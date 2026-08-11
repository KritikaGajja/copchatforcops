# CopChat — Supabase API Structure

What replaces "designing REST endpoints" now that [D-003](../decisions.md) picked Supabase.

> [api-conventions.md](api-conventions.md) is **superseded** for the Supabase path. Keep it:
> if CopChat is ever self-hosted behind a custom API, that document is the spec. The parts
> that still apply either way — UTC dates, cursor vs offset pagination, stable error codes —
> are repeated below.

---

## 1. The big shift

With Supabase there are no endpoints to design. There are **five** things instead:

| Layer | What it is | Replaces |
| --- | --- | --- |
| **Tables** | Postgres schema. PostgREST exposes every table automatically. | `GET /chats`, `POST /messages`, … |
| **RLS policies** | Row-level security in the database. | Role checks in controllers |
| **Channels** | Realtime broadcast / presence topics. | Your WebSocket event catalogue |
| **Storage buckets** | File upload and download. | `POST /files` |
| **Edge Functions** | Deno functions for logic a table write cannot do. | Custom endpoints |

**Your database schema *is* your API design now.** Time spent on the schema is time that
used to go into endpoint design.

---

## 2. What does NOT change — the architecture holds

This is the part worth internalising. Compare:

```dart
// REST version
final res = await dio.get('/chats');
return ApiResponse.success(res.data.map(ChatModel.fromJson).toList());

// Supabase version
final res = await supabase.from('chats').select();
return ApiResponse.success(res.map(ChatModel.fromJson).toList());
```

Same method signature. Same return type. **Only the inside of the repository changed.**
View models and views cannot tell the difference — which is exactly what
[core-architecture.md](../architecture/core-architecture.md) promised.

So the rules stand unchanged:

- Repositories are still the only place raw JSON is touched
- Repositories still return `ApiResponse<T>`
- A view model still never sees a `Map<String, dynamic>`

### One rule is rewritten

> ~~Never let a `DioException` escape a repository~~

becomes:

> Never let a **`PostgrestException`, `AuthException`, `StorageException` or
> `RealtimeSubscribeException`** escape a repository.

`BaseApiService` no longer wraps Dio. It wraps the Supabase client and centralises that
exception mapping — same job, different SDK.

---

## 3. Table schema

The real API design. Postgres conventions: `snake_case` columns, `uuid` primary keys,
`timestamptz` for every time column (always UTC).

### Identity

```
profiles              (extends auth.users)
  id                  uuid PK -> auth.users.id
  service_id          text unique       -- badge / service number, the login identifier
  name                text
  rank                text
  department_id       uuid -> departments
  station             text
  avatar_path         text
  role                text              -- super_admin | phq_admin | dept_head | officer
  on_duty             boolean
  last_seen_at        timestamptz
  public_key          text              -- E2EE: this device's public key
  created_at          timestamptz

departments
  id, name, parent_id -> departments, station, created_at

devices
  id, user_id -> profiles, device_id, fcm_token, platform,
  approved boolean, approved_by, last_seen_at, created_at
```

`profiles` is separate from `auth.users` because Supabase owns `auth.users` and you cannot
add columns to it. This split is standard.

### Chat — shaped by the E2EE decision

```
chats
  id, type ('direct'|'group'), name, department_id, created_by, created_at

chat_members
  chat_id, user_id, member_role, joined_at, last_read_message_id
  PK (chat_id, user_id)

messages
  id                  uuid PK
  chat_id             uuid -> chats
  sender_id           uuid -> profiles
  ciphertext          text              -- encrypted body; server CANNOT read this
  nonce               text              -- AES-GCM nonce
  message_type        text              -- text | image | document | location
  file_id             uuid -> files
  created_at          timestamptz
  deleted_at          timestamptz

message_keys                            -- E2EE: one row per recipient
  message_id          uuid -> messages
  recipient_id        uuid -> profiles
  encrypted_key       text              -- the AES key, encrypted with recipient's public key
  PK (message_id, recipient_id)

message_receipts
  message_id, user_id, delivered_at, read_at
  PK (message_id, user_id)
```

**`message_keys` is the cost of E2EE.** One message to a 40-officer department writes 1 row
in `messages` and **40** in `message_keys`. This is why group E2EE is hard, and why 1:1 is
built first.

### Files, location, emergency

