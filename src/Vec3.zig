const std = @import("std");
const util = @import("util.zig");
const Interval = util.Interval;

const Vec3 = @This();

x: f64,
y: f64,
z: f64,

pub fn init(x: f64, y: f64, z: f64) Vec3 {
    return Vec3{
        .x = x,
        .y = y,
        .z = z,
    };
}

pub fn copy(self: *const Vec3) Vec3 {
    return Vec3.init(self.x, self.y, self.z);
}

fn random() Vec3 {
    return Vec3.init(
        util.randomDouble(),
        util.randomDouble(),
        util.randomDouble(),
    );
}

fn randomInRange(min: f64, max: f64) Vec3 {
    return Vec3.init(
        util.randomDoubleInRange(min, max),
        util.randomDoubleInRange(min, max),
        util.randomDoubleInRange(min, max),
    );
}

pub inline fn randomUnitVector() Vec3 {
    while (true) {
        const p = Vec3.randomInRange(-1.0, 1.0);
        const len_sq = p.lengthSquared();

        // Small values can underflow to zero, so we need to check for this
        if (1e-160 < len_sq and len_sq <= 1.0)
            // Normalize whil avoiding calculating length squared twice
            return p.divScalar(std.math.sqrt(len_sq));
    }
}

pub inline fn randomOnHemisphere(normal: *const Vec3) Vec3 {
    const p = Vec3.randomUnitVector();
    return if (p.dot(normal) > 0.0) p else p.mulScalar(-1.0);
}

pub fn add(self: Vec3, other: Vec3) Vec3 {
    return Vec3.init(
        self.x + other.x,
        self.y + other.y,
        self.z + other.z,
    );
}

pub fn sub(self: Vec3, other: Vec3) Vec3 {
    return Vec3.init(
        self.x - other.x,
        self.y - other.y,
        self.z - other.z,
    );
}

pub fn subScalar(self: Vec3, other: f64) Vec3 {
    return Vec3.init(self.x - other, self.y - other, self.z - other);
}

pub fn mul(self: Vec3, other: Vec3) Vec3 {
    return Vec3.init(
        self.x * other.x,
        self.y * other.y,
        self.z * other.z,
    );
}

pub fn div(self: Vec3, other: Vec3) Vec3 {
    return Vec3.init(
        self.x / other.x,
        self.y / other.y,
        self.z / other.z,
    );
}

pub fn mulScalar(self: Vec3, scalar: f64) Vec3 {
    return Vec3.init(
        self.x * scalar,
        self.y * scalar,
        self.z * scalar,
    );
}

pub fn divScalar(self: Vec3, scalar: f64) Vec3 {
    return self.mulScalar(1.0 / scalar);
}

pub inline fn normalize(self: Vec3) Vec3 {
    return self.divScalar(self.length());
}

pub fn cross(self: Vec3, other: Vec3) Vec3 {
    return Vec3.init(
        self.y * other.z - self.z * other.y,
        self.z * other.x - self.x * other.z,
        self.x * other.y - self.y * other.x,
    );
}

pub fn dot(self: Vec3, other: *const Vec3) f64 {
    return self.x * other.x + self.y * other.y + self.z * other.z;
}

pub fn length(self: Vec3) f64 {
    return std.math.sqrt(self.lengthSquared());
}

pub fn lengthSquared(self: Vec3) f64 {
    return self.x * self.x + self.y * self.y + self.z * self.z;
}

pub fn nearZero(self: Vec3) bool {
    const s = 1e-8;
    return @abs(self.x) < s and @abs(self.y) < s and @abs(self.z) < s;
}

pub inline fn reflect(self: Vec3, normal: *const Vec3) Vec3 {
    return self.sub(normal.*.mulScalar(2.0 * self.dot(normal)));
}

pub fn format(
    self: Vec3,
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = fmt;
    _ = options;

    try writer.print("Vec3({d:.3}, {d:.3}, {d:.3})", .{ self.x, self.y, self.z });
}

const intensity = Interval.init(0.0, 0.999);

fn linearToGamma(linear_component: f64) f64 {
    if (linear_component > 0)
        return @sqrt(linear_component);

    return 0;
}

pub fn writePixel(self: Vec3, dest: []u8, offset: usize) void {
    const r = linearToGamma(self.x);
    const g = linearToGamma(self.y);
    const b = linearToGamma(self.z);

    // Translate the [0,1] component values to the byte range [0,255].
    dest[offset + 0] = @intFromFloat(256.0 * intensity.clamp(r));
    dest[offset + 1] = @intFromFloat(256.0 * intensity.clamp(g));
    dest[offset + 2] = @intFromFloat(256.0 * intensity.clamp(b));
}

const test_allocator = std.testing.allocator;

test "Vec3 formatting" {
    const vec = Vec3.init(1.0, 2.0, 3.0);

    const vec_str = try std.fmt.allocPrint(test_allocator, "{}", .{vec});
    defer test_allocator.free(vec_str);

    try std.testing.expectEqualStrings(vec_str, "Vec3(1.000, 2.000, 3.000)");
}
