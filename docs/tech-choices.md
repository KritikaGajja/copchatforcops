# CopChat — Technology Choices (no paid APIs)

Every hard part of this MVP has a free or self-hosted path. This documents which one to
take and, for the four unfamiliar pieces, what the concept actually is.

---

## Cost reality check

| Need | Paid option people assume | Free path we take |
| --- | --- | --- |
| Push notifications | OneSignal paid tier | **FCM — free, unlimited, no quota** |
| Maps | Google Maps SDK (billed per load) | **OpenStreetMap + `flutter_map` — free, no key** |
| Device GPS | — | **`geolocator` — free, it's the device's own hardware** |
| Realtime chat | Pusher / Ably / Stream | **Self-hosted WebSocket server (`ws` / Socket.IO)** |
| Voice / video | Agora / Twilio (per-minute) | **WebRTC + free Google STUN + self-hosted coturn** |
| Backend + DB | — | **Node + PostgreSQL, or Supabase free tier** |
| File storage | AWS S3 | **Local disk on your server, or Supabase Storage free tier** |
| SMS for SOS | Twilio (per message) | **In-app push + broadcast — no SMS needed** |

The only unavoidable cost is a small VPS (roughly ₹400–800/month) once you leave localhost.
For learning and for the whole MVP build, `localhost` is free and sufficient.

---

## 1. WebSockets — the concept

### The mental model

**HTTP** is a phone call you make: you dial, ask a question, get an answer, hang up. The
server can never call *you*.

**WebSocket** is a phone line left open. Either side can talk at any moment, and neither
hangs up. That is the entire idea.

Chat needs this because the server must be able to say "you have a new message" without the
app asking. The alternative — asking "any new messages?" every 2 seconds — is called
polling, and it drains battery and floods the server.

### What you'll actually write

**Server** (Node, ~40 lines to start):

```js
import { WebSocketServer } from 'ws';
const wss = new WebSocketServer({ port: 8080 });

wss.on('connection', (socket) => {
  socket.on('message', (raw) => {
    const { event, data } = JSON.parse(raw);
    // look up who else is in data.chatId, send to their sockets
  });
});
```

**Flutter** — package: `web_socket_channel`

```dart
final channel = WebSocketChannel.connect(Uri.parse('ws://localhost:8080'));
channel.stream.listen((raw) { /* decode, route by event name */ });
channel.sink.add(jsonEncode({'event': 'message:send', 'data': {...}}));
```

### The four things that bite beginners

1. **Reconnection.** Sockets drop constantly on mobile — tunnels, lifts, app backgrounded.
   You need automatic reconnect with exponential backoff (1s, 2s, 4s, 8s, cap at 30s).
   This is not optional; it's the majority of the work.
2. **Missed messages.** While disconnected you received nothing. On reconnect, always
   refetch over REST from the last message you have. The socket is a transport, never the
   source of truth.
3. **Authentication.** A socket connects *once*, so the token is checked once. When the
   access token expires 15 minutes later, the socket is still open. Either re-authenticate
   over the socket periodically, or reconnect on token refresh.
4. **Where it lives in the architecture.** The socket is a `@Riverpod(keepAlive: true)`
   service in `core/services/`. It exposes a `Stream` of decoded events. Repositories
   expose typed streams from it; view models watch those. **A view never touches the socket.**

### Learn it in this order

1. `ws` package docs (Node) — get a server echoing messages back
2. `web_socket_channel` on pub.dev — connect Flutter to it
3. Only then add reconnection
4. Only then move it behind a service

Do not start with Socket.IO. It adds rooms, auto-reconnect, and fallbacks — useful later,
but it hides the mechanics you're trying to learn.

---

## 2. GPS and location — the concept

### The mental model

The device already has a GPS chip. No API and no cost — you're reading local hardware. The
*only* hard part is Android's permission system.

### Packages

| Package | Job |
| --- | --- |
| `geolocator` | position, position stream, distance, permission checks |
| `permission_handler` | the permission UI flow |
| `flutter_map` | the map widget (OpenStreetMap tiles — free, no API key) |
| `latlong2` | coordinate type used by `flutter_map` |

### Android permission tiers — the part that catches everyone

| Permission | Gets you |
| --- | --- |
| `ACCESS_COARSE_LOCATION` | ~1 km accuracy |
| `ACCESS_FINE_LOCATION` | exact GPS |
| `ACCESS_BACKGROUND_LOCATION` | location while app is closed |

Background location is a **separate, second request** on Android 10+, and the user must
pick "Allow all the time" in system settings — your app cannot present that choice in a
dialog. Google Play also requires a written justification for it at review.

For CopChat this matters: "track officers in real time" implies background location. Build
foreground-only first and treat background as its own phase.

### Two different calls

```dart
// One-off — "share my location" button
final pos = await Geolocator.getCurrentPosition();

// Continuous — live tracking
Geolocator.getPositionStream(
  locationSettings: const LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 10,   // only emit after moving 10 metres
  ),
).listen((pos) { /* push over the socket */ });
```

`distanceFilter` is the battery-saving lever. Without it you get an update every second and
the phone is dead by lunch. For officer tracking, 10–25 m and a throttle of one socket
message every 10–15 seconds is a sane starting point.

### States you must handle

Service disabled · permission denied · permission denied forever (must send to app
settings) · permission granted. All four need real UI. Silently failing when location is
off is the most common bug in location apps.

---

