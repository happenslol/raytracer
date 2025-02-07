const std = @import("std");
const util = @import("util.zig");

const vec3 = @import("vec3.zig");
const Hittable = @import("Hittable.zig");
const Camera = @import("Camera.zig");
const Material = @import("Material.zig");

pub fn main() !void {
    try simple_scene();
}

pub fn simple_scene() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var world = Hittable.List.init(alloc);

    const material_ground = try Material.Lambertian.init(alloc, vec3.init(0.8, 0.8, 0.0));
    const material_center = try Material.Lambertian.init(alloc, vec3.init(0.1, 0.2, 0.5));
    const material_left = try Material.Dielectric.init(alloc, 1.50);
    const material_bubble = try Material.Dielectric.init(alloc, 1.00 / 1.50);
    const material_right = try Material.Metal.init(alloc, vec3.init(0.8, 0.6, 0.2), 1.0);

    try world.add(try Hittable.Sphere.init(alloc, vec3.init(0.0, -100.5, -1.0), 100.0, material_ground));
    try world.add(try Hittable.Sphere.init(alloc, vec3.init(0.0, 0.0, -1.2), 0.5, material_center));
    try world.add(try Hittable.Sphere.init(alloc, vec3.init(-1.0, 0.0, -1.0), 0.5, material_left));
    try world.add(try Hittable.Sphere.init(alloc, vec3.init(-1.0, 0.0, -1.0), 0.4, material_bubble));
    try world.add(try Hittable.Sphere.init(alloc, vec3.init(1.0, 0.0, -1.0), 0.5, material_right));

    const camera = Camera.init(.{
        .samples_per_pixel = 5,
        .look_from = vec3.init(-2, 2, 1),
    });

    try camera.render(alloc, &Hittable.init(&world));
}

pub fn demo_scene() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var world = Hittable.List.init(alloc);

    const ground_material = try Material.Lambertian.init(alloc, vec3.init(0.5, 0.5, 0.5));
    try world.add(try Hittable.Sphere.init(alloc, vec3.init(0, -1000, 0), 1000, ground_material));

    for (0..22) |ai| {
        const a = @as(i32, @intCast(ai)) - 11;
        for (0..22) |bi| {
            const b = @as(i32, @intCast(bi)) - 11;

            const choose_mat = util.randomDouble();
            const center = vec3.init(
                @as(f64, @floatFromInt(a)) + 0.9 * util.randomDouble(),
                0.2,
                @as(f64, @floatFromInt(b)) + 0.9 * util.randomDouble(),
            );

            if (vec3.length(center - (vec3.init(4, 0.2, 0))) <= 0.9) continue;

            const sphere_material = if (choose_mat < 0.8)
                try Material.Lambertian.init(alloc, vec3.random())
            else if (choose_mat < 0.95)
                try Material.Metal.init(alloc, vec3.randomInRange(0, 0.5), util.randomDoubleInRange(0, 0.5))
            else
                try Material.Dielectric.init(alloc, 1.5);

            try world.add(try Hittable.Sphere.init(alloc, center, 0.2, sphere_material));
        }
    }

    const material1 = try Material.Dielectric.init(alloc, 1.5);
    try world.add(try Hittable.Sphere.init(alloc, vec3.init(0, 1, 0), 1.0, material1));

    const material2 = try Material.Lambertian.init(alloc, vec3.init(0.4, 0.2, 0.1));
    try world.add(try Hittable.Sphere.init(alloc, vec3.init(-4, 1, 0), 1.0, material2));

    const material3 = try Material.Metal.init(alloc, vec3.init(0.7, 0.6, 0.5), 0.0);
    try world.add(try Hittable.Sphere.init(alloc, vec3.init(4, 1, 0), 1.0, material3));

    const camera = Camera.init(.{
        .image_width = 1200,
        .samples_per_pixel = 500,
        .vfov = 20,
        .look_from = vec3.init(13, 2, 3),
        .look_at = vec3.init(0, 0, 0),
        .v_up = vec3.init(0, 1, 0),
        .defocus_angle = 0.6,
        .focus_dist = 10,
    });

    try camera.render(alloc, &Hittable.init(&world));
}
