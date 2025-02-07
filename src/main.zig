const std = @import("std");
const util = @import("util.zig");

const Vec3 = @import("Vec3.zig");
const Hittable = @import("Hittable.zig");
const Camera = @import("Camera.zig");
const Material = @import("Material.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var world = Hittable.List.init(alloc);

    const material_ground = try Material.Lambertian.init(alloc, Vec3.init(0.8, 0.8, 0.0));
    const material_center = try Material.Lambertian.init(alloc, Vec3.init(0.1, 0.2, 0.5));
    const material_left = try Material.Dielectric.init(alloc, 1.50);
    const material_bubble = try Material.Dielectric.init(alloc, 1.00 / 1.50);
    const material_right = try Material.Metal.init(alloc, Vec3.init(0.8, 0.6, 0.2), 1.0);

    try world.add(try Hittable.Sphere.init(alloc, Vec3.init(0.0, -100.5, -1.0), 100.0, material_ground));
    try world.add(try Hittable.Sphere.init(alloc, Vec3.init(0.0, 0.0, -1.2), 0.5, material_center));
    try world.add(try Hittable.Sphere.init(alloc, Vec3.init(-1.0, 0.0, -1.0), 0.5, material_left));
    try world.add(try Hittable.Sphere.init(alloc, Vec3.init(-1.0, 0.0, -1.0), 0.4, material_bubble));
    try world.add(try Hittable.Sphere.init(alloc, Vec3.init(1.0, 0.0, -1.0), 0.5, material_right));

    const camera = Camera.init(.{
        .samples_per_pixel = 5,
        .look_from = Vec3.init(-2, 2, 1),
    });

    try camera.render(alloc, &Hittable.init(&world));
}
