const std = @import("std");
const Hittable = @import("Hittable.zig");
const Vec3 = @import("Vec3.zig");
const Ray = @import("Camera.zig").Ray;

const Material = @This();

ptr: *const anyopaque,
scatterFn: *const fn (
    ptr: *const anyopaque,
    r_in: *const Ray,
    hit_record: *const Hittable.Record,
    attenuation: *Vec3,
    scattered: *Ray,
) bool,
deinitFn: *const fn (ptr: *const anyopaque, alloc: std.mem.Allocator) void,

pub fn init(ptr: anytype) Material {
    const T = @TypeOf(ptr);
    const ptr_info = @typeInfo(T);

    const gen = struct {
        pub fn scatter(
            self_ptr: *const anyopaque,
            r_in: *const Ray,
            hit_record: *const Hittable.Record,
            attenuation: *Vec3,
            scattered: *Ray,
        ) bool {
            const self: T = @ptrCast(@alignCast(@constCast(self_ptr)));
            return @call(.always_inline, ptr_info.Pointer.child.scatter, .{ self, r_in, hit_record, attenuation, scattered });
        }

        pub fn deinit(self_ptr: *const anyopaque, alloc: std.mem.Allocator) void {
            const self: T = @ptrCast(@alignCast(@constCast(self_ptr)));
            return @call(.always_inline, ptr_info.Pointer.child.deinit, .{ self, alloc });
        }
    };

    return .{
        .ptr = ptr,
        .scatterFn = gen.scatter,
        .deinitFn = gen.deinit,
    };
}

pub inline fn scatter(
    self: Material,
    r_in: *const Ray,
    hit_record: *const Hittable.Record,
    attenuation: *Vec3,
    scattered: *Ray,
) bool {
    return self.scatterFn(self.ptr, r_in, hit_record, attenuation, scattered);
}

pub inline fn deinit(self: Material, alloc: std.mem.Allocator) void {
    self.deinitFn(self.ptr, alloc);
}

pub const Lambertian = struct {
    albedo: Vec3,

    pub fn init(alloc: std.mem.Allocator, albedo: Vec3) !Material {
        const result = try alloc.create(Lambertian);
        result.* = .{ .albedo = albedo };
        return Material.init(result);
    }

    pub fn deinit(self: *const Lambertian, alloc: std.mem.Allocator) void {
        alloc.destroy(self);
    }

    pub fn scatter(
        self: *const Lambertian,
        r_in: *const Ray,
        hit_record: *const Hittable.Record,
        attenuation: *Vec3,
        scattered: *Ray,
    ) bool {
        _ = r_in;

        var scatter_direction = hit_record.normal.add(Vec3.randomUnitVector());
        if (scatter_direction.nearZero()) scatter_direction = hit_record.normal;

        scattered.* = Ray.init(hit_record.p, scatter_direction);
        attenuation.* = self.albedo;
        return true;
    }
};

pub const Metal = struct {
    albedo: Vec3,
    fuzz: f64,

    pub fn init(alloc: std.mem.Allocator, albedo: Vec3, fuzz: f64) !Material {
        const result = try alloc.create(Metal);
        result.* = .{ .albedo = albedo, .fuzz = fuzz };
        return Material.init(result);
    }

    pub fn deinit(self: *const Metal, alloc: std.mem.Allocator) void {
        alloc.destroy(self);
    }

    pub fn scatter(
        self: *const Metal,
        r_in: *const Ray,
        hit_record: *const Hittable.Record,
        attenuation: *Vec3,
        scattered: *Ray,
    ) bool {
        const reflected = r_in.direction
            .reflect(&hit_record.normal)
            .normalize()
            .add(Vec3.randomUnitVector().mulScalar(self.fuzz));

        scattered.* = Ray.init(hit_record.p, reflected);
        attenuation.* = self.albedo;

        return scattered.direction.dot(&hit_record.normal) > 0;
    }
};
