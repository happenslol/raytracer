const std = @import("std");

const stbImageWrite = @cImport({
    @cInclude("stb_image_write.c");
});

const Vec3 = @import("vec3.zig");
const Hittable = @import("hittable.zig");
const Ray = @import("ray.zig");
const Interval = @import("interval.zig");

const Self = @This();
const Allocator = std.mem.Allocator;

aspect_ratio: f64,
image_width: u32,

image_height: u32,
center: Vec3,
pixel00_loc: Vec3,
pixel_delta_u: Vec3,
pixel_delta_v: Vec3,

pub fn render(self: *const Self, alloc: Allocator, world: *const Hittable) !void {
    const comp = 3;
    const stride = self.image_width * comp;

    const data = try alloc.alloc(u8, self.image_height * stride);
    defer alloc.free(data);

    for (0..self.image_height) |j| {
        std.debug.print("\r\x1b[KScanlines remaining: {}", .{self.image_height - j});

        for (0..self.image_width) |i| {
            const pixel_center = self.pixel00_loc
                .add(self.pixel_delta_u.mulScalar(@floatFromInt(i)))
                .add(self.pixel_delta_v.mulScalar(@floatFromInt(j)));

            const ray_direction = pixel_center.sub(self.center);
            const ray = Ray.init(self.center, ray_direction);

            rayColor(ray, world).writePixel(data, (j * self.image_width + i) * comp);
        }
    }

    const result = stbImageWrite.stbi_write_png(
        "./out.png",
        @intCast(self.image_width),
        @intCast(self.image_height),
        comp,
        @ptrCast(data),
        @intCast(stride),
    );

    if (result == 0) {
        std.debug.print("Failed to write out.png\n", .{});
        return;
    }

    std.debug.print("\r\x1b[KDone!\n", .{});
}

pub fn init(
    aspect_ratio: f64,
    image_width: u32,
) Self {
    var image_height: u32 = @intFromFloat(@as(f64, @floatFromInt(image_width)) / aspect_ratio);
    if (image_height < 1) image_height = 1;

    const focal_length = 1.0;
    const viewport_height = 2.0;
    const viewport_width = viewport_height * (@as(f64, @floatFromInt(image_width)) / @as(f64, @floatFromInt(image_height)));
    const center = Vec3.init(0.0, 0.0, 0.0);

    // Vectors along the viewport edges
    const viewport_u = Vec3.init(viewport_width, 0.0, 0.0); // Top left to top right
    const viewport_v = Vec3.init(0.0, -viewport_height, 0.0); // Top left to bottom left, reversed since our y-axis is flipped when writing

    // Pixel deltas (distance between individual pixels)
    var pixel_delta_u = viewport_u.divScalar(@as(f64, @floatFromInt(image_width)));
    const pixel_delta_v = viewport_v.divScalar(@as(f64, @floatFromInt(image_height)));

    // Location of upper left pixel, e.g. the pixel at (0, 0) and the first one we write
    const viewport_upper_left = center
        .sub(Vec3.init(0.0, 0.0, focal_length))
        .sub(viewport_u.divScalar(2))
        .sub(viewport_v.divScalar(2));

    const pixel00_loc = viewport_upper_left.add(
        pixel_delta_u.add(pixel_delta_v).mulScalar(0.5),
    );

    return .{
        .aspect_ratio = aspect_ratio,
        .image_width = image_width,

        .image_height = image_height,
        .center = center,
        .pixel00_loc = pixel00_loc,
        .pixel_delta_u = pixel_delta_u,
        .pixel_delta_v = pixel_delta_v,
    };
}

fn rayColor(r: Ray, world: *const Hittable) Vec3 {
    var rec = Hittable.Record.init();
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
