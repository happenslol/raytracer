const std = @import("std");
const util = @import("util.zig");
const vec3 = @import("vec3.zig");
const Material = @import("Material.zig");
const Ray = @import("Camera.zig").Ray;
const Interval = util.Interval;

const Hittable = @This();

pub const Record = struct {
    p: vec3.vec3,
    normal: vec3.vec3,
    mat: ?Material,
    t: f64,
    front_face: bool,

    pub fn init() Record {
        return .{
            .p = vec3.init(0, 0, 0),
            .normal = vec3.init(0, 0, 0),
            .mat = null,
            .t = 0,
            .front_face = false,
        };
    }

    /// Sets the hit record normal vector.
    // NOTE: the parameter `outward_normal` is assumed to have unit length.
    pub fn setFaceNormal(self: *Record, r: *const Ray, outward_normal: vec3.vec3) void {
        self.front_face = vec3.dot(r.direction, outward_normal) < 0;
        self.normal = if (self.front_face) outward_normal else outward_normal * vec3.scalar(-1);
    }
};

ptr: *const anyopaque,
hitFn: *const fn (ptr: *const anyopaque, r: *const Ray, ray_t: Interval, hit_record: ?*Record) bool,
deinitFn: *const fn (ptr: *const anyopaque, alloc: std.mem.Allocator) void,

pub fn init(ptr: anytype) Hittable {
    const T = @TypeOf(ptr);
    const ptr_info = @typeInfo(T);

    const gen = struct {
        pub fn hit(self_ptr: *const anyopaque, r: *const Ray, ray_t: Interval, hit_record: ?*Record) bool {
            const self: T = @ptrCast(@alignCast(@constCast(self_ptr)));
            return @call(.always_inline, ptr_info.Pointer.child.hit, .{ self, r, ray_t, hit_record });
        }

        pub fn deinit(self_ptr: *const anyopaque, alloc: std.mem.Allocator) void {
            const self: T = @ptrCast(@alignCast(@constCast(self_ptr)));
            return @call(.always_inline, ptr_info.Pointer.child.deinit, .{ self, alloc });
        }
    };

    return .{
        .ptr = ptr,
        .hitFn = gen.hit,
        .deinitFn = gen.deinit,
    };
}

pub inline fn hit(self: Hittable, r: *const Ray, ray_t: Interval, hit_record: ?*Record) bool {
    return self.hitFn(self.ptr, r, ray_t, hit_record);
}

pub fn deinit(self: Hittable, alloc: std.mem.Allocator) void {
    return self.deinitFn(self.ptr, alloc);
}

pub const List = struct {
    objects: std.ArrayList(Hittable),

    pub fn init(allocator: std.mem.Allocator) List {
        return .{ .objects = std.ArrayList(Hittable).init(allocator) };
    }

    pub fn add(self: *List, obj: Hittable) !void {
        try self.objects.append(obj);
    }

    pub fn clear(self: *List) void {
        self.objects.clearRetainingCapacity();
    }

    pub fn deinit(self: *List, alloc: std.mem.Allocator) void {
        for (self.objects.items) |obj| {
            obj.deinit(alloc);
        }

        self.objects.deinit();
    }

    pub fn hit(self: *const List, r: *const Ray, ray_t: Interval, hit_record: ?*Record) bool {
        var temp_rec = Record.init();
        var hit_anything = false;
        var closest_so_far = ray_t.max;

        for (self.objects.items) |obj| {
            if (obj.hit(r, Interval.init(ray_t.min, closest_so_far), &temp_rec)) {
                hit_anything = true;
                closest_so_far = temp_rec.t;
                hit_record.?.* = temp_rec;
            }
        }

        return hit_anything;
    }
};

pub const Sphere = struct {
    center: vec3.vec3,
    radius: f64,
    mat: Material,

    pub fn init(
        alloc: std.mem.Allocator,
        center: vec3.vec3,
        radius: f64,
        mat: Material,
    ) !Hittable {
        const result = try alloc.create(Sphere);
        result.* = .{
            .center = center,
            .radius = @max(0, radius),
            .mat = mat,
        };

        return Hittable.init(result);
    }

    pub fn deinit(self: *const Sphere, alloc: std.mem.Allocator) void {
        alloc.destroy(self);
    }

    pub fn hit(self: *const Sphere, r: *const Ray, ray_t: Interval, hit_record: ?*Hittable.Record) bool {
        const oc = self.center - r.origin;
        const a = vec3.lengthSquared(r.direction);
        const h = vec3.dot(r.direction, oc);
        const c = vec3.lengthSquared(oc) - self.radius * self.radius;

        // 0 or > 0 means 1 solution (tangent) or 2 solutions (intersection)
        const discriminant = h * h - a * c;

        if (discriminant < 0) {
            return false;
        }

        const discriminantSqrt = @sqrt(discriminant);

        // Find the nearest root that lies in the acceptable range.
        var root = (h - discriminantSqrt) / a;
        if (!ray_t.surrounds(root)) {
            root = (h + discriminantSqrt) / a;
            if (!ray_t.surrounds(root))
                return false;
        }

        if (hit_record) |rec| {
            rec.t = root;
            rec.p = r.at(root);
            rec.setFaceNormal(r, (rec.p - self.center) / vec3.scalar(self.radius));
            rec.mat = self.mat;
        }

        return true;
    }
};
