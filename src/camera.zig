const std = @import("std");
const util = @import("util.zig");

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
samples_per_pixel: u32,
max_depth: u16,

image_height: u32,
center: Vec3,
pixel00_loc: Vec3,
pixel_delta_u: Vec3,
pixel_delta_v: Vec3,
pixel_samples_scale: f64,

pub fn init(opts: struct {
    aspect_ratio: ?f64,
    image_width: ?u32,
    samples_per_pixel: ?u32,
    max_depth: ?u16,
}) Self {
    const aspect_ratio = opts.aspect_ratio orelse 16.0 / 9.0;
    const image_width = opts.image_width orelse 400;
    const samples_per_pixel = opts.samples_per_pixel orelse 10;
    const max_depth = opts.max_depth orelse 10;

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
        .samples_per_pixel = samples_per_pixel,
        .max_depth = max_depth,

        .image_height = image_height,
        .center = center,
        .pixel00_loc = pixel00_loc,
        .pixel_delta_u = pixel_delta_u,
        .pixel_delta_v = pixel_delta_v,
        .pixel_samples_scale = 1.0 / @as(f64, @floatFromInt(samples_per_pixel)),
    };
}

pub fn render(self: *const Self, alloc: Allocator, world: *const Hittable) !void {
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
        const direction = Vec3.randomOnHemisphere(&rec.normal);
        return rayColor(Ray.init(rec.p, direction), depth - 1, world).mulScalar(0.5);
    }

    const unit_direction = r.direction.normalize();
    // -1 < y < 1 since we scaled this to unit length, so we're now in the range of [0, 1]
    const a = 0.5 * (unit_direction.y + 1.0);

    // Linear interpolation
    const white = Vec3.init(1.0, 1.0, 1.0).mulScalar(1.0 - a);
    const blue = Vec3.init(0.5, 0.7, 1.0).mulScalar(a);
    return white.add(blue);
}

/// Constructs a camera ray originating from the origin and directed at randomly
/// sampled point around the pixel location i, j.
fn getRay(self: *const Self, i: u32, j: u32) Ray {
    const offset = sampleSquare();
    const pixel_sample = self.pixel00_loc
        .add(self.pixel_delta_u.mulScalar(@as(f64, @floatFromInt(i)) + offset.x))
        .add(self.pixel_delta_v.mulScalar(@as(f64, @floatFromInt(j)) + offset.y));

    const ray_origin = self.center;
    const ray_direction = pixel_sample.sub(ray_origin);

    return Ray.init(ray_origin, ray_direction);
}

/// Returns the vector to a random point in the [-.5,-.5]-[+.5,+.5] unit square.
fn sampleSquare() Vec3 {
    return Vec3.init(
        util.randomDouble() - 0.5,
        util.randomDouble() - 0.5,
        0,
    );
}
