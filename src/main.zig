const std = @import("std");
const Parser = @import("./parser.zig");
const File = std.fs.File;
const HashMap = Parser.HashMap;
const JsonUnionType = Parser.JsonUnionType;
const writer = std.io.getStdOut().writer();
const arguments = std.process.argsAlloc;
const gpa = std.heap.GeneralPurposeAllocator(.{});

fn printMap(valkey: ?[]const u8, map: HashMap) !void {
    if (valkey) |keyValue| {
        try writer.print("{s}\t -> \t[\n", .{keyValue});
    }
    for (map.keys()) |key| {
        const Optvalue = map.get(key);
        if (valkey) |_| {
            try writer.print("\t\t", .{});
        }
        if (Optvalue) |value| {
            switch (value) {
                .String => {
                    try writer.print("{s}\t -> \t{s}\n\n", .{ key, value.String });
                },
                .Number => {
                    try writer.print("{s}\t -> \t{d}\n\n", .{ key, value.Number });
                },
                .Boolean => {
                    try writer.print("{s}\t -> \t{any}\n\n", .{ key, value.Boolean });
                },
                .Float => {
                    try writer.print("{s}\t -> \t{d}\n\n", .{ key, value.Float });
                },
                .Null => {
                    try writer.print("{s}\t -> \tNULL,\n\n", .{key});
                },
                .Map => {
                    try printMap(key, value.Map);
                },
                .Array => {
                    try printArray(key, value.Array);
                },
            }
        } else {
            std.process.exit(2);
        }
    }
}

pub fn main() !void {
    var gpAlloc = gpa.init;
    const alloc = gpAlloc.allocator();
    defer {
        const check = gpAlloc.deinit();
        switch (check) {
            .ok => {},
            .leak => {},
        }
    }
    const args = try arguments(std.heap.page_allocator);
    // defer alloc.free(args);

    if (args.len < 2) {
        try std.io.getStdOut().writer().print("JParser\nVersion: 1\nA simple cli program that takes a json file as an input and returns its data in a readable form\tWritten and developed by AndroidJester (https://github.com/AndroidJester)\n", .{});
        std.process.exit(0);
    } else if (args.len > 2) {
        try std.io.getStdOut().writer().print("JParser\nVersion: 1\nA simple cli program that takes a json file as an input and returns its data in a readable form\tWritten and developed by AndroidJester (https://github.com/AndroidJester)\n", .{});
        try std.io.getStdErr().writer().print("\nERROR: Too Many Arguments\n", .{});
        std.process.exit(0);
    }

    const jsonFile = try std.fs.cwd().openFile(args[1], File.OpenFlags{ .mode = .read_only });
    const fileMeta = try jsonFile.metadata();
    const fileData = try jsonFile.readToEndAlloc(alloc, fileMeta.size());
    var parser = try Parser.Parser.init(alloc, fileData);
    defer parser.deinit();
    const hashmap = try parser.parse();
    try printMap(null, hashmap);
}

fn printArray(key: []const u8, arr: []JsonUnionType) !void {
    try writer.print("{s}\t -> \t: [ ", .{key});
    for (arr) |arrValue| {
        switch (arrValue) {
            .String => {
                try writer.print("\"{s}\" ", .{arrValue.String});
            },

            .Number => {
                try writer.print("{d} ", .{arrValue.Number});
            },
            .Boolean => {
                try writer.print("{any} ", .{arrValue.Boolean});
            },
            .Float => {
                try writer.print("{d} ", .{arrValue.Float});
            },
            .Null => {
                try writer.print("NULL", .{});
            },
            .Map => {
                //     try printMap(key, arrValue.Map);
            },
            .Array => {
                try printArray(key, arrValue.Array);
            },
        }
    }
    try writer.print(" ]\n\n", .{});
}
