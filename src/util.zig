const std = @import("std");

var rng = std.rand.DefaultPrng.init(0);

pub fn degreesToRadians(degrees: f64) f64 {
    return degrees * std.math.pi / 180.0;
}

pub fn randomDouble() f64 {
    return rng.random().float(f64);
}

pub fn randomDoubleInRange(min: f64, max: f64) f64 {
    return min + randomDouble() * (max - min);
}

pub const Interval = struct {
    min: f64,
    max: f64,

    pub fn init(min: f64, max: f64) Interval {
        return Interval{
            .min = min,
            .max = max,
        };
    }

    pub fn size(self: Interval) f64 {
        return self.max - self.min;
    }

    pub fn contains(self: Interval, x: f64) bool {
        return self.min <= x and x <= self.max;
    }

    pub fn surrounds(self: Interval, x: f64) bool {
        return self.min < x and x < self.max;
    }

    pub fn clamp(self: Interval, x: f64) f64 {
        if (x < self.min) return self.min;
        if (x > self.max) return self.max;
        return x;
    }

    pub const empty = Interval.init(0, 0);
    pub const universe = Interval.init(-std.math.inf(f64), std.math.inf(f64));
};
