const Ray = @import("ray.zig");
const Hittable = @import("hittable.zig");
const Vec3 = @import("Vec3.zig");

const Material = @This();

ptr: *const anyopaque,
scatterFn: *const fn (
    ptr: *const anyopaque,
    r_in: *const Ray,
    hit_record: *const Hittable.Record,
    attenuation: *Vec3,
    scattered: *Ray,
) bool,

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
            return @call(.always_inline, ptr_info.Pointer.child.scatter, .{
                self,
                r_in,
                hit_record,
                attenuation,
                scattered,
            });
        }
    };

    return .{
        .ptr = ptr,
        .scatterFn = gen.scatter,
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

pub const Lambertian = struct {
    albedo: Vec3,

    pub fn init(albedo: Vec3) Lambertian {
        return .{ .albedo = albedo };
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

    pub fn init(albedo: Vec3, fuzz: f64) Metal {
        return .{ .albedo = albedo, .fuzz = fuzz };
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
