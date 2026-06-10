# Мутный код — разобраться

## 1. XSS в renderLinkRow (high)
**Файл:** `src/link/handler.zig:164-173`

Функция `renderLinkRow` пишет HTML руками, URL из БД не экранируется:
```zig
try std.Io.Writer.print(w, "<td><a href=\"{s}\" target=\"_blank\">{s}</a></td>", .{ link.url, link.url });
```
Фильтр `startsWith("http://" | "https://")` пропускает: `http://x/" onclick="alert(1)`.
В шаблоне `link.ztl:28` экранирование есть (`<%= link["url"] %>`), но `renderLinkRow` его не использует.

**Фикс:** экранировать HTML-спецсимволы в `link.url` или переделать на ztl-шаблон.

---

## 2. Base62 modulo bias (medium)
**Файл:** `src/core/base62.zig:12`

```zig
c.* = charset[r % charset.len];  // charset.len = 62, r — случайный byte (0-255)
```
255 ÷ 62 = 4 ост. 7 → символы `0123456` выпадают с p=5/256, остальные с p=4/256.
Для 7-символьного кода bias небольшой, но нарушает равномерность CSPRNG.

**Фикс:** rejection sampling — отбрасывать r >= 248 (62×4).

---

## 3. Запасной ключ сессии хардкодом (medium)
**Файл:** `src/main.zig:34`

```zig
const session_key = init.environ_map.get("SESSION_KEY") orelse "dev_key_change_me";
```
Если `SESSION_KEY` не выставлен — шифрование на дефолтном ключе.

**Фикс:** падать с ошибкой, если ключ не задан.

---

## 4. Нет rate limiting (medium)
**Файлы:** `src/auth/handler.zig:17` (login), `src/auth/handler.zig:63` (register)

Эндпоинты `/auth/login` и `/auth/register` не имеют ограничений.
Позволяет brute-force паролей и массовую регистрацию.

**Фикс:** добавить throttling (in-memory или через БД).

---

## 5. Нет валидации email (low)
**Файл:** `src/auth/handler.zig:63-73`

`postRegister` проверяет только `len > 0` и `password >= 8`.
Email `"  "`, `"a@b"` или `"@"` сохраняется в БД.

**Фикс:** добавить проверку формата email (хотя бы contains `@`).
