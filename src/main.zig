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
    const comp = 4;
    const stride = image_width * comp;

    const data = try allocator.alloc(u8, image_height * image_width * comp);
    defer allocator.free(data);

    for (0.., data) |i, *pixel| {
        pixel.* = @truncate(i % 256);
    }

    const result = stbImageWrite.stbi_write_png("./out.png", image_height, image_width, comp, @ptrCast(data), stride);
    if (result == 0) {
        std.debug.print("Failed to write out.png\n", .{});
        return;
    }

    std.debug.print("Wrote out.png\n", .{});
}
