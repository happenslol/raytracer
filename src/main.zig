const std = @import("std");

const Vec3 = @import("Vec3.zig");
const Hittable = @import("Hittable.zig");
const Camera = @import("Camera.zig");
const Material = @import("Material.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const camera = Camera.init(.{
        .aspect_ratio = 16.0 / 9.0,
        .image_width = 400,
        .samples_per_pixel = 100,
        .max_depth = 50,
    });

    var world = Hittable.List.init(allocator);
    defer world.deinit(allocator);

    const material_ground = try Material.Lambertian.init(allocator, Vec3.init(0.8, 0.8, 0.0));
    defer material_ground.deinit(allocator);

    const material_center = try Material.Lambertian.init(allocator, Vec3.init(0.1, 0.2, 0.5));
    defer material_center.deinit(allocator);

    const material_left = try Material.Metal.init(allocator, Vec3.init(0.8, 0.8, 0.8), 0.3);
    defer material_left.deinit(allocator);

    const material_right = try Material.Metal.init(allocator, Vec3.init(0.8, 0.6, 0.2), 1.0);
    defer material_right.deinit(allocator);

    const ground = try Hittable.Sphere.init(allocator, Vec3.init(0.0, -100.5, -1.0), 100.0, material_ground);
    const center = try Hittable.Sphere.init(allocator, Vec3.init(0.0, 0.0, -1.2), 0.5, material_center);
    const left = try Hittable.Sphere.init(allocator, Vec3.init(-1.0, 0.0, -1.0), 0.5, material_left);
    const right = try Hittable.Sphere.init(allocator, Vec3.init(1.0, 0.0, -1.0), 0.5, material_right);

    try world.add(ground);
    try world.add(center);
    try world.add(left);
    try world.add(right);

    try camera.render(allocator, &Hittable.init(&world));
}
