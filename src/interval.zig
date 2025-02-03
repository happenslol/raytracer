const std = @import("std");
const Self = @This();

min: f64,
max: f64,

pub fn init(min: f64, max: f64) Self {
    return Self{
        .min = min,
        .max = max,
    };
}

pub fn size(self: Self) f64 {
    return self.max - self.min;
}

pub fn contains(self: Self, x: f64) bool {
    return self.min <= x and x <= self.max;
}

pub fn surrounds(self: Self, x: f64) bool {
    return self.min < x and x < self.max;
}

pub const empty = Self.init(0, 0);
pub const universe = Self.init(-std.math.inf(f64), std.math.inf(f64));
