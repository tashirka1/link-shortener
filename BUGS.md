# BUGS.md

## Critical / Security

### 1. `core/base62.zig:9` — `randomSecure` ошибка проглочена, код предсказуем
```zig
io.randomSecure(&rand_buf) catch {};  // rand_buf остаётся undefined
```
При отказе `randomSecure` буфер содержит мусор на стеке (или нули в debug). Код становится детерминированным. Тесты используют `std.Io.failing`, который всегда фейлит — тест на корректную длину проходит, но на уникальность кодов не проверяет ничего.

### 2. `core/session.zig:22` — `randomSecure` ошибка проглочена, nonce предсказуем
```zig
io.randomSecure(&nonce) catch {};  // nonce остаётся undefined
```
Если `randomSecure` фейлит, nonce — мусор/нули. Повтор nonce с тем же ключом ломает XChaCha20-Poly1305: атакующий восстанавливает plaintext (user_id).

### 3. `auth/handler.zig:42` — Cookie без HttpOnly, Secure и SameSite
```zig
try res.setCookie("session", &cookie_buf, .{ .path = "/" });
```
`CookieOpts.http_only = false` по умолчанию — cookie доступна из JS (XSS-уязвимость). `secure = false` — cookie передаётся по HTTP. Отсутствует `same_site`.

### 4. `core/base62.zig:11` — Смещение из-за modulo bias
```zig
c.* = charset[r % charset.len];
```
256 % 62 = 8, первые 8 символов charset (`01234567`) имеют чуть более высокую вероятность. Не критично для 7-символьных кодов (пространство 3.5T), но алгоритмически неверно.

---

## Memory Leaks

### 5. `auth/storage.zig:12-13` — Утечка email при падении dupe password
```zig
return .{
    .email = try allocator.dupe(u8, row.text(1)),
    .password = try allocator.dupe(u8, row.text(2)),  // OOM -> email утекает
};
```
`errdefer` в `checkUser` (service.zig:10-11) не срабатывает, потому что присваивание `const user = try ...` не завершилось. Нужен ручной free при ошибке.

### 6. `link/storage.zig:37-44` — Утечка аллокаций при OOM в listLinks
```zig
while (rows.next()) |row| {
    try list.append(allocator, .{
        .code = try allocator.dupe(u8, row.text(1)),
        .url = try allocator.dupe(u8, row.text(2)),
        // OOM на url или created_at — code уже утек
        .created_at = try allocator.dupe(u8, ...),
    });
}
```
Если `dupe` падает после того, как часть строк добавлена в `list`, всё, что было в list (и частичные аллокации текущей строки) утекает. Нужен `errdefer` для очистки.

---

## Logic Errors

### 7. `link/storage.zig:9-24` — ON CONFLICT возвращает ошибку вместо существующей ссылки
```zig
INSERT ... ON CONFLICT(user_id, url) DO NOTHING
SELECT ... WHERE code = ?
```
При дубликате URL новая строка не вставляется, SELECT по новому коду ничего не находит → возвращается `LinkAlreadyExists`. Пользователь видит ошибку, но не получает существующий короткий код. Нужно SELECT по `(user_id, url)` вместо генерации нового кода.

### 8. `link/handler.zig:120-124` — removeLink возвращает 200 при ошибке
```zig
service.removeLink(&conn, user_id, code) catch {
    std.log.err("remove link failed", .{});
    res.status = 200;  // Должно быть 500
    return;
};
```
Клиент думает, что удаление прошло успешно.

### 9. `link/handler.zig:150` — Ошибка clickLink проглочена
```zig
service.clickLink(&conn, code) catch {};
```
Счётчик кликов не обновляется при ошибке, редирект всё равно происходит. Пользователь не узнаёт о потере данных.

### 10. `link/storage.zig:32` — Cursor 0 превращается в maxInt, но 0 может быть валидным id
```zig
WHERE user_id = ? AND id < ? ORDER BY id DESC LIMIT 5
```
`cursor = 0` → `maxInt(i64)` — корректно для первой страницы. Но если удалить первую запись (id=1) и следующая тоже id=1 (SQLite может переиспользовать id при `AUTOINCREMENT`? нет, без AUTOINCREMENT id монотонны), может быть затирание. При использовании `INTEGER PRIMARY KEY` id уникальны, так что ок, но стоит задокументировать, что cursor=0 означает "первая страница".

---

## Stylistic / Code Quality

### 11. `auth/handler.zig:91-97` + `link/handler.zig:8-14` — Дублирование getUserId
Одна и та же функция в 2 файлах. Нужно вынести в core или session.

### 12. `core/base62.zig:30-38` — Бесполезный тест
```zig
test "newCode generates different codes" {
    // "...both codes will be identical (zero-filled rand_buf)"
    try std.testing.expectEqual(code1.len, code2.len);  // всегда true
}
```
Комментарий признаёт, что коды идентичны из-за `std.Io.failing`. Тест проверяет только длину, которая гарантирована типом.

### 13. `catch {}` паттерн в 4 местах
- `base62.zig:9` — randomSecure fail
- `session.zig:22` — randomSecure fail
- `link/handler.zig:150` — clickLink fail
- `link/storage.zig` — нет, но выше

Во всех случаях ошибка бесшумно глотается. Нужно хотя бы логировать.

### 14. `core/app.zig:47-57` — Неиспользуемые параметры в partial
```zig
_ = self;
_ = allocator;
_ = template_key;
```
Требуется интерфейсом ztl, но можно заменить на `_allocator` (ведущий `_`) для консистентности.

---

## Minor

### 15. `link/handler.zig:21-26` — main() не показывает ссылки для авторизованного пользователя
Лендинг всегда рендерится с `user_id = 0`, даже если пользователь залогинен. Должен проверять cookie и редиректить на `/link/create-link`.

### 16. `auth/handler.zig:104-109` + `112-117` — Дублирование renderLoginError / renderRegisterError
Функции идентичны, отличаются только ID элемента (`#errors`). Можно объединить.

### 17. `main.zig:111` — `server_instance` присваивается перед блокирующим `server.listen()`
Если `listen()` упадёт с ошибкой, `server_instance` останется висеть. Не критично (процесс всё равно завершится), но лучше присваивать после успешного старта.
