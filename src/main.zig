const std = @import("std");
const httpz = @import("httpz");
const zqlite = @import("zqlite");
const schema = @import("schema.zig");
const session = @import("core/session.zig");
const link_handler = @import("link/handler.zig");
const auth_handler = @import("auth/handler.zig");
const App = @import("core/app.zig").App;

var server_instance: ?*httpz.Server(*App) = null;

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    // db
    const DB_NAME = try allocator.dupeZ(u8, init.environ_map.get("DB_NAME") orelse "./db/main.db");
    defer allocator.free(DB_NAME);
    var db_pool = try zqlite.Pool.init(allocator, .{
        .size = 32,
        .path = DB_NAME,
        .flags = zqlite.OpenFlags.ReadWrite | zqlite.OpenFlags.Create | zqlite.OpenFlags.EXResCode,
        .on_connection = &configureConnection,
    });
    defer db_pool.deinit();

    // run schema
    {
        const conn = try db_pool.acquire(init.io);
        defer db_pool.release(init.io, conn);
        try schema.run(conn);
    }

    // session
    const session_key = init.environ_map.get("SESSION_KEY") orelse "dev_key_change_me";
    const session_ctx = session.init(session_key);
    var app = App{
        .io = init.io,
        .db_pool = db_pool,
        .template = .{
            .layout = undefined,
            .main = undefined,
            .login = undefined,
            .register = undefined,
            .link = undefined,
            .error_tpl = undefined,
        },
        .session = session_ctx,
    };

    try app.compileTemplates(allocator);
    defer {
        app.template.layout.deinit();
        app.template.main.deinit();
        app.template.login.deinit();
        app.template.register.deinit();
        app.template.link.deinit();
        app.template.error_tpl.deinit();
    }

    // shutdown
    if (comptime @import("builtin").os.tag != .windows) {
        std.posix.sigaction(std.posix.SIG.INT, &.{
            .handler = .{ .handler = shutdown },
            .mask = std.posix.sigemptyset(),
            .flags = 0,
        }, null);
        std.posix.sigaction(std.posix.SIG.TERM, &.{
            .handler = .{ .handler = shutdown },
            .mask = std.posix.sigemptyset(),
            .flags = 0,
        }, null);
    }

    // server
    const worker_count = std.Thread.getCpuCount() catch 4;
    var server = try httpz.Server(*App).init(init.io, allocator, .{
        .address = .all(8000),
        .workers = .{ .count = @intCast(worker_count) },
        .request = .{ .max_form_count = 32 },
    }, &app);
    defer server.deinit();

    // router
    var router = try server.router(.{});

    // public routes
    router.get("/", link_handler.main, .{});
    router.get("/status/health", healthCheck, .{});

    // static files: /static/*path
    router.get("/static/*", serveStatic, .{});

    // auth routes
    router.get("/auth/login", auth_handler.getLogin, .{});
    router.post("/auth/login", auth_handler.postLogin, .{});
    router.get("/auth/register", auth_handler.getRegister, .{});
    router.post("/auth/register", auth_handler.postRegister, .{});
    router.get("/auth/logout", auth_handler.logout, .{});

    // link routes (group)
    var link_group = router.group("/link", .{});
    link_group.get("/create-link", link_handler.getCreateLink, .{});
    link_group.post("/create-link", link_handler.postCreateLink, .{});
    link_group.get("/list-link", link_handler.listLinks, .{});
    link_group.delete("/remove-link/:code", link_handler.removeLink, .{});

    // redirect catch-all (must be last)
    router.get("/:code", link_handler.redirectLink, .{});

    // server
    server_instance = &server;
    errdefer server_instance = null;
    try server.listen();
}

fn shutdown(_: std.posix.SIG) callconv(.c) void {
    if (server_instance) |server| {
        server_instance = null;
        server.stop();
    }
}

fn configureConnection(conn: zqlite.Conn, _: ?*anyopaque) !void {
    try conn.execNoArgs("PRAGMA busy_timeout=10000");
    try conn.execNoArgs("PRAGMA foreign_keys=ON");
    try conn.execNoArgs("PRAGMA journal_mode=WAL");
    try conn.execNoArgs("PRAGMA synchronous=NORMAL");
    try conn.execNoArgs("PRAGMA auto_vacuum=INCREMENTAL");
    try conn.execNoArgs("PRAGMA journal_size_limit=67110000");
    try conn.execNoArgs("PRAGMA temp_store=MEMORY");
    try conn.execNoArgs("PRAGMA cache_size=-65536");
    try conn.execNoArgs("PRAGMA page_size=4096");
}

fn healthCheck(_: *App, _: *httpz.Request, res: *httpz.Response) !void {
    res.status = 200;
    try res.json(.{ .status = "ok" }, .{});
}

const StaticEntry = struct {
    data: []const u8,
    ext: []const u8,
};

const static_files = std.StaticStringMap(StaticEntry).initComptime(.{
    .{ "css/main.css", StaticEntry{ .data = @embedFile("static/css/main.css"), .ext = ".css" } },
    .{ "css/pico@2.min.css", StaticEntry{ .data = @embedFile("static/css/pico@2.min.css"), .ext = ".css" } },
    .{ "icon/favicon.ico", StaticEntry{ .data = @embedFile("static/icon/favicon.ico"), .ext = ".ico" } },
    .{ "icon/favicon.png", StaticEntry{ .data = @embedFile("static/icon/favicon.png"), .ext = ".png" } },
    .{ "icon/favicon.svg", StaticEntry{ .data = @embedFile("static/icon/favicon.svg"), .ext = ".svg" } },
    .{ "js/htmx.org@2.0.10.min.js", StaticEntry{ .data = @embedFile("static/js/htmx.org@2.0.10.min.js"), .ext = ".js" } },
    .{ "js/main.js", StaticEntry{ .data = @embedFile("static/js/main.js"), .ext = ".js" } },
});

fn serveStatic(_: *App, req: *httpz.Request, res: *httpz.Response) !void {
    const raw = req.url.raw;
    const stripped = if (std.mem.startsWith(u8, raw, "/static/")) raw["/static/".len..] else raw;
    if (stripped.len == 0) return notFound(res);

    const path = if (std.mem.indexOfScalar(u8, stripped, '?')) |q| stripped[0..q] else stripped;
    if (path.len == 0) return notFound(res);

    const entry = static_files.get(path) orelse return notFound(res);

    res.content_type = httpz.ContentType.forExtension(entry.ext);
    try res.writer().writeAll(entry.data);
}

fn notFound(res: *httpz.Response) !void {
    res.status = 404;
    res.content_type = .HTML;
    try res.writer().writeAll("<h1>Not Found</h1>");
}
