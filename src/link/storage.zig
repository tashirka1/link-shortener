const std = @import("std");
const zqlite = @import("zqlite");
const base62 = @import("../core/base62.zig");
const model = @import("model.zig");

pub fn createLink(conn: *zqlite.Conn, allocator: std.mem.Allocator, url: []const u8, user_id: i64, io: std.Io) !model.Link {
    const code = try base62.newCode(io);

    try conn.exec("INSERT INTO link_link(code, url, clicks, user_id) VALUES (?, ?, 0, ?) ON CONFLICT(user_id, url) DO NOTHING", .{ &code, url, user_id });

    var rows = try conn.rows("SELECT id, code, url, clicks, user_id, created_at FROM link_link WHERE user_id = ? AND code = ?", .{ user_id, &code });
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

    var rows = try conn.rows(
        "SELECT id, code, url, clicks, user_id, created_at FROM link_link WHERE user_id = ? AND id < ? ORDER BY id DESC LIMIT 5",
        .{ user_id, if (cursor == 0) std.math.maxInt(i64) else cursor },
    );
    defer rows.deinit();

    while (rows.next()) |row| {
        try list.append(allocator, .{
            .id = row.int(0),
            .code = try allocator.dupe(u8, row.text(1)),
            .url = try allocator.dupe(u8, row.text(2)),
            .clicks = row.int(3),
            .user_id = row.int(4),
            .created_at = try allocator.dupe(u8, row.nullableText(5) orelse ""),
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

fn ftsQuery(query: []const u8, allocator: std.mem.Allocator) ![]const u8 {
    var parts: std.ArrayList(u8) = .empty;
    var it = std.mem.tokenizeScalar(u8, query, ' ');
    var first = true;
    while (it.next()) |token| {
        if (!first) try parts.append(allocator, ' ');
        first = false;
        try parts.appendSlice(allocator, token);
        try parts.append(allocator, '*');
    }
    return try parts.toOwnedSlice(allocator);
}

pub fn searchLinks(conn: *zqlite.Conn, allocator: std.mem.Allocator, user_id: i64, query: []const u8) ![]model.Link {
    var list: std.ArrayListAligned(model.Link, null) = .empty;

    const fts_q = try ftsQuery(query, allocator);
    defer allocator.free(fts_q);

    var rows = try conn.rows(
        \\SELECT l.id, l.code, l.url, l.clicks, l.user_id, l.created_at
        \\FROM link_link l
        \\JOIN link_fts f ON l.id = f.rowid
        \\WHERE l.user_id = ? AND link_fts MATCH ?
        \\ORDER BY bm25(link_fts)
        \\LIMIT 20
    , .{ user_id, fts_q });
    defer rows.deinit();

    while (rows.next()) |row| {
        try list.append(allocator, .{
            .id = row.int(0),
            .code = try allocator.dupe(u8, row.text(1)),
            .url = try allocator.dupe(u8, row.text(2)),
            .clicks = row.int(3),
            .user_id = row.int(4),
            .created_at = try allocator.dupe(u8, row.nullableText(5) orelse ""),
        });
    }
    return list.toOwnedSlice(allocator);
}
