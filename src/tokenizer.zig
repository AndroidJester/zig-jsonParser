const std = @import("std");
const ascii = std.ascii;
pub const contains = std.mem.containsAtLeast;
pub const TokenList = std.ArrayList(Token);
pub const ArrayList = std.ArrayList;
pub const Allocator = std.mem.Allocator;
const eql = std.mem.eql;
pub const TokenType = enum {
    LeftBrace,
    RightBrace,
    ArrLeftBracket,
    ArrRightBracket,
    String,
    Colon,
    Number,
    Float,
    Comma,
    NewLine,
    Boolean,
    Null,
    // Comment,
};

pub const Token = struct {
    type: TokenType = undefined,
    value: []u8 = undefined,

    pub fn add(jsonType: TokenType, value: []u8) Token {
        return .{
            .type = jsonType,
            .value = value,
        };
    }
};

fn chrcmp(a: u8, b: u8) bool {
    return a == b;
}

fn strcmp(a: []u8, b: []const u8) bool {
    return eql(u8, a, b);
}

fn chrncmp(a: u8, b: u8) bool {
    return a != b;
}

pub const Tokenizer = struct {
    alloc: Allocator = undefined,
    position: usize = 0,
    currentValue: u8 = undefined,
    tokenVals: TokenList = undefined,
    data: []u8 = undefined,
    bufferList: ArrayList(ArrayList(u8)) = undefined,

    pub fn getData(data: []u8, alloc: Allocator) Tokenizer {
        return .{
            .alloc = alloc,
            .tokenVals = TokenList.init(alloc),
            .data = data,
            .currentValue = data[0],
            .bufferList = ArrayList(ArrayList(u8)).init(alloc),
        };
    }

    pub fn deinit(self: *Tokenizer) void {
        self.alloc.free(self.data);
        self.tokenVals.deinit();
        self.bufferList.deinit();
    }

    fn advance(self: *Tokenizer) u8 {
        self.position += 1;
        if (self.position < self.data.len) {
            self.currentValue = self.data[self.position];
        }
        return self.currentValue;
    }

    fn add(self: *Tokenizer, jsonType: TokenType, value: []u8) !void {
        try self.tokenVals.append(Token.add(jsonType, value));
    }

    fn tokenizeNumber(self: *Tokenizer) !void {
        var val = self.currentValue;
        var buffer = ArrayList(u8).init(std.heap.page_allocator);
        try self.bufferList.append(buffer);
        if (val == '-') {
            try buffer.append(val);
        }
        while (chrncmp(val, ',') and chrncmp(self.currentValue, '\n')) {
            try buffer.append(val);
            val = self.advance();
        }
        if (contains(u8, buffer.items, 1, ".")) {
            try self.add(.Float, buffer.items);
        } else {
            try self.add(.Number, buffer.items);
        }
    }

    fn tokenizeString(self: *Tokenizer) !void {
        var val = self.advance();
        var buffer = ArrayList(u8).init(std.heap.page_allocator);
        try self.bufferList.append(buffer);
        while (chrncmp(val, '"')) {
            if (self.position > self.data.len) {
                try std.io.getStdErr().writer().print("Invalid Json Detected: Unterminated String\n", .{});
                std.process.exit(0);
            }
            try buffer.append(val);
            val = self.advance();
        }
        try self.add(.String, buffer.items);
    }

    fn tokenizeBool(self: *Tokenizer) !void {
        var val = self.currentValue;
        var buffer = ArrayList(u8).init(std.heap.page_allocator);
        try self.bufferList.append(buffer);

        while (chrncmp(val, ',') and chrncmp(val, '\n')) {
            try buffer.append(val);
            val = self.advance();
        }

        if (strcmp(buffer.items, "true") != true and strcmp(buffer.items, "false") != true) {
            try std.io.getStdErr().writer().print("Invalid Json Detected: Wrong bool Values\n", .{});
            std.process.exit(2);
        }
        try self.add(.Boolean, buffer.items);
    }

    pub fn tokenize(self: *Tokenizer) !TokenList {
        while (self.position < self.data.len) {
            const res: []u8 = self.data[self.position..(self.position + 1)];
            if (ascii.isDigit(self.currentValue) or chrcmp(self.currentValue, '-')) {
                try self.tokenizeNumber();
                continue;
            } else if (chrcmp(self.currentValue, '"')) {
                try self.tokenizeString();
            } else if (chrcmp('t', self.currentValue) or chrcmp('f', self.currentValue)) {
                try self.tokenizeBool();
                continue;
            } else {
                switch (self.currentValue) {
                    '{' => {
                        try self.add(.LeftBrace, res);
                    },
                    '}' => {
                        try self.add(.RightBrace, res);
                    },
                    ':' => {
                        try self.add(.Colon, res);
                    },

                    '[' => {
                        try self.add(.ArrLeftBracket, res);
                    },
                    ']' => {
                        try self.add(.ArrRightBracket, res);
                    },
                    // '\n' => {
                    //     try self.add(.NewLine, res);
                    // },
                    ',' => {
                        try self.add(.Comma, res);
                    },
                    'n' => {
                        var buffer = ArrayList(u8).init(std.heap.page_allocator);
                        try self.bufferList.append(buffer);
                        while (chrncmp(self.currentValue, ',')) {
                            try buffer.append(self.currentValue);
                            _ = self.advance();
                        }
                        try self.add(.Null, buffer.items);
                        continue;
                    },
                    else => {
                        if (ascii.isAlphanumeric(self.currentValue)) {
                            try std.io.getStdErr().writer().print("Invalid Json Detected: Invalid String\n", .{});
                            std.process.exit(1);
                        }

                        if (chrcmp(self.currentValue, '/')) {
                            if (chrcmp(self.advance(), '/')) {
                                while (self.currentValue != '\n') {
                                    _ = self.advance();
                                }
                            } else {
                                try std.io.getStdErr().writer().print("Invalid Json Detected: Invalid Comment\n", .{});
                                std.process.exit(1);
                            }
                        }
                    },
                }
            }
            _ = self.advance();
        }

        return self.tokenVals;
    }
};
