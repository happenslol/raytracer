const std = @import("std");
const stbImageWrite = @cImport({
    @cInclude("stb_image_write.c");
});

const Interval = @import("interval.zig");

const Vec3 = @import("vec3.zig");
const Ray = @import("ray.zig");

const HitRecord = struct {
    p: Vec3,
    normal: Vec3,
    t: f64,
    front_face: bool,

    fn init() HitRecord {
        return .{
            .p = Vec3.init(0, 0, 0),
            .normal = Vec3.init(0, 0, 0),
            .t = 0,
            .front_face = false,
        };
    }

    /// Sets the hit record normal vector.
    // NOTE: the parameter `outward_normal` is assumed to have unit length.
    fn setFaceNormal(self: *HitRecord, r: *const Ray, outward_normal: Vec3) void {
        self.front_face = r.direction.dot(outward_normal) < 0;
        self.normal = if (self.front_face) outward_normal else outward_normal.mulScalar(-1);
    }
};

const Hittable = struct {
    ptr: *const anyopaque,
    hitFn: *const fn (ptr: *const anyopaque, r: *const Ray, ray_t: Interval, hit_record: ?*HitRecord) bool,

    fn init(ptr: anytype) Hittable {
        const T = @TypeOf(ptr);
        const ptr_info = @typeInfo(T);

        const gen = struct {
            pub fn hit(self_ptr: *const anyopaque, r: *const Ray, ray_t: Interval, hit_record: ?*HitRecord) bool {
                const self: T = @ptrCast(@alignCast(self_ptr));
                return @call(.always_inline, ptr_info.Pointer.child.hit, .{ self, r, ray_t, hit_record });
            }
        };

        return .{
            .ptr = ptr,
            .hitFn = gen.hit,
        };
    }

    pub inline fn hit(self: Hittable, r: *const Ray, ray_t: Interval, hit_record: ?*HitRecord) bool {
        return self.hitFn(self.ptr, r, ray_t, hit_record);
    }
};

const Sphere = struct {
    center: Vec3,
    radius: f64,

    fn init(center: Vec3, radius: f64) Sphere {
        return .{ .center = center, .radius = @max(0, radius) };
    }

    fn hit(self: *const Sphere, r: *const Ray, ray_t: Interval, hit_record: ?*HitRecord) bool {
        const oc = self.center.sub(r.origin);
        const a = r.direction.lengthSquared();
        const h = r.direction.dot(oc);
        const c = oc.lengthSquared() - self.radius * self.radius;

        // 0 or > 0 means 1 solution (tangent) or 2 solutions (intersection)
        const discriminant = h * h - a * c;

        if (discriminant < 0) {
            return false;
        }

        const discriminantSqrt = @sqrt(discriminant);

        // Find the nearest root that lies in the acceptable range.
        var root = (h - discriminantSqrt) / a;
        if (!ray_t.surrounds(root)) {
            root = (h + discriminantSqrt) / a;
            if (!ray_t.surrounds(root))
                return false;
        }

        if (hit_record) |rec| {
            rec.t = root;
            rec.p = r.at(root);
            rec.setFaceNormal(r, rec.p.sub(self.center).divScalar(self.radius));
        }

        return true;
    }
};

const HittableList = struct {
    objects: std.ArrayList(Hittable),

    pub fn init(allocator: std.mem.Allocator) HittableList {
        return .{ .objects = std.ArrayList(Hittable).init(allocator) };
    }

    pub fn add(self: *HittableList, obj: Hittable) !void {
        try self.objects.append(obj);
    }

    pub fn clear(self: *HittableList) void {
        self.objects.clearRetainingCapacity();
    }

    pub fn deinit(self: *HittableList) void {
        self.objects.deinit();
    }

    pub fn hit(self: *const HittableList, r: *const Ray, ray_t: Interval, hit_record: ?*HitRecord) bool {
        var temp_rec = HitRecord.init();
        var hit_anything = false;
        var closest_so_far = ray_t.max;

        for (self.objects.items) |obj| {
            if (obj.hit(r, Interval.init(ray_t.min, closest_so_far), &temp_rec)) {
                hit_anything = true;
                closest_so_far = temp_rec.t;
                hit_record.?.* = temp_rec;
            }
        }

        return hit_anything;
    }
};

