const std = @import("std");
const httpz = @import("httpz");
const App = @import("../core/app.zig").App;

pub fn simpleText(_: *App, _: *httpz.Request, res: *httpz.Response) !void {
    try res.writer().writeAll("ok");
}
