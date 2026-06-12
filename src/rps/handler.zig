const std = @import("std");
const httpz = @import("httpz");
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
