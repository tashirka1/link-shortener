const std = @import("std");

const charset = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";
const code_length = 7;

pub fn newCode(io: std.Io) ![code_length]u8 {
    var code: [code_length]u8 = undefined;
    var rand_buf: [code_length]u8 = undefined;
    try io.randomSecure(&rand_buf);

    var value: u56 = 0;
    for (rand_buf) |b| {
        value = (value << 8) | b;
    }
    for (&code) |*c| {
        c.* = charset[value % charset.len];
        value /= charset.len;
    }
    return code;
}

test "newCode returns correct length" {
    const io = std.testing.io;
    const code = try newCode(io);
    try std.testing.expectEqual(@as(usize, code_length), code.len);
}

test "newCode only contains valid charset characters" {
    const io = std.testing.io;
    const code = try newCode(io);
    for (code) |c| {
        try std.testing.expect(std.mem.indexOfScalar(u8, charset, c) != null);
    }
}

test "newCode generates different codes" {
    const io = std.testing.io;
    const code1 = try newCode(io);
    const code2 = try newCode(io);
    try std.testing.expect(!std.mem.eql(u8, &code1, &code2));
}
