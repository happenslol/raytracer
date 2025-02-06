const Vec3 = @import("Vec3.zig");
const Self = @This();

origin: Vec3,
direction: Vec3,

pub fn init(origin: Vec3, direction: Vec3) Self {
    return Self{
        .origin = origin,
        .direction = direction,
    };
}

pub fn at(self: Self, t: f64) Vec3 {
    return self.origin.add(self.direction.mulScalar(t));
}
