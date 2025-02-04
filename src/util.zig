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
