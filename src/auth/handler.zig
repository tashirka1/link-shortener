const std = @import("std");
const httpz = @import("httpz");
const model = @import("model.zig");
const service = @import("service.zig");
const session = @import("../core/session.zig");
const App = @import("../core/app.zig").App;

pub fn getLogin(app: *App, req: *httpz.Request, res: *httpz.Response) !void {
    const user_id = getUserId(app, req) catch 0;
    var buf = std.Io.Writer.Allocating.init(res.arena);
    defer buf.deinit();
    try app.template.login.render(&buf.writer, .{ .user_id = user_id }, .{ .allocator = res.arena });
    try renderLayout(app, res, "Login", user_id, buf.written());
}

pub fn postLogin(app: *App, req: *httpz.Request, res: *httpz.Response) !void {
    const fd = try req.formData();
    const email = fd.get("email") orelse "";
    const password = fd.get("password") orelse "";

    if (email.len == 0 or password.len == 0) {
        return renderLoginError(app, res, "email and password are required");
    }

    var conn = try app.db_pool.acquire(app.io);
    defer app.db_pool.release(app.io, conn);

    const user = service.checkUser(&conn, res.arena, email, password, app.io) catch |err| {
        return switch (err) {
            error.UserNotFound => renderLoginError(app, res, "email not found"),
            error.InvalidPassword => renderLoginError(app, res, "password isn't correct"),
            else => {
                std.log.err("login failed: {s}", .{@errorName(err)});
                return renderLoginError(app, res, "internal error");
            },
        };
    };

    const encrypted = try session.encrypt(&app.session, @intCast(user.id), app.io);
    var cookie_buf: [std.base64.url_safe_no_pad.Encoder.calcSize(session.encrypted_len)]u8 = undefined;
    _ = std.base64.url_safe_no_pad.Encoder.encode(&cookie_buf, &encrypted);
    try res.setCookie("session", &cookie_buf, .{ .path = "/" });

    res.status = 200;
    res.header("HX-Redirect", "/link/create-link");
}

pub fn logout(_: *App, _: *httpz.Request, res: *httpz.Response) !void {
    try res.setCookie("session", "", .{ .max_age = 0, .path = "/" });
    res.status = 200;
    res.header("HX-Redirect", "/auth/login");
}

pub fn getRegister(app: *App, req: *httpz.Request, res: *httpz.Response) !void {
    const user_id = getUserId(app, req) catch 0;
    var buf = std.Io.Writer.Allocating.init(res.arena);
    defer buf.deinit();
    try app.template.register.render(&buf.writer, .{ .user_id = user_id }, .{ .allocator = res.arena });
    try renderLayout(app, res, "Register", user_id, buf.written());
}

pub fn postRegister(app: *App, req: *httpz.Request, res: *httpz.Response) !void {
    const fd = try req.formData();
    const email = fd.get("email") orelse "";
    const password = fd.get("password") orelse "";

    if (email.len == 0) {
        return renderRegisterError(app, res, "email is required");
    }
    if (password.len < 8) {
        return renderRegisterError(app, res, "password must be at least 8 characters");
    }

    var conn = try app.db_pool.acquire(app.io);
    defer app.db_pool.release(app.io, conn);

    service.createUser(&conn, res.arena, email, password, app.io) catch |err| {
        return switch (err) {
            error.UserAlreadyExists => renderRegisterError(app, res, "the email is already in use"),
            else => {
                std.log.err("register failed: {s}", .{@errorName(err)});
                return renderRegisterError(app, res, "internal error");
            },
        };
    };

    res.status = 200;
    res.header("HX-Redirect", "/auth/login");
}

fn getUserId(app: *App, req: *httpz.Request) !i64 {
    const cookie = req.cookies().get("session") orelse return 0;
    if (cookie.len == 0) return 0;
    var buf: [session.encrypted_len]u8 = undefined;
    std.base64.url_safe_no_pad.Decoder.decode(&buf, cookie) catch return 0;
    return session.decrypt(&app.session, buf[0..]) catch 0;
}

fn renderLayout(app: *App, res: *httpz.Response, title: []const u8, user_id: i64, content: []const u8) !void {
    res.content_type = .HTML;
    try app.template.layout.render(res.writer(), .{ .title = title, .user_id = user_id, .content = content }, .{ .allocator = res.arena });
}

fn renderLoginError(app: *App, res: *httpz.Response, msg: []const u8) !void {
    res.status = 200;
    res.header("HX-Retarget", "#errors");
    res.header("HX-Reswap", "innerHTML");
    res.content_type = .HTML;
    try app.template.error_tpl.render(res.writer(), .{ .message = msg }, .{ .allocator = res.arena });
}

fn renderRegisterError(app: *App, res: *httpz.Response, msg: []const u8) !void {
    res.status = 200;
    res.header("HX-Retarget", "#errors");
    res.header("HX-Reswap", "innerHTML");
    res.content_type = .HTML;
    try app.template.error_tpl.render(res.writer(), .{ .message = msg }, .{ .allocator = res.arena });
}
