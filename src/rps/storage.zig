const std = @import("std");
const zqlite = @import("zqlite");

pub const JoinRow = struct {
    id: i64,
    payload: []const u8,
    ts: i64,
    duration: i64,
    meta_key: []const u8,
    meta_value: []const u8,
};

pub fn insert(conn: *zqlite.Conn, payload: []const u8, ts: i64, duration: i64) !i64 {
    try conn.exec("INSERT INTO rps_log(payload, ts, duration) VALUES (?, ?, ?)", .{ payload, ts, duration });
    var rows = try conn.rows("SELECT last_insert_rowid()", .{});
    defer rows.deinit();
    return if (rows.next()) |row| row.int(0) else error.InsertFailed;
}

pub fn selectJoin(conn: *zqlite.Conn, allocator: std.mem.Allocator, limit: usize) ![]JoinRow {
    var list: std.ArrayListAligned(JoinRow, null) = .empty;

    var rows = try conn.rows(
        "SELECT rps_log.id, rps_log.payload, rps_log.ts, rps_log.duration, rps_meta.key, rps_meta.value FROM rps_log LEFT JOIN rps_meta ON rps_log.id = rps_meta.log_id ORDER BY rps_log.id DESC LIMIT ?",
        .{@as(i64, @intCast(limit))},
    );
    defer rows.deinit();

    while (rows.next()) |row| {
        try list.append(allocator, .{
            .id = row.int(0),
            .payload = try allocator.dupe(u8, row.text(1)),
            .ts = row.int(2),
            .duration = row.int(3),
            .meta_key = if (row.nullableText(4)) |v| try allocator.dupe(u8, v) else "",
            .meta_value = if (row.nullableText(5)) |v| try allocator.dupe(u8, v) else "",
        });
    }
    return list.toOwnedSlice(allocator);
}

pub fn updateDurations(conn: *zqlite.Conn, ids: []const i64) !void {
    for (ids) |id| {
        try conn.exec("UPDATE rps_log SET duration = duration + 1 WHERE id = ?", .{id});
    }
}