```
files
  id, uploader_id, bucket_path, name, mime_type, size_bytes,
  thumbnail_path, created_at

locations                               -- current position, ONE row per officer
  user_id PK -> profiles
  lat, lng, accuracy, heading, updated_at

location_history                        -- append-only trail
  id, user_id, lat, lng, recorded_at

sos_events
  id, user_id, lat, lng, accuracy, message,
  status ('active'|'resolved'|'cancelled'), radius_metres,
  created_at, resolved_at, resolved_by, resolution_note

sos_responders
  sos_id, user_id, responded_at, lat, lng
  PK (sos_id, user_id)

broadcasts
  id, sender_id, title, body, audience_type, audience_id,
  priority, created_at

broadcast_reads
  broadcast_id, user_id, read_at
  PK (broadcast_id, user_id)

calls
  id, caller_id, callee_id, call_type ('voice'|'video'),
  status ('missed'|'answered'|'rejected'), started_at, ended_at, duration_seconds

audit_log
  id, actor_id, action, target_type, target_id, metadata jsonb, created_at
```

`locations` holds only the current position; `location_history` is the trail. Splitting them
keeps the live map query trivial and stops history from bloating the hot table.

---

## 4. Realtime channel naming

One naming scheme, used everywhere. Channel names are strings — without a convention they
become a mess by feature three.

| Channel | Type | Carries |
| --- | --- | --- |
| `chat:{chatId}` | Broadcast | `message:new`, `typing:start`, `typing:stop` |
| `presence:dept:{deptId}` | Presence | Who is online and on duty |
| `location:dept:{deptId}` | Broadcast | `location:update` pings |
| `sos:district:{districtId}` | Broadcast | `sos:triggered`, `sos:responder`, `sos:resolved` |
| `call:{userId}` | Broadcast | `call:offer`, `call:answer`, `call:ice`, `call:end` |

Rules:

- **Broadcast for events, Presence for state.** Do not hand-roll online/offline tracking —
  Presence already does it.
- **`call:{userId}` is per-user**, not per-call: an incoming call has to reach someone who
  does not yet know a call exists.
- **Postgres Changes is for sync, not delivery.** Use Broadcast to deliver a message
  instantly; use the table as the durable record. Relying on Postgres Changes alone adds
  latency and misses everything sent while disconnected.

---

## 5. Edge Functions

Only for what a table write genuinely cannot do. Each one is a piece of trusted server logic.

| Function | Why it cannot be a plain insert |
| --- | --- |
| `sos-trigger` | Must find every officer within the radius, fan out, and send high-priority push. Cannot be trusted to the client. |
| `send-push` | Holds the FCM server credentials — these must never reach the app. |
| `create-officer` | Creates an `auth.users` row **and** a `profiles` row atomically. Admin-only. |
| `approve-device` | Privileged state change that must be audited. |
| `rotate-group-keys` | E2EE: re-issues keys when a member joins or leaves a group. |

Everything else — sending a message, updating a profile, marking read — is a direct table
operation guarded by RLS.

---

## 6. RLS — the authorization layer

**RLS replaces almost every role check you would have written by hand.** It runs in the
database, so it cannot be bypassed by a malicious client.

The policies that matter:

| Table | Policy |
| --- | --- |
| `messages` | Read only if you are in `chat_members` for that `chat_id` |
| `message_keys` | Read only rows where `recipient_id = auth.uid()` |
| `profiles` | Everyone reads basic fields; only self or admin updates |
| `locations` | Read only officers your role is permitted to track |
| `sos_events` | Read if in the alert radius or a senior role |
| `audit_log` | Super Admin reads; **nobody** updates or deletes |
| `admin.*` operations | Role checked from `profiles.role` |

> **RLS is OFF by default on a new table.** A table with RLS off and a public anon key is
> readable by anyone with the key. Enable it on every table before real data exists.

---

## 7. Conventions that survive from the REST spec

- **UTC everywhere.** `timestamptz`, never a local time or a formatted string. In an SOS log
  a wrong timestamp is a real problem.
- **Cursor pagination for messages**, offset for stable lists — same reasoning as before.
  Supabase: `.lt('created_at', cursor).order('created_at', ascending: false).limit(30)`.
- **Stable error codes.** Map `PostgrestException.code` to your own `AUTH_*` / `PERM_*` /
  `CHAT_*` strings in `BaseApiService`, so view models switch on your codes, not Postgres's.
- **`data` is never a bare value** — irrelevant here, since `ApiResponse<T>` already carries
  the typed model.

---

## 8. Build order for the schema

Do not create all 17 tables now. Create what the current spike needs:

1. **Chat spike:** `profiles`, `chats`, `chat_members`, `messages`
2. **Encryption:** add `message_keys`, add `profiles.public_key`
3. **Tracking:** `locations`
4. **Calls:** `calls` (signalling itself is channels only — no table needed)
5. Everything else follows the phases in [feature-roadmap.md](../feature-roadmap.md)

Adding a column later is easy. Reshaping a table that already holds encrypted messages is
not — so `messages` and `message_keys` are the two worth getting right the first time.
