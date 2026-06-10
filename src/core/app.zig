const std = @import("std");
const zqlite = @import("zqlite");
const ztl = @import("ztl");
const session = @import("session.zig");

pub const Templates = struct {
    layout: ztl.Template(*App),
    main: ztl.Template(void),
    login: ztl.Template(void),
    register: ztl.Template(void),
    link: ztl.Template(void),
    link_row: ztl.Template(void),
    error_tpl: ztl.Template(void),
};

pub const App = struct {
    io: std.Io,
    db_pool: *zqlite.Pool,
    template: Templates,
    session: session.Context,

    pub fn compileTemplates(self: *App, allocator: std.mem.Allocator) !void {
        self.template.layout = ztl.Template(*App).init(allocator, self);
        errdefer self.template.layout.deinit();
        try self.template.layout.compile(@embedFile("../templates/layout/layout.ztl"), .{});

        self.template.main = ztl.Template(void).init(allocator, {});
        errdefer self.template.main.deinit();
        try self.template.main.compile(@embedFile("../templates/main.ztl"), .{});

        self.template.login = ztl.Template(void).init(allocator, {});
        errdefer self.template.login.deinit();
        try self.template.login.compile(@embedFile("../templates/auth/login.ztl"), .{});

        self.template.register = ztl.Template(void).init(allocator, {});
        errdefer self.template.register.deinit();
        try self.template.register.compile(@embedFile("../templates/auth/register.ztl"), .{});

        self.template.link = ztl.Template(void).init(allocator, {});
        errdefer self.template.link.deinit();
        try self.template.link.compile(@embedFile("../templates/link/link.ztl"), .{});

        self.template.link_row = ztl.Template(void).init(allocator, {});
        errdefer self.template.link_row.deinit();
        try self.template.link_row.compile(@embedFile("../templates/link/row.ztl"), .{});

        self.template.error_tpl = ztl.Template(void).init(allocator, {});
        errdefer self.template.error_tpl.deinit();
        try self.template.error_tpl.compile(@embedFile("../templates/error.ztl"), .{});
    }

    pub fn partial(_self: *App, _allocator: std.mem.Allocator, _template_key: []const u8, include_key: []const u8) !?ztl.PartialResult {
        _ = _self;
        _ = _allocator;
        _ = _template_key;
        if (std.mem.eql(u8, include_key, "header")) {
            return .{ .src = @embedFile("../templates/layout/header.ztl") };
        }
        if (std.mem.eql(u8, include_key, "footer")) {
            return .{ .src = @embedFile("../templates/layout/footer.ztl") };
        }
        return null;
    }
};
