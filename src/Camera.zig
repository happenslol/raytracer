const std = @import("std");
const util = @import("util.zig");

const stbImageWrite = @cImport({
    @cInclude("stb_image_write.c");
});

const Vec3 = @import("Vec3.zig");
const Hittable = @import("Hittable.zig");
const Interval = util.Interval;

const Camera = @This();
const Allocator = std.mem.Allocator;

pub const Ray = struct {
    origin: Vec3,
    direction: Vec3,

    pub fn init(origin: Vec3, direction: Vec3) Ray {
        return Ray{
            .origin = origin,
            .direction = direction,
        };
    }

    pub fn at(self: Ray, t: f64) Vec3 {
        return self.origin.add(self.direction.mulScalar(t));
    }
};

aspect_ratio: f64,
image_width: u32,
samples_per_pixel: u32,
max_depth: u16,

vfov: f64,
look_from: Vec3,
look_at: Vec3,
v_up: Vec3,

defocus_angle: f64,
focus_dist: f64,

image_height: u32,
center: Vec3,
pixel00_loc: Vec3,
pixel_delta_u: Vec3,
pixel_delta_v: Vec3,
pixel_samples_scale: f64,

u: Vec3,
v: Vec3,
w: Vec3,

defocus_disk_u: Vec3,
defocus_disk_v: Vec3,

pub fn init(opts: struct {
    aspect_ratio: f64 = 16.0 / 9.0,
    image_width: u32 = 400,
    samples_per_pixel: u32 = 10,
    max_depth: u16 = 10,

    vfov: f64 = 90.0,
    look_from: Vec3 = Vec3.init(0, 0, 0),
    look_at: Vec3 = Vec3.init(0, 0, -1),
    v_up: Vec3 = Vec3.init(0, 1, 0),

    defocus_angle: f64 = 0,
    focus_dist: f64 = 10,
}) Camera {
    var image_height: u32 = @intFromFloat(@as(f64, @floatFromInt(opts.image_width)) / opts.aspect_ratio);
    if (image_height < 1) image_height = 1;

    const theta = util.degreesToRadians(opts.vfov);
    const h = @tan(theta / 2.0);
    const viewport_height = 2.0 * h * opts.focus_dist;
    const viewport_width = viewport_height * (@as(f64, @floatFromInt(opts.image_width)) / @as(f64, @floatFromInt(image_height)));
    const center = opts.look_from;

    const w = opts.look_from.sub(opts.look_at).normalize();
    const u = opts.v_up.cross(w).normalize();
    const v = w.cross(u);

    // Vectors along the viewport edges
    const viewport_u = u.mulScalar(viewport_width); // Top left to top right
    const viewport_v = v.mulScalar(viewport_height * -1); // Top left to bottom left, reversed since our y-axis is flipped when writing

    // Pixel deltas (distance between individual pixels)
    var pixel_delta_u = viewport_u.divScalar(@as(f64, @floatFromInt(opts.image_width)));
    const pixel_delta_v = viewport_v.divScalar(@as(f64, @floatFromInt(image_height)));

    // Location of upper left pixel, e.g. the pixel at (0, 0) and the first one we write
    const viewport_upper_left = center
        .sub(w.mulScalar(opts.focus_dist))
        .sub(viewport_u.divScalar(2))
        .sub(viewport_v.divScalar(2));

    // Calculate the location of the upper left pixel.
    const pixel00_loc = viewport_upper_left.add(
        pixel_delta_u.add(pixel_delta_v).mulScalar(0.5),
    );

    // Calculate the camera defocus disk basis vectors.
    const defocus_radius = opts.focus_dist * @tan(util.degreesToRadians(opts.defocus_angle / 2));
    const defocus_disk_u = u.mulScalar(defocus_radius);
    const defocus_disk_v = v.mulScalar(defocus_radius);

    return .{
        .aspect_ratio = opts.aspect_ratio,
        .image_width = opts.image_width,
        .samples_per_pixel = opts.samples_per_pixel,
        .max_depth = opts.max_depth,

        .vfov = opts.vfov,
        .look_from = opts.look_from,
        .look_at = opts.look_at,
        .v_up = opts.v_up,

        .defocus_angle = opts.defocus_angle,
        .focus_dist = opts.focus_dist,

        .image_height = image_height,
        .center = center,
        .pixel00_loc = pixel00_loc,
        .pixel_delta_u = pixel_delta_u,
        .pixel_delta_v = pixel_delta_v,
        .pixel_samples_scale = 1.0 / @as(f64, @floatFromInt(opts.samples_per_pixel)),

        .u = u,
        .v = v,
        .w = w,

        .defocus_disk_u = defocus_disk_u,
        .defocus_disk_v = defocus_disk_v,
    };
}

