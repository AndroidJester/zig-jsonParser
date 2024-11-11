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
    Boolean
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

fn chrcmp(a: u8, b:u8) bool {
    return a == b;
}

fn chrncmp(a: u8, b:u8) bool {
    return a != b;
}


fn strncmp(a: u8, b:u8) bool {
    return !(eql(u8, a, b));
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
        self.currentValue = self.data[self.position];
        return self.currentValue;
    }

    fn add(self: *Tokenizer, jsonType: TokenType, value: []u8) !void {
        try self.tokenVals.append(Token.add(jsonType, value));
    }

    fn tokenizeNumber(self: *Tokenizer) !void {
        var val = self.currentValue;
        var buffer = ArrayList(u8).init(self.alloc);
        try self.bufferList.append(buffer);
        // std.debug.print("Position: {d}\nCurrent Value: {c}\n", .{self.position, self.currentValue});
        std.debug.print("[START] Number Tokenizing\n\n", .{});
        std.debug.print("Position: {d}\nCurrent Value: {c}\n\n", .{self.position, self.currentValue});
        if(val == '-') {
            try buffer.append(val);
        }
        while(chrncmp(val, ',') and chrncmp(self.currentValue, '\n')) {
            std.debug.print("Position: {d}\nCurrent Value: {c}\n\n", .{self.position, self.currentValue});
            // std.debug.print("Position: {d}\nCurrent Value: {c}\n", .{self.position, self.currentValue});
            try buffer.append(val);
            val = self.advance();
        }

        if(contains(u8, buffer.items, 1, ".")) {
            try self.add(.Float, buffer.items);
        } else {
            try self.add(.Number, buffer.items);
        }
        std.debug.print("[END] Number Tokenizing\n\n", .{});

    }

    fn tokenizeString(self: *Tokenizer) !void {
        var val = self.advance();
        var buffer = ArrayList(u8).init(self.alloc);
        try self.bufferList.append(buffer);
        std.debug.print("[START]String Tokenizing\n\n", .{});
        std.debug.print("Position: {d}\nCurrent Value: {c}\n\n", .{self.position, self.currentValue});
        while(chrncmp(val, '"')) {
            std.debug.print("Position: {d}\nCurrent Value: {c}\n\n", .{self.position, self.currentValue});
            try buffer.append(val);
            val = self.advance();
        }
        val = self.advance();
        try self.add(.String, buffer.items);
        std.debug.print("[END]String Tokenizing\n\n", .{});

    }

    fn tokenizeBool(self: *Tokenizer) !void {
        var val = self.currentValue;
        var buffer = ArrayList(u8).init(self.alloc);
        try self.bufferList.append(buffer);
        std.debug.print("[START] Boolean Tokenizing\n\n", .{});
        std.debug.print("Position: {d}\nCurrent Value: {c}\n\n", .{self.position, self.currentValue});

        while(chrncmp(val, ',') and chrncmp(val, '\n')) {
            std.debug.print("Position: {d}\nCurrent Value: {c}\n\n", .{self.position, self.currentValue});
            try buffer.append(val);
            val = self.advance();
        }
        try self.add(.Boolean, buffer.items);
        std.debug.print("[END] Boolean Tokenizing End\n\n", .{});

    }

    pub fn tokenize(self: *Tokenizer) !TokenList {
        while(self.position < self.data.len) {
            std.debug.print("Position: {d}\nCurrent Value: {c}\n\n", .{self.position, self.currentValue});
            const res: []u8 = self.data[self.position..(self.position + 1)];
            if(ascii.isDigit(self.currentValue) or chrcmp(self.currentValue, '-')) {
                try self.tokenizeNumber();
            } else if(chrcmp(self.currentValue, '"')) {
                try self.tokenizeString();
            } else if(chrcmp('t', self.currentValue) or chrcmp('f', self.currentValue)) {
                try self.tokenizeBool();
            }  else {
                switch (self.currentValue) {
                    '{' => {
                        try self.add(.LeftBrace, res);
                    },
                    '}' => {
                        try self.add(.RightBrace, res);
                        break;
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

                    ',' => {
                        try self.add(.Comma, res);

                    },
                    '\n' => {
                        try self.add(.NewLine, res);
                    },
                else => {}
                }
                _ = self.advance();

            }

        }
        return self.tokenVals;
    }

};