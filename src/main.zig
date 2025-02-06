const std = @import("std");

const Vec3 = @import("Vec3.zig");
const Ray = @import("ray.zig");
const Interval = @import("interval.zig");
const Hittable = @import("hittable.zig");
const Camera = @import("camera.zig");
const Material = @import("material.zig");

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
    defer world.deinit();

    const material_ground = Material.init(&Material.Lambertian.init(Vec3.init(0.8, 0.8, 0.0)));
    const material_center = Material.init(&Material.Lambertian.init(Vec3.init(0.1, 0.2, 0.5)));
    const material_left = Material.init(&Material.Metal.init(Vec3.init(0.8, 0.8, 0.8), 0.3));
    const material_right = Material.init(&Material.Metal.init(Vec3.init(0.8, 0.6, 0.2), 1.0));

    try world.add(Hittable.init(&Hittable.Sphere.init(Vec3.init(0.0, -100.5, -1.0), 100.0, &material_ground)));
    try world.add(Hittable.init(&Hittable.Sphere.init(Vec3.init(0.0, 0.0, -1.2), 0.5, &material_center)));
    try world.add(Hittable.init(&Hittable.Sphere.init(Vec3.init(-1.0, 0.0, -1.0), 0.5, &material_left)));
    try world.add(Hittable.init(&Hittable.Sphere.init(Vec3.init(1.0, 0.0, -1.0), 0.5, &material_right)));

    try camera.render(allocator, &Hittable.init(&world));
}
