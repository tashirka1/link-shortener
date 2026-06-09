const std = @import("std");

pub const User = struct {
    id: i64,
    email: []const u8,
    password: []const u8,
};

pub const UserError = error{
    UserNotFound,
    UserAlreadyExists,
    InvalidPassword,
};
