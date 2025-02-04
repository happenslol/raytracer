const std = @import("std");

const Vec3 = @import("vec3.zig");
const Ray = @import("ray.zig");
const Interval = @import("interval.zig");
const Hittable = @import("hittable.zig");
const Sphere = @import("sphere.zig");
const Camera = @import("camera.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const camera = Camera.init(16.0 / 9.0, 400);

    var world = Hittable.List.init(allocator);
    defer world.deinit();

    try world.add(Hittable.init(&Sphere.init(Vec3.init(0.0, 0.0, -1.0), 0.5)));
    try world.add(Hittable.init(&Sphere.init(Vec3.init(0, -100.5, -1.0), 100)));

    try camera.render(allocator, &Hittable.init(&world));
}
