const std = @import("std");
const stbImageWrite = @cImport({
    @cInclude("stb_image_write.c");
});

pub fn main() !void {
    std.debug.print("Hello World\n", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const image_height = 256;
    const image_width = 256;
    const comp = 3;
    const stride = image_width * comp;

    const data = try allocator.alloc(u8, image_height * image_width * comp);
    defer allocator.free(data);

    for (0..image_height) |j| {
        for (0..image_width) |i| {
            const r = @as(f64, @floatFromInt(i)) / @as(f64, @floatFromInt((image_width - 1)));
            const g = @as(f64, @floatFromInt(j)) / @as(f64, @floatFromInt((image_height - 1)));
            const b = 0.0;

            data[(j * image_width + i) * comp + 0] = @intFromFloat(r * 255.999);
            data[(j * image_width + i) * comp + 1] = @intFromFloat(g * 255.999);
            data[(j * image_width + i) * comp + 2] = @intFromFloat(b * 255.999);
        }
    }

    const result = stbImageWrite.stbi_write_png("./out.png", image_height, image_width, comp, @ptrCast(data), stride);
    if (result == 0) {
        std.debug.print("Failed to write out.png\n", .{});
        return;
    }

    std.debug.print("Wrote out.png\n", .{});
}
