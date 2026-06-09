pub const max_url_length = 2048;

pub const Link = struct {
    id: i64,
    code: []const u8,
    url: []const u8,
    clicks: i64,
    user_id: i64,
    created_at: []const u8,
};

pub const LinkError = error{
    LinkAlreadyExists,
};
