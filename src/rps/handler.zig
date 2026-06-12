const std = @import("std");
const httpz = @import("httpz");
const storage = @import("storage.zig");
const App = @import("../core/app.zig").App;

pub fn simpleText(_: *App, _: *httpz.Request, res: *httpz.Response) !void {
    try res.writer().writeAll("ok");
}

pub fn simpleJson(_: *App, _: *httpz.Request, res: *httpz.Response) !void {
    try res.json(.{ .status = "ok" }, .{});
}

pub fn simpleZtlPage(app: *App, _: *httpz.Request, res: *httpz.Response) !void {
    res.content_type = .HTML;
    try app.template.rps_simple.render(res.writer(), .{}, .{ .allocator = res.arena });
}

fn parseLimit(req: *httpz.Request) !usize {
    const q = try req.query();
    const limit_str = q.get("limit") orelse "10";
    return std.fmt.parseInt(usize, limit_str, 10) catch 10;
}

fn renderJoin(app: *App, res: *httpz.Response, rows: []const storage.JoinRow) !void {
    res.content_type = .HTML;
    try app.template.rps_select_join.render(res.writer(), .{ .rows = rows }, .{ .allocator = res.arena });
}

pub fn ztlPageSelectJoin(app: *App, req: *httpz.Request, res: *httpz.Response) !void {
    const limit = try parseLimit(req);

    var conn = try app.db_pool.acquire(app.io);
    defer app.db_pool.release(app.io, conn);

    const rows = try storage.selectJoin(&conn, res.arena, limit);
    try renderJoin(app, res, rows);
}

pub fn ztlPageSelectJoinUpdate(app: *App, req: *httpz.Request, res: *httpz.Response) !void {
    const limit = try parseLimit(req);

    var conn = try app.db_pool.acquire(app.io);
    defer app.db_pool.release(app.io, conn);

    const rows = try storage.selectJoin(&conn, res.arena, limit);

    var ids = try std.ArrayList(i64).initCapacity(res.arena, rows.len);
    for (rows) |row| ids.appendAssumeCapacity(row.id);
    try storage.updateDurations(&conn, ids.items);

    const updated_rows = try storage.selectJoin(&conn, res.arena, limit);
    try renderJoin(app, res, updated_rows);
}

pub fn ztlPageInsert(app: *App, req: *httpz.Request, res: *httpz.Response) !void {
    const q = try req.query();
    const payload = q.get("payload") orelse "rps_bench";
    const ts = @as(i64, @intCast(@divFloor(std.Io.Clock.real.now(app.io).nanoseconds, std.time.ns_per_s)));

    var conn = try app.db_pool.acquire(app.io);
    defer app.db_pool.release(app.io, conn);

    const id = try storage.insert(&conn, payload, ts, 0);

    res.content_type = .HTML;
    try app.template.rps_insert.render(res.writer(), .{ .id = id, .payload = payload }, .{ .allocator = res.arena });
}
