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
        self.current = self.tokenVals.items[self.position];
        return self.current;
    }

    pub fn parseArray(self: *Parser, key: []u8, jsonHashMap: *HashMap) !void {
        var currentVal = self.current;
        switch (currentVal.type) {
            .String => {
                var arrayItems = Tokenizer.ArrayList(JsonUnionType).init(pga);
                while (currentVal.type != .ArrRightBracket) {
                    if(currentVal.type == .String) {
                       try arrayItems.append(JsonUnionType{.String = currentVal.value});
                        currentVal = self.advance();
                    }
                }
                try jsonHashMap.put(key, .{.Array = arrayItems.items});

            },
            .Float => {
                var arrayItems = Tokenizer.ArrayList(JsonUnionType).init(self.alloc);
                while (currentVal.type != .ArrRightBracket) {
                    if(currentVal.type == .Float) {
                        const number = try parseFloat(f64, currentVal.value);
                        try arrayItems.append(JsonUnionType{ .Float = number });
                        currentVal = self.advance();
                    }
                }
                try jsonHashMap.put(key, .{.Array = arrayItems.items});

            },
            .Number => {
                var arrayItems = Tokenizer.ArrayList(JsonUnionType).init(self.alloc);
                while (currentVal.type != .ArrRightBracket) {
                    if(currentVal.type == .Number) {
                        const number = try parseInt(i32, currentVal.value, 10);

                        try arrayItems.append(JsonUnionType{ .Number = number });
                        currentVal = self.advance();
                    }
                }
                try jsonHashMap.put(key, .{.Array = arrayItems.items});

            },
            .Boolean => {
                var arrayItems = Tokenizer.ArrayList(JsonUnionType).init(self.alloc);
                while (currentVal.type != .ArrRightBracket) {
                    if(currentVal.type == .Boolean) {
                        try arrayItems.append(JsonUnionType { .Boolean = strcmp(currentVal.value, "true") });
                        currentVal = self.advance();
                    }
                }
                try jsonHashMap.put(key, .{.Array = arrayItems.items});
            },
            else => {},
        }
    }


    pub fn parse(self: *Parser) !HashMap {
        var jsonHashMap = HashMap.init(self.alloc);
        var key: []u8 = undefined;
        var currentVal = self.current;
        while (currentVal.type != .RightBrace) {
                if(currentVal.type == .String) {
                    key = currentVal.value;
                    currentVal = self.advance();
                    while (currentVal.type != .Comma) {
                        std.debug.print("Current Position: {d}\nCurrent ValueType: {any}\nCurrent Value: {s}\n\n", .{self.position, currentVal.type, currentVal.value});
                        switch (currentVal.type) {
                            .String => {
                                try jsonHashMap.put(key, .{ .String = currentVal.value });
                            },
                            .Float => {
                                const number = try parseFloat(f64, currentVal.value);
                                try jsonHashMap.put(key, .{.Float = number});
                            },
                            .Number => {
                                const number = try parseInt(i32, currentVal.value, 10);
                                try jsonHashMap.put(key, .{.Number = number});
                            },
                            .Boolean => {
                                const truth: []const u8 = "true";
                                try jsonHashMap.put(key, .{.Boolean = strcmp(currentVal.value, truth)});
                            },
                            .ArrLeftBracket => {
                                currentVal = self.advance();
                                try self.parseArray(key, &jsonHashMap);
                            },
                            .LeftBrace => {
                                try jsonHashMap.put(key, .{.Map = try self.parse()});
                            },
                            else => {},
                        }
                        currentVal = self.advance();
                    }
                    break;
                }
        }

        return jsonHashMap;
    }
};