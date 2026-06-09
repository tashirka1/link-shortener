const std = @import("std");
const zqlite = @import("zqlite");
const model = @import("model.zig");

pub fn checkEmail(conn: *zqlite.Conn, allocator: std.mem.Allocator, email: []const u8) !model.User {
    var rows = try conn.rows("SELECT id, email, password FROM auth_user WHERE email = ?", .{email});
    defer rows.deinit();

    if (rows.next()) |row| {
        const user_email = try allocator.dupe(u8, row.text(1));
        const user_password = try allocator.dupe(u8, row.text(2));
        return .{
            .id = row.int(0),
            .email = user_email,
            .password = user_password,
        };
    }
    return model.UserError.UserNotFound;
}

pub fn createUser(conn: *zqlite.Conn, email: []const u8, hashed_password: []const u8) !void {
    try conn.exec("INSERT INTO auth_user(email, password) VALUES (?, ?)", .{ email, hashed_password });
}
