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
;

pub fn run(conn: zqlite.Conn) !void {
    try conn.execNoArgs(create_tables);
}
