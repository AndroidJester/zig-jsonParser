const std = @import("std");
const ascii = std.ascii;
const rgx = @import("regex");
const gpa = std.heap.GeneralPurposeAllocator(.{});
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const parseInt = std.fmt.parseInt;
const parseFloat = std.fmt.parseFloat;
const writer = std.io.getStdOut().writer();
fn strcmp(a: u8, b: u8) bool {
    return (a == b);
    // return std.mem.eql(u8, a, b);
}

fn strncmp(a: u8, b: u8) bool {
    return (a != b);
    // return std.mem.eql(u8, a, b) == false;
}

const TokenType = enum {
    String,
    LeftBrace,
    RightBrace,
    Colon,
    ArrLeftBracket,
    ArrRightBracket,
    Number,
    Float,
    Bool,
};

const Token = struct {
        jsonType: TokenType,
        value: []u8,

        pub fn add(jsonType: TokenType, value: []u8) Token {
            return .{ .jsonType = jsonType, .value = value };
        }
};

const Tokenizer = struct {
    data: []u8 = undefined,
    currentValue: u8 = undefined,
    currentPosition: usize,
    tokenVals: ArrayList(Token) = undefined,
    alloc: Allocator = undefined,
    arrs: ArrayList(ArrayList(u8)) = undefined,
    pub fn getData(data: []u8, alloc: Allocator) Tokenizer {
        return .{
            .data = data,
            .currentPosition = 0,
            .currentValue = data[0],
            .alloc = alloc,
            .arrs = ArrayList(ArrayList(u8)).init(alloc),
        };
    }

    pub fn deinit(self: *Tokenizer) void {
        for(self.arrs.items) |items| {
            items.deinit();
        }
        self.arrs.deinit();
    }

    pub fn peek(self: *Tokenizer) u8 {
        return self.currentValue;
    }

    pub fn advance(self: *Tokenizer) u8 {
        const value = self.currentValue;
        if (self.currentPosition < (self.data.len - 1)) {
            self.currentPosition += 1;
            self.currentValue = self.data[self.currentPosition];
        }
        return value;
    }

    pub fn peekNext(self: *Tokenizer) u8 {
        self.currentValue = self.data[self.currentPosition + 1];
        return self.currentValue;
    }

    pub fn parseBool(self: *Tokenizer) !void {
        const alloc = std.heap.page_allocator;
        var boolArr = ArrayList(u8).init(alloc);
        while(ascii.isAlphabetic(self.currentValue) and (self.currentPosition < self.data.len) and (strncmp(self.currentValue, '\n') or strncmp(self.currentValue, ','))) {
            try boolArr.append(self.advance());
        }
        const boolv = boolArr.items;
        try self.tokenVals.append(Token.add(.Bool, boolv));
    }

    pub fn parseString(self: *Tokenizer) !void {
        const alloc = std.heap.page_allocator;
        var stringArr: ArrayList(u8) = ArrayList(u8).init(alloc);
        try self.arrs.append(stringArr);
        _ = self.advance();

        while (strncmp(self.currentValue, '\"') and (self.currentPosition < self.data.len - 1)) {
            try stringArr.append(self.advance());
        }
        const string: []u8 = stringArr.items[0..stringArr.items.len];
        try self.tokenVals.append(Token.add(.String, string));
    }

    pub fn parseNum(self: *Tokenizer) !void {
        const alloc = std.heap.page_allocator;
        var numArr: ArrayList(u8) = ArrayList(u8).init(alloc);
        try self.arrs.append(numArr);
        while ((strncmp(self.currentValue, '\n') or strncmp(self.currentValue, ',') or strncmp(self.currentValue, ' ')) and (self.currentPosition < self.data.len - 1)) {
            try numArr.append(self.advance());
        }
        // if (std.mem.containsAtLeast(u8, numArr.allocatedSlice(), 1, ".")) {
        //     const number = try parseFloat(f64, numArr.allocatedSlice());
        //     try self.tokenVals.append(.add(.Float, number));
        // } else {
        //     const number = try parseInt(i32, numArr.allocatedSlice(), 10);
        //     try self.tokenVals.append(.add(.Number, number));
        // }
        const values = numArr.items;
        try self.tokenVals.append(Token.add(.Float, values));
    }

    pub fn tokenize(self: *Tokenizer) !void {

        self.tokenVals = ArrayList(Token).init(self.alloc);
        defer self.tokenVals.deinit();

        while (self.currentPosition < self.data.len) {
            self.currentValue = self.data[self.currentPosition];
            const val = self.currentValue;
            const arr = [_]u8{val};
            const res: []u8 = arr[0..0];
            if (strcmp(val, '{')) {
                try self.tokenVals.append(Token.add(.LeftBrace, res ));
            } else if (strcmp(val, '}')) {
                try self.tokenVals.append(Token.add(.RightBrace, res));
            } else if (strcmp(val, '[')) {
                try self.tokenVals.append(Token.add(.ArrLeftBracket, res));
            } else if (strcmp(val, ']')) {
                try self.tokenVals.append(Token.add(.ArrRightBracket, res));
            } else if (strcmp(val, '"')) {
                try self.parseString();
            } else if (ascii.isDigit(val) or strcmp(val, '-')) {
                self.parseNum() catch unreachable;
            } else if (strcmp(val, '\n') or strcmp(val, ',') or strcmp(val, ' ')) {
                self.currentPosition += 1;
                continue;
            } else if (strcmp(val, ':')) {
                try self.tokenVals.append(Token.add(.Colon, res));
            } else if(strcmp(val, 't') or strcmp(val, 'f')) {
                try self.parseBool();
            }
            self.currentPosition += 1;
        }
        for (self.tokenVals.items) |value| {
        //
            std.debug.print("TokenType: {any}\nToken Value: {s}\n\n", .{value.jsonType, value.value});

        //     writer.print("Tokens Type: {any}\nToken Value: {s}\n\n", .{ value.jsonType, value.value }) catch |err| {
        //         std.debug.print("ERROR: {any}", .{err});
        //     };
        }
    }
};

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
    var tokenizer = Tokenizer.getData(fileData, alloc);
    try tokenizer.tokenize();
    tokenizer.deinit();
}
