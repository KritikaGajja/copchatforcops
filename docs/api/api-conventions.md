# CopChat — API Conventions

The contract every endpoint follows. Agreeing on this **before** writing endpoints is what
keeps `BaseApiService` thin: if every response has the same shape, parsing lives in one
place instead of in every repository.

---

## 1. Base URL and versioning

```
https://api.copchat.<domain>/api/v1
```

The version goes in the path, never in a header. When v2 arrives, v1 keeps running for
older installed apps — police devices do not all update on the same day.

---

## 2. Response envelope

**Every** response — success or failure — uses the same three-field envelope. This maps
1:1 onto `ApiResponse<T>` from [services.md](../architecture/services.md).

### Success

```json
{
  "success": true,
  "message": "Login successful",
  "data": { }
}
```

### Failure

```json
{
  "success": false,
  "message": "Invalid credentials",
  "error": {
    "code": "AUTH_INVALID_CREDENTIALS",
    "details": { "attemptsRemaining": 2 }
  }
}
```

Rules:

- `data` is an **object or array, never a bare value**. `"data": 5` is forbidden — use
  `"data": { "count": 5 }` so a field can be added later without breaking clients.
- `message` is **user-displayable**. The app shows it directly.
- `error.code` is a **stable machine string**, screaming snake case. The app switches on
  this; it never parses `message`.
- A list response always nests: `"data": { "items": [...], "pagination": {...} }`.
  Returning a bare array leaves nowhere to put pagination later.

---

## 3. HTTP status codes

| Code | Meaning | App behaviour |
| --- | --- | --- |
| 200 | OK | parse `data` |
| 201 | Created | parse `data` |
| 400 | Validation failed | show field errors from `error.details` |
| 401 | Token missing/expired | refresh token, retry once, else force logout |
| 403 | Role not permitted | show "not authorised" screen |
| 404 | Not found | show empty state |
| 409 | Conflict (duplicate) | show `message` |
| 422 | Semantically invalid | show field errors |
| 429 | Rate limited | back off, show retry-after |
| 500 | Server error | generic error, log it |

401 vs 403 matters here: **401 = we don't know who you are, 403 = we know and you may not.**
With four roles, 403 will be common and must never trigger a logout.

---

## 4. Authentication

JWT, two tokens:

| Token | Lifetime | Stored in |
| --- | --- | --- |
| access | 15 min | memory + secure storage |
| refresh | 30 days | **secure storage only** |

Sent as: `Authorization: Bearer <accessToken>`

On 401, `BaseApiService` calls `POST /auth/refresh` once, retries the original request, and
on a second failure forces logout. This lives in a Dio interceptor, so no repository ever
handles token refresh.

Every request also sends:

```
X-Device-Id: <stable device uuid>
X-App-Version: 1.0.0+1
```

`X-Device-Id` is what makes remote-wipe and "logout this device" possible later.

---

## 5. Naming

- Resources are **plural nouns**: `/users`, `/chats`, `/messages`
- Multi-word paths use **kebab-case**: `/emergency-broadcasts`
- JSON fields use **camelCase** — matches Dart, so no field renaming in `fromJson`
- Never put verbs in paths. `POST /chats/{id}/messages`, not `/sendMessage`
  - The one accepted exception: actions that aren't CRUD — `POST /auth/login`,
    `POST /auth/logout`, `POST /sos/trigger`

### Standard shape

```
GET    /chats                    list
POST   /chats                    create
GET    /chats/{chatId}           read one
PATCH  /chats/{chatId}           partial update
DELETE /chats/{chatId}           delete
GET    /chats/{chatId}/messages  sub-resource
```

Use `PATCH`, not `PUT`. `PUT` means "replace the whole object", which the app almost never
actually wants.

---

## 6. Pagination

**Two different kinds, and using the wrong one will hurt.**

### Cursor-based — for messages

```
GET /chats/{chatId}/messages?before=<messageId>&limit=30
```

```json
"pagination": { "nextCursor": "msg_8812", "hasMore": true }
```

Chat needs cursors because new messages arrive constantly. With page numbers, a message
arriving between "page 1" and "page 2" shifts everything down and the user sees a duplicate
or misses one.

### Offset-based — for stable lists