pub fn render(self: *const Camera, alloc: Allocator, world: *const Hittable) !void {
    const comp = 3;
    const stride = self.image_width * comp;

    const data = try alloc.alloc(u8, self.image_height * stride);
    defer alloc.free(data);

    for (0..self.image_height) |j| {
        std.debug.print("\r\x1b[KScanlines remaining: {}", .{self.image_height - j});

        for (0..self.image_width) |i| {
            var pixel_color = Vec3.init(0, 0, 0);
            for (0..self.samples_per_pixel) |_| {
                const ray = self.getRay(@intCast(i), @intCast(j));
                pixel_color = pixel_color.add(rayColor(ray, self.max_depth, world));
            }

            pixel_color
                .mulScalar(self.pixel_samples_scale)
                .writePixel(data, (j * self.image_width + i) * comp);
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

fn rayColor(r: Ray, depth: u16, world: *const Hittable) Vec3 {
    if (depth <= 0) return Vec3.init(0, 0, 0);

    var rec = Hittable.Record.init();
    if (world.hit(&r, Interval.init(0.001, std.math.inf(f64)), &rec)) {
        var scattered = Ray.init(Vec3.init(0, 0, 0), Vec3.init(0, 0, 0));
        var attenuation = Vec3.init(0, 0, 0);

        if (rec.mat) |mat| {
            if (mat.scatter(&r, &rec, &attenuation, &scattered))
                return attenuation.mul(rayColor(scattered, depth - 1, world));

            return Vec3.init(0, 0, 0);
        }
    }

    const unit_direction = r.direction.normalize();
    // -1 < y < 1 since we scaled this to unit length, so we're now in the range of [0, 1]
    const a = 0.5 * (unit_direction.y + 1.0);

    // Linear interpolation
    const white = Vec3.init(1.0, 1.0, 1.0).mulScalar(1.0 - a);
    const blue = Vec3.init(0.5, 0.7, 1.0).mulScalar(a);
    return white.add(blue);
}

/// Constructs a camera ray originating from the defocus disk and directed at a
/// randomly sampled point around the pixel location i, j.
fn getRay(self: *const Camera, i: u32, j: u32) Ray {
    const offset = sampleSquare();
    const pixel_sample = self.pixel00_loc
        .add(self.pixel_delta_u.mulScalar(@as(f64, @floatFromInt(i)) + offset.x))
        .add(self.pixel_delta_v.mulScalar(@as(f64, @floatFromInt(j)) + offset.y));

    const ray_origin = if (self.defocus_angle <= 0) self.center else self.defocus_disk_sample();
    const ray_direction = pixel_sample.sub(ray_origin);

    return Ray.init(ray_origin, ray_direction);
}
// Returns a random point in the camera defocus disk.
fn defocus_disk_sample(self: *const Camera) Vec3 {
    const p = Vec3.randomInUnitDisk();
    return self.center
        .add(self.defocus_disk_u.mulScalar(p.x))
        .add(self.defocus_disk_v.mulScalar(p.y));
}

/// Returns the vector to a random point in the [-.5,-.5]-[+.5,+.5] unit square.
fn sampleSquare() Vec3 {
    return Vec3.init(
        util.randomDouble() - 0.5,
        util.randomDouble() - 0.5,
        0,
    );
}
