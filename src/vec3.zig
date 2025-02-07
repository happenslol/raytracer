const std = @import("std");
const util = @import("util.zig");
const Interval = util.Interval;

pub const vec3 = @Vector(4, f64);

pub inline fn init(x: f64, y: f64, z: f64) vec3 {
    return .{ x, y, z, 0 };
}

pub inline fn scalar(s: f64) vec3 {
    return @splat(s);
}

pub inline fn random() vec3 {
    return .{
        util.randomDouble(),
        util.randomDouble(),
        util.randomDouble(),
    };
}

pub inline fn randomInRange(min: f64, max: f64) vec3 {
    return init(
        util.randomDoubleInRange(min, max),
        util.randomDoubleInRange(min, max),
        util.randomDoubleInRange(min, max),
    );
}

pub inline fn randomUnit() vec3 {
    while (true) {
        const p = randomInRange(-1, 1);
        const len_sq = lengthSquared(p);

        // Small values can underflow to zero, so we need to check for this
        if (1e-160 < len_sq and len_sq <= 1)
            // Normalize whil avoiding calculating length squared twice
            return p / scalar(std.math.sqrt(len_sq));
    }
}

pub inline fn randomOnHemisphere(normal: vec3) vec3 {
    const p = randomUnit();
    return if (dot(p, normal) > 0) p else p * scalar(-1);
}

pub inline fn randomInUnitDisk() vec3 {
    while (true) {
        const p = init(
            util.randomDoubleInRange(-1, 1),
            util.randomDoubleInRange(-1, 1),
            0,
        );
        if (lengthSquared(p) < 1) return p;
    }
}

pub inline fn normalize(v: vec3) vec3 {
    return v / scalar(length(v));
}

pub inline fn cross(a: vec3, b: vec3) vec3 {
    return init(
        a[1] * b[2] - a[2] * b[1],
        a[2] * b[0] - a[0] * b[2],
        a[0] * b[1] - a[1] * b[0],
    );
}

pub inline fn dot(a: vec3, b: vec3) f64 {
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
}

pub inline fn length(x: vec3) f64 {
    return std.math.sqrt(lengthSquared(x));
}

pub inline fn lengthSquared(x: vec3) f64 {
    return x[0] * x[0] + x[1] * x[1] + x[2] * x[2];
}

pub inline fn nearZero(x: vec3) bool {
    const s = 1e-8;
    return @abs(x[0]) < s and @abs(x[1]) < s and @abs(x[2]) < s;
}

pub inline fn reflect(x: vec3, normal: vec3) vec3 {
    return x - (normal * scalar(2 * dot(x, normal)));
}

pub inline fn refract(x: vec3, normal: vec3, etai_over_etat: f64) vec3 {
    const cos_theta = @min(dot(x * scalar(-1), normal), 1);
    const r_out_perp = (x + (normal * scalar(cos_theta))) * scalar(etai_over_etat);
    const r_out_parallel = normal * scalar(@sqrt(@abs(1 - lengthSquared(r_out_perp))) * -1);
    return r_out_perp + r_out_parallel;
}

const intensity = Interval.init(0, 0.999);

fn linearToGamma(linear_component: f64) f64 {
    if (linear_component > 0)
        return @sqrt(linear_component);

    return 0;
}

pub fn writePixel(x: vec3, dest: []u8, offset: usize) void {
    const r = linearToGamma(x[0]);
    const g = linearToGamma(x[1]);
    const b = linearToGamma(x[2]);

    // Translate the [0,1] component values to the byte range [0,255].
    dest[offset + 0] = @intFromFloat(256 * intensity.clamp(r));
    dest[offset + 1] = @intFromFloat(256 * intensity.clamp(g));
    dest[offset + 2] = @intFromFloat(256 * intensity.clamp(b));
}

const test_allocator = std.testing.allocator;

test "vec3 formatting" {
    const vec = init(1, 2, 3);

    const vec_str = try std.fmt.allocPrint(test_allocator, "{}", .{vec});
    defer test_allocator.free(vec_str);

    try std.testing.expectEqualStrings(vec_str, "vec3(1.000, 2.000, 3.000)");
}
