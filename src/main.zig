const std = @import("std");
const stbImageWrite = @cImport({
    @cInclude("stb_image_write.c");
});

const Vec3 = @import("vec3.zig");
const Ray = @import("ray.zig");

fn hitSphere(center: *const Vec3, radius: f64, r: *const Ray) f64 {
    const oc = center.sub(r.origin);
    const a = r.direction.lengthSquared();
    const h = r.direction.dot(oc);
    const c = oc.lengthSquared() - radius * radius;

    const discriminant = h * h - a * c;

    // 0 or > 0 means 1 solution (tangent) or 2 solutions (intersection)
    if (discriminant < 0) {
        return -1;
    }

    return (h - @sqrt(discriminant)) / a;
}

const sphereCenter = Vec3.init(0.0, 0.0, -1.0);
const sphereRadius = 0.5;

fn rayColor(r: Ray) Vec3 {
    const t = hitSphere(&sphereCenter, sphereRadius, &r);
    if (t > 0) {
        const n = r.at(t).sub(Vec3.init(0.0, 0.0, -1.0)).normalize();
        return Vec3.init(n.x + 1.0, n.y + 1.0, n.z + 1.0).mulScalar(0.5);
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

            rayColor(ray).writePixel(data, (j * image_width + i) * comp);
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