fn rayColor(r: Ray, world: *HittableList) Vec3 {
    var rec = HitRecord.init();
    if (world.hit(&r, Interval.init(0, std.math.inf(f64)), &rec)) {
        return rec.normal.add(Vec3.init(1.0, 1.0, 1.0)).mulScalar(0.5);
    }

    const unit_direction = r.direction.normalize();
    // -1 < y < 1 since we scaled this to unit length, so we're now in the range of [0, 1]
    const a = 0.5 * (unit_direction.y + 1.0);

    // Linear interpolation
    const white = Vec3.init(1.0, 1.0, 1.0).mulScalar(1.0 - a);
    const blue = Vec3.init(0.5, 0.7, 1.0).mulScalar(a);
    return white.add(blue);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const aspect_ratio = 16.0 / 9.0;
    const image_width = 400;

    var image_height: u32 = @intFromFloat(@as(f64, @floatFromInt(image_width)) / aspect_ratio);
    if (image_height < 1) image_height = 1;

    const comp = 3;
    const stride = image_width * comp;

    // World
    var world = HittableList.init(allocator);
    defer world.deinit();

    try world.add(Hittable.init(&Sphere.init(Vec3.init(0.0, 0.0, -1.0), 0.5)));
    try world.add(Hittable.init(&Sphere.init(Vec3.init(0, -100.5, -1.0), 100)));

    // Camera
    const focal_length = 1.0;
    const viewport_height = 2.0;
    const viewport_width = viewport_height * (@as(f64, @floatFromInt(image_width)) / @as(f64, @floatFromInt(image_height)));
    const camera_center = Vec3.init(0.0, 0.0, 0.0);

    // Vectors along the viewport edges
    const viewport_u = Vec3.init(viewport_width, 0.0, 0.0); // Top left to top right
    const viewport_v = Vec3.init(0.0, -viewport_height, 0.0); // Top left to bottom left, reversed since our y-axis is flipped when writing

    // Pixel deltas (distance between individual pixels)
    var pixel_delta_u = viewport_u.divScalar(@as(f64, @floatFromInt(image_width)));
    const pixel_delta_v = viewport_v.divScalar(@as(f64, @floatFromInt(image_height)));

    // Location of upper left pixel, e.g. the pixel at (0, 0) and the first one we write
    const viewport_upper_left = camera_center
        .sub(Vec3.init(0.0, 0.0, focal_length))
        .sub(viewport_u.divScalar(2))
        .sub(viewport_v.divScalar(2));

    const pixel00_loc = viewport_upper_left.add(
        pixel_delta_u.add(pixel_delta_v).mulScalar(0.5),
    );

    // Writing

    const data = try allocator.alloc(u8, image_height * image_width * comp);
    defer allocator.free(data);

    for (0..image_height) |j| {
        std.debug.print("\r\x1b[KScanlines remaining: {}", .{image_height - j});

        for (0..image_width) |i| {
            const pixel_center = pixel00_loc
                .add(pixel_delta_u.mulScalar(@floatFromInt(i)))
                .add(pixel_delta_v.mulScalar(@floatFromInt(j)));

            const ray_direction = pixel_center.sub(camera_center);
            const ray = Ray.init(camera_center, ray_direction);

            rayColor(ray, &world).writePixel(data, (j * image_width + i) * comp);
        }
    }

    const result = stbImageWrite.stbi_write_png(
        "./out.png",
        @intCast(image_width),
        @intCast(image_height),
        comp,
        @ptrCast(data),
        stride,
    );
    if (result == 0) {
        std.debug.print("Failed to write out.png\n", .{});
        return;
    }

    std.debug.print("\r\x1b[KDone!\n", .{});
}
