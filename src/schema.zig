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
    \\CREATE INDEX IF NOT EXISTS idx_rps_meta_log_id ON rps_meta(log_id);
;

pub fn run(conn: zqlite.Conn) !void {
    try conn.execNoArgs(create_tables);
}

pub fn seedFts(conn: zqlite.Conn) !void {
    try conn.execNoArgs(
        \\CREATE VIRTUAL TABLE IF NOT EXISTS link_fts USING fts5(
        \\    code, url,
        \\    tokenize='unicode61'
        \\);
        \\
        \\CREATE TRIGGER IF NOT EXISTS link_ai AFTER INSERT ON link_link BEGIN
        \\    INSERT INTO link_fts(rowid, code, url) VALUES (new.id, new.code, new.url);
        \\END;
        \\
        \\CREATE TRIGGER IF NOT EXISTS link_ad AFTER DELETE ON link_link BEGIN
        \\    DELETE FROM link_fts WHERE rowid = old.id;
        \\END;
        \\
        \\CREATE TRIGGER IF NOT EXISTS link_au AFTER UPDATE ON link_link BEGIN
        \\    DELETE FROM link_fts WHERE rowid = old.id;
        \\    INSERT INTO link_fts(rowid, code, url) VALUES (new.id, new.code, new.url);
        \\END;
        \\
        \\DELETE FROM link_fts;
        \\INSERT INTO link_fts(rowid, code, url) SELECT id, code, url FROM link_link;
    );
}
