# PLAN: Port url-shortener (Go/Echo) → link-shortener (Zig/httpz)

## Scope
- **Auth**: Registration, login, logout (Argon2id + encrypted cookie sessions)
- **Links**: CRUD, redirect with click tracking, cursor pagination, base62 short codes
- **Templates**: Landing, login, register, create-link + list (ztl)
- **Static**: PicoCSS, HTMX, custom JS
- Replace existing `Post` model/table with `Link`

## Architecture

```
src/
├── main.zig              ← entry point, routes, static serving
├── core/
│   ├── app.zig           ← App struct, Templates, session helpers
│   ├── base62.zig        ← 7-char crypto-random code
│   └── session.zig       ← encrypted cookie sessions (XChaCha20-Poly1305)
├── auth/
│   ├── model.zig         ← User struct, sentinel errors
│   ├── storage.zig       ← SQL: CheckEmail, CreateUser
│   ├── service.zig       ← Argon2id via std.crypto.pwhash
│   └── handler.zig       ← GET/POST login, register, logout
├── link/
│   ├── model.zig         ← Link struct, sentinel errors
│   ├── storage.zig       ← SQL: CRUD links, click increment
│   ├── service.zig       ← thin wrappers + logging
│   └── handler.zig       ← GET/POST create, list, delete, redirect
└── templates/
    ├── layout.ztl        ← base HTML shell (nav, PicoCSS, HTMX, slot)
    ├── header.ztl        ← kept for compat
    ├── footer.ztl        ← kept for compat
    ├── main.ztl          ← landing page (Start here)
    ├── login.ztl         ← login form
    ├── register.ztl      ← register form
    └── link.ztl          ← create-link form + link table + infinite scroll
static/
├── css/pico@2.min.css
├── css/main.css
├── js/htmx.org@2.0.10.min.js
└── js/main.js
```

## Steps

### Step 1: Database schema
- `src/schema.zig` — SQL to create `auth_user` + `link_link` tables, drop `posts`
- Run `CREATE TABLE IF NOT EXISTS` on startup in `main.zig`

### Step 2: Core utilities
- `src/core/base62.zig` — 7-char crypto-random code from `[0-9a-zA-Z]`
- `src/core/session.zig` — encrypt/decrypt user ID into cookie (XChaCha20-Poly1305)

### Step 3: Auth module (model → storage → service → handler)
- `src/auth/model.zig` — `User { id, email, password }`, sentinel errors
- `src/auth/storage.zig` — `CheckEmail()`, `CreateUser()`
- `src/auth/service.zig` — `CheckUser()` verify password, `CreateUser()` hash+store
- `src/auth/handler.zig` — `GET/POST /auth/login`, `/auth/logout`, `GET/POST /auth/register`

### Step 4: Link module (model → storage → service → handler)
- `src/link/model.zig` — `Link { id, code, url, clicks, created_at }`, const MaxURLLength
- `src/link/storage.zig` — `CreateLink()`, `ListLink()` cursor-paginated, `RemoveLink()`, `GetLink()`, `ClickLink()`
- `src/link/service.zig` — pass-through + error handling
- `src/link/handler.zig` — `GET /link/create-link`, `POST /link/create-link`, `GET /link/list-link`, `DELETE /link/remove-link/:code`, `GET /:code` (redirect), `GET /` (landing)

### Step 5: Templates
- Convert all Go/templ → Zig/ztl
- `layout.ztl` — doctype, head (PicoCSS, favicon, meta), body (nav, content slot, HTMX, main.js)
- `main.ztl` — landing page: register/login links when unauthenticated
- `login.ztl` / `register.ztl` — forms with HTMX submission + error slot
- `link.ztl` — create form, link table with copy-to-clipboard, infinite scroll, delete

### Step 6: Static files
- Copy PicoCSS, HTMX, main.js from url-shortener
- Serve from `/static/*` via a simple file-reading handler in `main.zig`

### Step 7: Wire everything in main.zig
- Register static file route
- Register auth routes
- Register link routes
- Register redirect route
- Register landing route
- Add SESSION_KEY to .env
- Initialize session secret from env
- Update `core/app.zig` with template fields

### Step 8: Cleanup & verify
- Remove old `posts` references from all files
- Remove old templates if unused
- Build: `zig build`
- Verify binary runs and all endpoints work

## Key Design Decisions

| Concern | Decision |
|---------|----------|
| **Password hashing** | `std.crypto.pwhash.argon2.strHash` / `strVerify` (Zig stdlib) |
| **Sessions** | Encrypted cookies (stateless, no server-side storage) via `std.crypto.aead.xchacha20_poly1305` |
| **Short codes** | 7-char base62, `crypto.random.int()` per char |
| **Pagination** | Cursor-based: `WHERE user_id=? AND id<? ORDER BY id DESC LIMIT 5` |
| **Duplicate URLs** | `UNIQUE(user_id, url)` constraint → sentinel error |
| **Templates** | Layout with inline nav (userId-aware), content slot via string |
| **Static files** | Read from disk at `static/` via handler |
| **Config** | `SESSION_KEY` and `DB_NAME` from env vars |
| **DB init** | `CREATE TABLE IF NOT EXISTS` on startup (no migration system) |
