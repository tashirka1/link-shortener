const std = @import("std");
const httpz = @import("httpz");
const model = @import("model.zig");
const service = @import("service.zig");
const session = @import("../core/session.zig");
const user_core = @import("../core/user.zig");
const App = @import("../core/app.zig").App;

pub fn unauthorized(app: *App, _: *httpz.Request, res: *httpz.Response) !void {
    var buf = std.Io.Writer.Allocating.init(res.arena);
    defer buf.deinit();
    try app.template.unauthorized.render(&buf.writer, .{}, .{ .allocator = res.arena });
    try renderLayout(app, res, "Unauthorized", 0, buf.written());
}

fn renderLayout(app: *App, res: *httpz.Response, title: []const u8, user_id: i64, content: []const u8) !void {
    res.content_type = .HTML;
    try app.template.layout.render(res.writer(), .{ .title = title, .user_id = user_id, .content = content }, .{ .allocator = res.arena });
}

pub fn main(app: *App, _: *httpz.Request, res: *httpz.Response) !void {
    var buf = std.Io.Writer.Allocating.init(res.arena);
    defer buf.deinit();
    try app.template.main.render(&buf.writer, .{}, .{ .allocator = res.arena });
    try renderLayout(app, res, "Link Shortener", 0, buf.written());
}

pub fn getCreateLink(app: *App, req: *httpz.Request, res: *httpz.Response) !void {
    const user_id = user_core.getUserId(app, req);
    if (user_id == 0) {
        res.header("HX-Redirect", "/auth/login");
        try unauthorized(app, req, res);
        return;
    }

    var conn = try app.db_pool.acquire(app.io);
    defer app.db_pool.release(app.io, conn);

    const links = try service.listLinks(&conn, res.arena, user_id, 0);

    var buf = std.Io.Writer.Allocating.init(res.arena);
    defer buf.deinit();
    try app.template.link.render(&buf.writer, .{ .user_id = user_id, .links = links }, .{ .allocator = res.arena });
    try renderLayout(app, res, "Create Link", user_id, buf.written());
}

pub fn postCreateLink(app: *App, req: *httpz.Request, res: *httpz.Response) !void {
    const user_id = user_core.getUserId(app, req);
    if (user_id == 0) {
        res.header("HX-Redirect", "/auth/login");
        try unauthorized(app, req, res);
        return;
    }

    const fd = try req.formData();
    const url = fd.get("url") orelse "";

    if (url.len == 0) {
        return renderCreateLinkError(app, res, "url is required");
    }
    if (url.len > model.max_url_length) {
        return renderCreateLinkError(app, res, "url is too long");
    }
    if (!std.mem.startsWith(u8, url, "http://") and !std.mem.startsWith(u8, url, "https://")) {
        return renderCreateLinkError(app, res, "url must start with http:// or https://");
    }

    var conn = try app.db_pool.acquire(app.io);
    defer app.db_pool.release(app.io, conn);

    const link = service.createLink(&conn, res.arena, url, user_id, app.io) catch |err| {
        return switch (err) {
            error.LinkAlreadyExists => renderCreateLinkError(app, res, "this URL already exists"),
            else => {
                std.log.err("create link failed: {s}", .{@errorName(err)});
                return renderCreateLinkError(app, res, "internal error");
            },
        };
    };

    try renderLinkRow(app, res, link);
}

pub fn listLinks(app: *App, req: *httpz.Request, res: *httpz.Response) !void {
    const user_id = user_core.getUserId(app, req);
    if (user_id == 0) {
        res.header("HX-Redirect", "/auth/login");
        try unauthorized(app, req, res);
        return;
    }

    const q = try req.query();
    const cursor_str = q.get("cursor") orelse "0";
    const cursor = std.fmt.parseInt(i64, cursor_str, 10) catch 0;

    var conn = try app.db_pool.acquire(app.io);
    defer app.db_pool.release(app.io, conn);

    const links = try service.listLinks(&conn, res.arena, user_id, cursor);

    for (links) |link| {
        try renderLinkRow(app, res, link);
    }
}

pub fn removeLink(app: *App, req: *httpz.Request, res: *httpz.Response) !void {
    const user_id = user_core.getUserId(app, req);
    if (user_id == 0) {
        res.header("HX-Redirect", "/auth/login");
        try unauthorized(app, req, res);
        return;
    }

    const code = req.param("code") orelse {
        res.status = 400;
        return;
    };

    var conn = try app.db_pool.acquire(app.io);
    defer app.db_pool.release(app.io, conn);

    service.removeLink(&conn, user_id, code) catch |err| {
        std.log.err("remove link failed: {s}", .{@errorName(err)});
        res.status = 500;
        return;
    };
    res.status = 200;
}

pub fn redirectLink(app: *App, req: *httpz.Request, res: *httpz.Response) !void {
    const code = req.param("code") orelse {
        res.status = 404;
        return;
    };

    var conn = try app.db_pool.acquire(app.io);
    defer app.db_pool.release(app.io, conn);

    const url = service.getLink(&conn, res.arena, code) catch |err| switch (err) {
        error.NotFound => {
            res.status = 404;
            res.content_type = .HTML;
            try std.Io.Writer.writeAll(res.writer(), "<h1>Link not found</h1>");
            return;
        },
        else => {
            res.status = 500;
            return;
        },
    };

    service.clickLink(&conn, code) catch |err| {
        std.log.err("click link failed: {s}", .{@errorName(err)});
    };
    res.status = 303;
    res.header("Location", url);
}

fn renderCreateLinkError(app: *App, res: *httpz.Response, msg: []const u8) !void {
    res.status = 200;
    res.header("HX-Retarget", "#create-link-errors");
    res.header("HX-Reswap", "innerHTML");
    res.content_type = .HTML;
    try app.template.error_tpl.render(res.writer(), .{ .message = msg }, .{ .allocator = res.arena });
}

fn renderLinkRow(app: *App, res: *httpz.Response, link: model.Link) !void {
    res.content_type = .HTML;
    try app.template.link_row.render(res.writer(), .{
        .code = link.code,
        .url = link.url,
        .clicks = link.clicks,
    }, .{ .allocator = res.arena });
}
