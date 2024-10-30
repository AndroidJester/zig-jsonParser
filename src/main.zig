const std = @import("std");
const gpa = std.heap.GeneralPurposeAllocator(.{});
const Tokenizer = @import("./tokenizer.zig");
pub fn main() !void {
    var gpa_init = gpa{};
    const alloc = gpa_init.allocator();
    defer _ = gpa_init.deinit();

    const exit = std.process.exit;

    const args = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, args);

    std.debug.print("Args: {s}\n\n", .{args});

    if (args.len < 2) {
        _ = try std.io.getStdOut().write("The args are less");
        exit(1);
    }

    const file = try std.fs.cwd().openFile(args[1], .{
        .mode = .read_only,
    });
    const meta = try file.metadata();
    const fileData = try file.readToEndAlloc(alloc, meta.size());
    defer alloc.free(fileData);
    var tokenizer = Tokenizer.Tokenizer.getData(fileData, alloc);
    try tokenizer.tokenize();
    tokenizer.deinit();
}