```
GET /users?page=1&limit=20&search=sharma
```

```json
"pagination": { "page": 1, "limit": 20, "total": 143, "totalPages": 8 }
```

Fine for user directories and document lists, where order doesn't change under you.

---

## 7. Dates

Always **UTC ISO-8601 with the Z suffix**: `2026-08-08T14:32:00.000Z`

The server never sends local time or a formatted string. The app converts to local for
display. Officers across shifts and districts will otherwise see wrong timestamps, and in
an SOS log a wrong timestamp is a real problem.

---

## 8. IDs

Prefixed strings, not bare integers: `usr_a3f9`, `chat_88b1`, `msg_4410`.

Two reasons: you can tell what a broken ID belongs to when reading a log, and passing a
user ID where a chat ID was expected fails loudly rather than silently fetching the wrong
record.

---

## 9. File upload

```
POST /files
Content-Type: multipart/form-data
```

```json
"data": {
  "fileId": "file_9912",
  "url": "https://.../file_9912.pdf",
  "name": "fir-copy.pdf",
  "mimeType": "application/pdf",
  "sizeBytes": 249301,
  "thumbnailUrl": "https://.../file_9912_thumb.jpg"
}
```

Upload first, then reference `fileId` when sending the message. Two steps, not one, because
it lets the upload show a progress bar and be retried without resending the message.

Server enforces: max size, an allow-list of MIME types (never a block-list), and a virus
scan. `thumbnailUrl` is generated server-side — do not make the app download a 4 MB image
to show a 60 px preview.

---

## 10. Real-time events (WebSocket)

REST covers request/response. Chat, presence, typing, receipts, live location, and SOS are
**push**-shaped and go over a socket.

### Connection

```
wss://api.copchat.<domain>/ws?token=<accessToken>
```

### Event envelope

Both directions use one shape:

```json
{
  "event": "message:new",
  "data": { },
  "timestamp": "2026-08-08T14:32:00.000Z"
}
```

### Event catalogue

| Event | Direction | Payload |
| --- | --- | --- |
| `message:new` | server → app | the full message object |
| `message:send` | app → server | `{ chatId, tempId, text, fileId? }` |
| `message:delivered` | server → app | `{ messageId, userId }` |
| `message:read` | both | `{ chatId, messageId }` |
| `typing:start` / `typing:stop` | both | `{ chatId, userId }` |
| `presence:update` | server → app | `{ userId, status, lastSeenAt }` |
| `location:update` | app → server | `{ lat, lng, accuracy, heading }` |
| `location:officer` | server → app | `{ userId, lat, lng, updatedAt }` |
| `sos:triggered` | server → app | `{ sosId, userId, lat, lng, message }` |
| `call:incoming` / `call:accept` / `call:reject` / `call:end` | both | `{ callId, from, to, type }` |

### The `tempId` rule

When sending, the app generates a `tempId` (a local UUID) and renders the message
immediately as "sending". The server echoes `tempId` back alongside the real `messageId`,
and the app swaps it in. Without this the UI freezes on every send while waiting for the
network — this is how every chat app achieves instant-feeling sends.

### Rules

- The socket is a **transport, not a source of truth.** History always comes from REST.
  A socket that reconnects mid-scroll must not leave gaps in the thread.
- On reconnect, refetch messages since the last known `messageId`. Never assume the socket
  caught everything while it was down.
- Events are **fire-and-forget**. Anything that must not be lost (sending a message, SOS)
  gets an acknowledgement event or a REST fallback.

---

## 11. Error codes

Stable strings, grouped by prefix. The app switches on these.

```
AUTH_INVALID_CREDENTIALS   AUTH_TOKEN_EXPIRED       AUTH_ACCOUNT_DISABLED
AUTH_DEVICE_NOT_REGISTERED PERM_ROLE_DENIED         PERM_NOT_CHAT_MEMBER
CHAT_NOT_FOUND             MSG_TOO_LARGE            FILE_TYPE_NOT_ALLOWED
FILE_TOO_LARGE             LOC_PERMISSION_REQUIRED  SOS_ALREADY_ACTIVE
RATE_LIMITED               VALIDATION_FAILED        SERVER_ERROR
```

Add to this list as you go — but never change or reuse an existing code, because older
installed app versions still switch on it.
