const std = @import("std");

const aead = std.crypto.aead.chacha_poly.XChaCha20Poly1305;

pub const nonce_len = aead.nonce_length;
pub const tag_len = aead.tag_length;
pub const plain_len = @sizeOf(i64);
pub const encrypted_len = nonce_len + plain_len + tag_len;

pub const Context = struct {
    key: [aead.key_length]u8,
};

pub fn init(secret: []const u8) Context {
    var ctx: Context = undefined;
    std.crypto.hash.blake2.Blake2b256.hash(secret, &ctx.key, .{});
    return ctx;
}

pub fn encrypt(ctx: *const Context, user_id: i64, io: std.Io) ![encrypted_len]u8 {
    var nonce: [nonce_len]u8 = undefined;
    try io.randomSecure(&nonce);

    var ciphertext: [plain_len]u8 = undefined;
    var tag: [tag_len]u8 = undefined;
    const plaintext = std.mem.asBytes(&user_id);
    aead.encrypt(&ciphertext, &tag, plaintext, &.{}, nonce, ctx.key);

    var result: [encrypted_len]u8 = undefined;
    @memcpy(result[0..nonce_len], &nonce);
    @memcpy(result[nonce_len..][0..plain_len], &ciphertext);
    @memcpy(result[nonce_len + plain_len..], &tag);
    return result;
}

pub fn decrypt(ctx: *const Context, data: []const u8) !i64 {
    if (data.len < encrypted_len) return error.InvalidSession;

    const nonce: [nonce_len]u8 = data[0..nonce_len].*;
    const ciphertext = data[nonce_len..][0..plain_len];
    const tag: [tag_len]u8 = data[nonce_len + plain_len ..][0..tag_len].*;

    var plaintext: [plain_len]u8 = undefined;
    try aead.decrypt(&plaintext, ciphertext, tag, &.{}, nonce, ctx.key);
    return std.mem.readInt(i64, &plaintext, .little);
}

test "encrypt/decrypt round trip" {
    const ctx = init("test_key_12345");
    const user_id: i64 = 42;
    const io = std.testing.io;

    const encrypted = try encrypt(&ctx, user_id, io);
    const decrypted = try decrypt(&ctx, encrypted[0..]);

    try std.testing.expectEqual(user_id, decrypted);
}

test "decrypt invalid session" {
    const ctx = init("test_key");
    try std.testing.expectError(error.InvalidSession, decrypt(&ctx, ""));
}

test "decrypt with wrong key" {
    const ctx1 = init("key1");
    const ctx2 = init("key2");
    const user_id: i64 = 99;
    const io = std.testing.io;

    const encrypted = try encrypt(&ctx1, user_id, io);
    try std.testing.expectError(error.AuthenticationFailed, decrypt(&ctx2, encrypted[0..]));
}
