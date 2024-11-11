const std = @import("std");
const Parser = @import("./parser.zig");
const File = std.fs.File;
const arguments = std.process.argsAlloc;
const gpa = std.heap.GeneralPurposeAllocator(.{});
pub fn main() !void {
    var gpAlloc = gpa.init;
    const alloc = gpAlloc.allocator();
    defer {
        const check = gpAlloc.deinit();
        switch (check) {
            .ok => {
                std.debug.print("[++] No Leaks Detected\n", .{});
            },
            .leak => {
                std.debug.print("[++] Memory Leak Detected\n", .{});
            },
            },
        }
    }
    const args = try arguments(std.heap.page_allocator);
    // defer alloc.free(args);
    std.debug.print("[++] Program Start: Successful\n", .{});
    std.debug.print("[++] Arguments: {s}\n", .{args});
    const jsonFile = try std.fs.cwd().openFile(args[1], File.OpenFlags{ .mode = .read_only });
    const jsonFile = try std.fs.cwd().openFile(args[1], File.OpenFlags{ .mode = .read_only });
    const fileMeta = try jsonFile.metadata();
    const fileData = try jsonFile.readToEndAlloc(alloc, fileMeta.size());
    var parser = try Parser.Parser.init(alloc, fileData);
    defer parser.deinit();
    const hashmap = try parser.parse();
    _ = hashmap;
    // std.debug.print("Parsed Data: {s}", .{hashmap.keys()});
}

