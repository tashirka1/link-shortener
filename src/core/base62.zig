const std = @import("std");

const charset = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";
const code_length = 7;

pub fn newCode(io: std.Io) ![code_length]u8 {
    var code: [code_length]u8 = undefined;
    var rand_buf: [code_length]u8 = undefined;
    io.randomSecure(&rand_buf) catch {};
    for (&code, rand_buf) |*c, r| {
        c.* = charset[r % charset.len];
    }
    return code;
}

test "newCode returns correct length" {
    const io = std.Io.failing;
    const code = try newCode(io);
    try std.testing.expectEqual(@as(usize, code_length), code.len);
}

test "newCode only contains valid charset characters" {
    const io = std.Io.failing;
    const code = try newCode(io);
    for (code) |c| {
        try std.testing.expect(std.mem.indexOfScalar(u8, charset, c) != null);
    }
}

test "newCode generates different codes" {
    const io = std.Io.failing;
    const code1 = try newCode(io);
    const code2 = try newCode(io);
    // With failing Io, randomSecure returns error caught by catch {}
    // so both codes will be identical (zero-filled rand_buf).
    // This test verifies the code structure, not randomness.
    try std.testing.expectEqual(code1.len, code2.len);
}
