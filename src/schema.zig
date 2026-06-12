const zqlite = @import("zqlite");

const create_tables = 
    \\CREATE TABLE IF NOT EXISTS auth_user (
    \\    id INTEGER PRIMARY KEY,
    \\    email TEXT NOT NULL,
    \\    password TEXT NOT NULL,
    \\    UNIQUE(email)
    \\);
    \\CREATE TABLE IF NOT EXISTS link_link (
    \\    id INTEGER PRIMARY KEY,
    \\    code TEXT NOT NULL,
    \\    url TEXT NOT NULL,
    \\    clicks INTEGER DEFAULT 0,
    \\    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    \\    user_id INTEGER NOT NULL,
    \\    FOREIGN KEY (user_id) REFERENCES auth_user(id),
    \\    UNIQUE(code),
    \\    UNIQUE(user_id, url)
    \\);
    \\CREATE INDEX IF NOT EXISTS idx_link_link_user_id ON link_link(user_id);
    \\
    \\CREATE TABLE IF NOT EXISTS rps_log (
    \\    id INTEGER PRIMARY KEY AUTOINCREMENT,
    \\    payload TEXT NOT NULL,
    \\    ts INTEGER NOT NULL,
    \\    duration INTEGER NOT NULL DEFAULT 0
    \\);
    \\
    \\CREATE TABLE IF NOT EXISTS rps_meta (
    \\    id INTEGER PRIMARY KEY AUTOINCREMENT,
    \\    log_id INTEGER NOT NULL REFERENCES rps_log(id) ON DELETE CASCADE,
    \\    key TEXT NOT NULL,
    \\    value TEXT NOT NULL
    \\);
;

pub fn run(conn: zqlite.Conn) !void {
    try conn.execNoArgs(create_tables);
}
