const std = @import("std");
const zqlite = @import("zqlite");
const storage = @import("storage.zig");
const model = @import("model.zig");

const argon2 = std.crypto.pwhash.argon2;

pub fn checkUser(conn: *zqlite.Conn, allocator: std.mem.Allocator, email: []const u8, password: []const u8, io: std.Io) !model.User {
    const user = try storage.checkEmail(conn, allocator, email);
    errdefer allocator.free(user.email);
    errdefer allocator.free(user.password);

    argon2.strVerify(user.password, password, .{ .allocator = allocator }, io) catch {
        return model.UserError.InvalidPassword;
    };
    return user;
}

pub fn createUser(conn: *zqlite.Conn, allocator: std.mem.Allocator, email: []const u8, password: []const u8, io: std.Io) !void {
    var hash_buf: [256]u8 = undefined;
    const hash = try argon2.strHash(password, .{ .allocator = allocator, .params = .{ .t = 3, .m = 19 * 1024, .p = 4 } }, &hash_buf, io);
    try storage.createUser(conn, email, hash);
}
