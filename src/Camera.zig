const std = @import("std");
const util = @import("util.zig");

const stbImageWrite = @cImport({
    @cInclude("stb_image_write.c");
});

const vec3 = @import("vec3.zig");
const Hittable = @import("Hittable.zig");
const Interval = util.Interval;

const Camera = @This();
const Allocator = std.mem.Allocator;

pub const Ray = struct {
    origin: vec3.vec3,
    direction: vec3.vec3,

    pub fn init(origin: vec3.vec3, direction: vec3.vec3) Ray {
        return Ray{
            .origin = origin,
            .direction = direction,
        };
    }

    pub fn at(self: Ray, t: f64) vec3.vec3 {
        return self.origin + (self.direction * vec3.scalar(t));
    }
};

aspect_ratio: f64,
image_width: u32,
samples_per_pixel: u32,
max_depth: u16,

vfov: f64,
look_from: vec3.vec3,
look_at: vec3.vec3,
v_up: vec3.vec3,

defocus_angle: f64,
focus_dist: f64,

image_height: u32,
center: vec3.vec3,
pixel00_loc: vec3.vec3,
pixel_delta_u: vec3.vec3,
pixel_delta_v: vec3.vec3,
pixel_samples_scale: f64,

u: vec3.vec3,
v: vec3.vec3,
w: vec3.vec3,

defocus_disk_u: vec3.vec3,
defocus_disk_v: vec3.vec3,

pub fn init(opts: struct {
    aspect_ratio: f64 = 16 / 9,
    image_width: u32 = 400,
    samples_per_pixel: u32 = 10,
    max_depth: u16 = 10,

    vfov: f64 = 90,
    look_from: vec3.vec3 = vec3.init(0, 0, 0),
    look_at: vec3.vec3 = vec3.init(0, 0, -1),
    v_up: vec3.vec3 = vec3.init(0, 1, 0),

    defocus_angle: f64 = 0,
    focus_dist: f64 = 1,
}) Camera {
    var image_height: u32 = @intFromFloat(@as(f64, @floatFromInt(opts.image_width)) / opts.aspect_ratio);
    if (image_height < 1) image_height = 1;

    const theta = util.degreesToRadians(opts.vfov);
    const h = @tan(theta / 2);
    const viewport_height = 2 * h * opts.focus_dist;
    const viewport_width = viewport_height * (@as(f64, @floatFromInt(opts.image_width)) / @as(f64, @floatFromInt(image_height)));
    const center = opts.look_from;

    const w = vec3.normalize(opts.look_from - opts.look_at);
    const u = vec3.normalize(vec3.cross(opts.v_up, w));
    const v = vec3.cross(w, u);

    // Vectors along the viewport edges
    const viewport_u = u * vec3.scalar(viewport_width); // Top left to top right
    const viewport_v = v * vec3.scalar(viewport_height * -1); // Top left to bottom left, reversed since our y-axis is flipped when writing

    // Pixel deltas (distance between individual pixels)
    const pixel_delta_u = viewport_u / vec3.scalar(@as(f64, @floatFromInt(opts.image_width)));
    const pixel_delta_v = viewport_v / vec3.scalar(@as(f64, @floatFromInt(image_height)));

    // Location of upper left pixel, e.g. the pixel at (0, 0) and the first one we write
    const viewport_upper_left = center -
        (w * vec3.scalar(opts.focus_dist)) -
        (viewport_u / vec3.scalar(2)) -
        (viewport_v / vec3.scalar(2));

    // Calculate the location of the upper left pixel.
    const pixel00_loc = viewport_upper_left + vec3.scalar(0.5) * (pixel_delta_u + pixel_delta_v);

    // Calculate the camera defocus disk basis vectors.
    const defocus_radius = opts.focus_dist * @tan(util.degreesToRadians(opts.defocus_angle / 2));
    const defocus_disk_u = u * vec3.scalar(defocus_radius);
    const defocus_disk_v = v * vec3.scalar(defocus_radius);

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
        .pixel_samples_scale = 1 / @as(f64, @floatFromInt(opts.samples_per_pixel)),

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
            var pixel_color = vec3.init(0, 0, 0);
            for (0..self.samples_per_pixel) |_| {
                const ray = self.getRay(@intCast(i), @intCast(j));
                pixel_color = pixel_color + rayColor(ray, self.max_depth, world);
            }

            vec3.writePixel(
                pixel_color * vec3.scalar(self.pixel_samples_scale),
                data,
                (j * self.image_width + i) * comp,
            );
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

fn rayColor(r: Ray, depth: u16, world: *const Hittable) vec3.vec3 {
    if (depth <= 0) return vec3.init(0, 0, 0);

    var rec = Hittable.Record.init();
    if (world.hit(&r, Interval.init(0.001, std.math.inf(f64)), &rec)) {
        var scattered = Ray.init(vec3.init(0, 0, 0), vec3.init(0, 0, 0));
        var attenuation = vec3.init(0, 0, 0);

        if (rec.mat) |mat| {
            if (mat.scatter(&r, &rec, &attenuation, &scattered))
                return attenuation * rayColor(scattered, depth - 1, world);

            return vec3.init(0, 0, 0);
        }
    }

    const unit_direction = vec3.normalize(r.direction);
    // -1 < y < 1 since we scaled this to unit length, so we're now in the range of [0, 1]
    const a = 0.5 * (unit_direction[1] + 1);

    // Linear interpolation
    const white = vec3.init(1, 1, 1) * vec3.scalar(1 - a);
    const blue = vec3.init(0.5, 0.7, 1) * vec3.scalar(a);
    return white + blue;
}

/// Constructs a camera ray originating from the defocus disk and directed at a
/// randomly sampled point around the pixel location i, j.
fn getRay(self: *const Camera, i: u32, j: u32) Ray {
    const offset = sampleSquare();
    const pixel_sample = self.pixel00_loc +
        (self.pixel_delta_u * vec3.scalar(@as(f64, @floatFromInt(i)) + offset[0])) +
        (self.pixel_delta_v * vec3.scalar(@as(f64, @floatFromInt(j)) + offset[1]));

    const ray_origin = if (self.defocus_angle <= 0) self.center else self.defocus_disk_sample();
    const ray_direction = pixel_sample - ray_origin;

    return Ray.init(ray_origin, ray_direction);
}
// Returns a random point in the camera defocus disk.
fn defocus_disk_sample(self: *const Camera) vec3.vec3 {
    const p = vec3.randomInUnitDisk();
    return self.center +
        (self.defocus_disk_u * vec3.scalar(p[0])) +
        (self.defocus_disk_v * vec3.scalar(p[1]));
}

/// Returns the vector to a random point in the [-.5,-.5]-[+.5,+.5] unit square.
fn sampleSquare() vec3.vec3 {
    return vec3.init(
        util.randomDouble() - 0.5,
        util.randomDouble() - 0.5,
        0,
    );
}
