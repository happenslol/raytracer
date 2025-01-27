const std = @import("std");
const Self = @This();

x: f64,
y: f64,
z: f64,

pub fn init(x: f64, y: f64, z: f64) Self {
    return Self{
        .x = x,
        .y = y,
        .z = z,
    };
}

pub fn add(self: Self, other: Self) Self {
    return Self.init(
        self.x + other.x,
        self.y + other.y,
        self.z + other.z,
    );
}

pub fn sub(self: Self, other: Self) Self {
    return Self.init(
        self.x - other.x,
        self.y - other.y,
        self.z - other.z,
    );
}

pub fn mul(self: Self, other: Self) Self {
    return Self.init(
        self.x * other.x,
        self.y * other.y,
        self.z * other.z,
    );
}

pub fn div(self: Self, other: Self) Self {
    return Self.init(
        self.x / other.x,
        self.y / other.y,
        self.z / other.z,
    );
}

pub fn mulScalar(self: Self, scalar: f64) Self {
    return Self.init(
        self.x * scalar,
        self.y * scalar,
        self.z * scalar,
    );
}

pub fn divScalar(self: Self, scalar: f64) Self {
    return self.mulScalar(1.0 / scalar);
}

pub fn normalize(self: Self) Self {
    return self.divScalar(self.length());
}

pub fn cross(self: Self, other: Self) Self {
    return Self.init(
        self.y * other.z - self.z * other.y,
        self.z * other.x - self.x * other.z,
        self.x * other.y - self.y * other.x,
    );
}

pub fn dot(self: Self, other: Self) f64 {
    return self.x * other.x + self.y * other.y + self.z * other.z;
}

pub fn length(self: Self) f64 {
    return std.math.sqrt(self.lengthSquared());
}

pub fn lengthSquared(self: Self) f64 {
    return self.x * self.x + self.y * self.y + self.z * self.z;
}

pub fn format(
    self: Self,
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = fmt;
    _ = options;

    try writer.print("Vec3({d:.3}, {d:.3}, {d:.3})", .{ self.x, self.y, self.z });
}

pub fn writePixel(self: Self, dest: []u8, offset: usize) void {
    dest[offset + 0] = @intFromFloat(self.x * 255.999);
    dest[offset + 1] = @intFromFloat(self.y * 255.999);
    dest[offset + 2] = @intFromFloat(self.z * 255.999);
}

const test_allocator = std.testing.allocator;

test "Vec3 formatting" {
    const vec = Self.init(1.0, 2.0, 3.0);

    const vec_str = try std.fmt.allocPrint(test_allocator, "{}", .{vec});
    defer test_allocator.free(vec_str);

    try std.testing.expectEqualStrings(vec_str, "Vec3(1.000, 2.000, 3.000)");
}