## 3. Messaging — the concept

### The three pieces

Chat feels like one feature but is three:

1. **History** — REST. `GET /chats/{id}/messages?before=…&limit=30`
2. **Live delivery** — WebSocket. `message:new`
3. **Local cache** — a database on the device so the thread opens instantly and works
   offline

Skipping #3 is fine for the MVP, but design the repository so it can be added without
touching view models.

### Optimistic sending

Never make the user wait for the network. The flow:

1. User hits send
2. App creates the message locally with a `tempId` and status `sending` — renders instantly
3. App emits `message:send` over the socket
4. Server saves it, replies with the real `messageId` **and the same `tempId`**
5. App finds the message by `tempId`, swaps in the real ID, status → `sent`
6. On failure, status → `failed` with a retry button

`MessageStatus` is therefore an enum: `sending`, `sent`, `delivered`, `read`, `failed` —
which is exactly the tick marks users expect.

### Read receipts and typing

- **Typing:** emit `typing:start` on first keystroke, `typing:stop` after 3 s of no typing.
  Throttle it — do not emit on every letter.
- **Read receipts:** emit `message:read` when the message is actually visible on screen, not
  when the chat opens. `VisibilityDetector` or scroll-position checks.

### Free backend options

| Option | Good | Bad |
| --- | --- | --- |
| **Node + PostgreSQL + `ws`, self-hosted** | You learn everything; no limits; full data control | You build and run all of it |
| **Supabase** (free tier) | Realtime, auth, storage, Postgres included | Free tier pauses after inactivity; less learning |
| **Firebase** (Spark plan) | Fastest to a working chat | Data lives on Google's servers |

**Recommendation: Node + PostgreSQL.** Police data on your own infrastructure is close to a
hard requirement for this domain, and you said you want to learn the pieces. Supabase is the
sane fallback if backend work becomes the bottleneck.

---

## 4. Emergency SOS — the concept

### The good news

**SOS needs no third-party service at all.** It is a message with three extra properties:
highest priority, an attached location, and it goes to many people at once.

### The flow

1. Officer long-presses the SOS button (long-press, never a tap — accidental SOS is worse
   than a slow SOS)
2. App captures GPS **immediately**, in parallel with everything else
3. `POST /sos/trigger` with `{ lat, lng, accuracy, message? }`
4. Server creates the SOS record, resolves recipients by role and jurisdiction, and:
   - emits `sos:triggered` over the socket to everyone online
   - sends an FCM push with `priority: high` to everyone offline
5. Recipients get a full-screen alert with a map and a "responding" button
6. The originating device keeps streaming location until the SOS is cancelled

### The details that make it actually work

- **Fire before you're ready.** Send the SOS with the last known location instantly, then
  send an update when a precise fix arrives. A GPS lock can take 30 seconds; an officer in
  danger does not have 30 seconds.
- **Offline fallback.** No network means the SOS never left. Queue it and retry on
  reconnect, and *tell the user which state it's in*. A silent failure here is dangerous.
  If you later add SMS as a true fallback, that's the one place a paid service earns its
  cost.
- **Cancellation and false alarms.** Needs a confirm dialog and an audit trail. False
  alarms will happen and must be cheap to resolve.
- **Notification channel.** On Android, SOS gets its own channel with max importance and a
  custom sound, so it bypasses the user's normal notification settings.

---

## 5. Push notifications — free, and simpler than expected

**FCM (Firebase Cloud Messaging) is free with no message limit.** Using it does not require
adopting the rest of Firebase.

- Flutter: `firebase_messaging` + `flutter_local_notifications`
- Your server: stores each device's FCM token, calls the FCM HTTP v1 API to send

Three states you must handle separately, and they behave differently:
**foreground** (app open — you draw the notification yourself), **background** (app open but
hidden), **terminated** (app killed — the hardest to debug).

iOS additionally requires a paid Apple Developer account (₹8,000/year) for push to work at
all. Android has no such requirement — build and test on Android first.

---

## 6. Voice and video — free, but genuinely hard

WebRTC is an open standard. The protocol costs nothing. Three pieces are needed:

| Piece | What it does | Free option |
| --- | --- | --- |
| **Signalling** | Two devices exchange connection details | Your own WebSocket server |
| **STUN** | Discovers your public IP behind NAT | `stun:stun.l.google.com:19302` — free |
| **TURN** | Relays media when a direct connection fails | Self-host **coturn** |

Flutter package: `flutter_webrtc`.

Honest assessment: STUN alone connects roughly 80–90% of calls. The rest — symmetric NAT,
restrictive mobile networks — need TURN, and TURN relays actual media so it needs real
bandwidth on your server. This is why calling is Phase 10. Agora's free tier (10,000
minutes/month) is a legitimate way to ship calling and revisit it later.

---

## Recommended stack

```
Flutter app
    ├── REST      → Node (Express/Fastify) + PostgreSQL      [self-hosted, free]
    ├── Realtime  → ws / Socket.IO on the same Node server    [self-hosted, free]
    ├── Push      → FCM                                        [free, unlimited]
    ├── Maps      → flutter_map + OpenStreetMap                [free, no key]
    ├── GPS       → geolocator                                 [free, device hardware]
    ├── Files     → server disk or MinIO                       [free]
    └── Calls     → flutter_webrtc + Google STUN + coturn      [free, Phase 10]
```

Everything runs on `localhost` while you learn. A single small VPS runs all of it in
production.
