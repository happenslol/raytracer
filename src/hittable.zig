const std = @import("std");
const Ray = @import("ray.zig");
const Interval = @import("interval.zig");
const Vec3 = @import("vec3.zig");

const Self = @This();

pub const Record = struct {
    p: Vec3,
    normal: Vec3,
    t: f64,
    front_face: bool,

    pub fn init() Record {
        return .{
            .p = Vec3.init(0, 0, 0),
            .normal = Vec3.init(0, 0, 0),
            .t = 0,
            .front_face = false,
        };
    }

    /// Sets the hit record normal vector.
    // NOTE: the parameter `outward_normal` is assumed to have unit length.
    pub fn setFaceNormal(self: *Record, r: *const Ray, outward_normal: Vec3) void {
        self.front_face = r.direction.dot(outward_normal) < 0;
        self.normal = if (self.front_face) outward_normal else outward_normal.mulScalar(-1);
    }
};

ptr: *const anyopaque,
hitFn: *const fn (ptr: *const anyopaque, r: *const Ray, ray_t: Interval, hit_record: ?*Record) bool,

pub fn init(ptr: anytype) Self {
    const T = @TypeOf(ptr);
    const ptr_info = @typeInfo(T);

    const gen = struct {
        pub fn hit(self_ptr: *const anyopaque, r: *const Ray, ray_t: Interval, hit_record: ?*Record) bool {
            const self: T = @ptrCast(@alignCast(@constCast(self_ptr)));
            return @call(.always_inline, ptr_info.Pointer.child.hit, .{ self, r, ray_t, hit_record });
        }
    };

    return .{
        .ptr = ptr,
        .hitFn = gen.hit,
    };
}

pub inline fn hit(self: Self, r: *const Ray, ray_t: Interval, hit_record: ?*Record) bool {
    return self.hitFn(self.ptr, r, ray_t, hit_record);
}

pub const List = struct {
    objects: std.ArrayList(Self),

    pub fn init(allocator: std.mem.Allocator) List {
        return .{ .objects = std.ArrayList(Self).init(allocator) };
    }

    pub fn add(self: *List, obj: Self) !void {
        try self.objects.append(obj);
    }

    pub fn clear(self: *List) void {
        self.objects.clearRetainingCapacity();
    }

    pub fn deinit(self: *List) void {
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
