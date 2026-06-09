const std = @import("std");
const zqlite = @import("zqlite");
const storage = @import("storage.zig");
const model = @import("model.zig");

pub fn createLink(conn: *zqlite.Conn, allocator: std.mem.Allocator, url: []const u8, user_id: i64, io: std.Io) !model.Link {
    if (url.len > model.max_url_length) return error.UrlTooLong;
    return storage.createLink(conn, allocator, url, user_id, io);
}

pub fn listLinks(conn: *zqlite.Conn, allocator: std.mem.Allocator, user_id: i64, cursor: i64) ![]model.Link {
    return storage.listLinks(conn, allocator, user_id, cursor);
}

pub fn removeLink(conn: *zqlite.Conn, user_id: i64, code: []const u8) !void {
    return storage.removeLink(conn, user_id, code);
}

pub fn getLink(conn: *zqlite.Conn, allocator: std.mem.Allocator, code: []const u8) ![]const u8 {
    return storage.getLink(conn, allocator, code);
}

pub fn clickLink(conn: *zqlite.Conn, code: []const u8) !void {
    return storage.clickLink(conn, code);
}
