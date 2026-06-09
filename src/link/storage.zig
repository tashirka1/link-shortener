const std = @import("std");
const zqlite = @import("zqlite");
const base62 = @import("../core/base62.zig");
const model = @import("model.zig");

pub fn createLink(conn: *zqlite.Conn, allocator: std.mem.Allocator, url: []const u8, user_id: i64, io: std.Io) !model.Link {
    const code = try base62.newCode(io);

    try conn.exec("INSERT INTO link_link(code, url, clicks, user_id) VALUES (?, ?, 0, ?) ON CONFLICT(user_id, url) DO NOTHING", .{ &code, url, user_id });

    var rows = try conn.rows("SELECT id, code, url, clicks, user_id, created_at FROM link_link WHERE user_id = ? AND url = ?", .{ user_id, url });
    defer rows.deinit();

    if (rows.next()) |row| {
        return .{
            .id = row.int(0),
            .code = try allocator.dupe(u8, row.text(1)),
            .url = try allocator.dupe(u8, row.text(2)),
            .clicks = row.int(3),
            .user_id = row.int(4),
            .created_at = try allocator.dupe(u8, row.nullableText(5) orelse ""),
        };
    }
    return model.LinkError.LinkAlreadyExists;
}

pub fn listLinks(conn: *zqlite.Conn, allocator: std.mem.Allocator, user_id: i64, cursor: i64) ![]model.Link {
    var list: std.ArrayListAligned(model.Link, null) = .empty;
    errdefer {
        for (list.items) |item| {
            allocator.free(item.code);
            allocator.free(item.url);
            allocator.free(item.created_at);
        }
        list.deinit(allocator);
    }

    var rows = try conn.rows(
        "SELECT id, code, url, clicks, user_id, created_at FROM link_link WHERE user_id = ? AND id < ? ORDER BY id DESC LIMIT 5",
        .{ user_id, if (cursor == 0) std.math.maxInt(i64) else cursor },
    );
    defer rows.deinit();

    while (rows.next()) |row| {
        const code = try allocator.dupe(u8, row.text(1));
        errdefer allocator.free(code);
        const url = try allocator.dupe(u8, row.text(2));
        errdefer allocator.free(url);
        const created_at = try allocator.dupe(u8, row.nullableText(5) orelse "");
        errdefer allocator.free(created_at);

        try list.append(allocator, .{
            .id = row.int(0),
            .code = code,
            .url = url,
            .clicks = row.int(3),
            .user_id = row.int(4),
            .created_at = created_at,
        });
    }
    return list.toOwnedSlice(allocator);
}

pub fn removeLink(conn: *zqlite.Conn, user_id: i64, code: []const u8) !void {
    try conn.exec("DELETE FROM link_link WHERE user_id = ? AND code = ?", .{ user_id, code });
}

pub fn getLink(conn: *zqlite.Conn, allocator: std.mem.Allocator, code: []const u8) ![]const u8 {
    var rows = try conn.rows("SELECT url FROM link_link WHERE code = ?", .{code});
    defer rows.deinit();

    if (rows.next()) |row| {
        return try allocator.dupe(u8, row.text(0));
    }
    return error.NotFound;
}

pub fn clickLink(conn: *zqlite.Conn, code: []const u8) !void {
    try conn.exec("UPDATE link_link SET clicks = clicks + 1 WHERE code = ?", .{code});
}
