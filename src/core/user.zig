const std = @import("std");
const httpz = @import("httpz");
const session = @import("session.zig");
const App = @import("app.zig").App;

pub fn getUserId(app: *App, req: *httpz.Request) i64 {
    const cookie = req.cookies().get("session") orelse return 0;
    if (cookie.len == 0) return 0;
    var buf: [session.encrypted_len]u8 = undefined;
    std.base64.url_safe_no_pad.Decoder.decode(&buf, cookie) catch return 0;
    return session.decrypt(&app.session, buf[0..]) catch 0;
}
