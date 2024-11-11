const std = @import("std");
const Tokenizer = @import("./tokenizer.zig");
const Token = Tokenizer.Token;
const parseFloat = std.fmt.parseFloat;
const parseInt = std.fmt.parseInt;
const HashMap = std.StringArrayHashMap(JsonUnionType);
const eql = std.mem.eql;
const pga = std.heap.page_allocator;
const JsonUnionType = union(enum) {
    String: []u8,
    Map: HashMap,
    Array: []JsonUnionType,
    Number: i32,
    Float: f64,
    Null: u8,
    Boolean: bool,
};

fn strcmp(a: []u8, b: []const u8) bool {
    return eql(u8, a, b);
}

pub const Parser = struct {
    position: usize = 0,
    current: Token = undefined,
    tokenVals: Tokenizer.TokenList = undefined,
    alloc: Tokenizer.Allocator = undefined,
    // jsonHashMap: HashMap,
    tokenizer: Tokenizer.Tokenizer = undefined,

    pub fn init(alloc: Tokenizer.Allocator, data: []u8) !Parser {
        var tokenizer = Tokenizer.Tokenizer.getData(data, alloc);
        const tokenVals = try tokenizer.tokenize();
        return .{
            .tokenizer = tokenizer,
            .tokenVals = tokenVals,
            .current = tokenVals.items[0],
            .alloc = alloc,
            // .jsonHashMap = HashMap.init(pga),
        };
    }
    pub fn deinit(self: *Parser) void {
        self.tokenizer.deinit();
        // self.jsonHashMap.deinit();
    }

    fn advance(self: *Parser) Token {
        self.position += 1;
        // std.debug.print("Current Position: {d}\nCurrent Token: {any}\n\n", .{self.position, self.current.type});
        if((self.position) < (self.tokenVals.items.len)) {
            self.current = self.tokenVals.items[self.position];
        }
        return self.current;
    }
    fn peek(self: *Parser) Token {
        if((self.position + 1) < (self.tokenVals.items.len)) {
            return self.tokenVals.items[self.position + 1];
        }
        return self.current;
    }

    pub fn parseArray(self: *Parser, key: []u8, jsonHashMap: *HashMap) !void {
        var arrayItems = Tokenizer.ArrayList(JsonUnionType).init(pga);
        while (self.current.type != .ArrRightBracket) {
            switch (self.current.type) {
                .String => {
                    try arrayItems.append(JsonUnionType{ .String = self.current.value });

                },
                .Float => {
                    const number = try parseFloat(f64, self.current.value);
                    try arrayItems.append(JsonUnionType{ .Float = number });
                },
                .Number => {
                    const number = try parseInt(i32, self.current.value, 10);
                    try arrayItems.append(JsonUnionType{ .Number = number });
                },
                .Boolean => {
                    try arrayItems.append(JsonUnionType{ .Boolean = strcmp(self.current.value, "true") });
                },
                else => {}
            }

            _ = self.advance();
        }
        try jsonHashMap.put(key, .{ .Array = arrayItems.items });
    }

    pub fn parse(self: *Parser) !HashMap {
        var jsonHashMap = HashMap.init(pga);
        var key: []u8 = undefined;
        _ = self.advance();
        while (self.current.type != .RightBrace) {
            if (self.current.type == .String) {
                key = self.current.value;
                while (self.advance().type != .Comma) {
                    switch (self.current.type) {
                        .String => {
                            try jsonHashMap.put(key, .{ .String = self.current.value });
                        },
                        .Float => {
                            const number = try parseFloat(f64, self.current.value);
                            try jsonHashMap.put(key, .{ .Float = number });
                        },
                        .Number => {
                            const number = try parseInt(i32, self.current.value, 10);
                            try jsonHashMap.put(key, .{ .Number = number });
                        },
                        .Boolean => {
                            const truth: []const u8 = "true";
                            try jsonHashMap.put(key, .{ .Boolean = strcmp(self.current.value, truth) });
                        },
                        .Null => {
                            try jsonHashMap.put(key, .{ .Null = 0 });
                        },
                        .ArrLeftBracket => {
                            _ = self.advance();
                            try self.parseArray(key, &jsonHashMap);
                        },
                        .LeftBrace => {
                            try jsonHashMap.put(key, .{ .Map = try self.parse() });
                        },
                        else => {
                            // std.debug.print("Invalid ValueType: {any}\n", .{self.current.type});
                        },
                    }
                    if(self.peek().type == .NewLine) {
                        break;
                    }
                }
                //     } else {
        //         std.process.exit(1);
        //     }
        }
            _ = self.advance();
        }
        std.debug.print("Json Length: {d}\n\n", .{jsonHashMap.keys().len});
        std.debug.print("Key\t->\tValue\n", .{});
        for (jsonHashMap.keys()) |value| {
            std.debug.print("{s}: {any}\n\n", .{value, jsonHashMap.get(value)});
        }

        return jsonHashMap;
    }
};
