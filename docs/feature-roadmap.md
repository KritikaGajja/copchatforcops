# CopChat — Feature Roadmap

How the [MVP scope](mvp-scope.md) maps onto the feature-first structure from
[core-architecture.md](architecture/core-architecture.md), and the order to build it in.

---

## Module map

Every MVP feature belongs to exactly one module. Anything two modules both need moves to
`core/` — that rule is what stops this from turning into a tangle.

| Module | MVP features it owns |
| --- | --- |
| `core/` | role & permission model, theme, routing, navigation/dialog services, `ApiResponse` |
| `features/auth/` | Secure Login, Logout, session/token handling |
| `features/profile/` | User Profile Management, view other officers' profiles |
| `features/chat/` | One-to-One Chat, Department/Group Chat, Typing Indicator, Read Receipts |
| `features/presence/` | Online/Offline Status |
| `features/files/` | Share Images, Share Documents, File Preview, File Download |
| `features/calls/` | Voice Calling, Video Calling, Missed Call Notifications |
| `features/location/` | Live GPS Sharing, Real-Time Tracking, Officer Map, Permission Management |
| `features/emergency/` | Emergency SOS, Emergency Broadcast, Priority Notifications |
| `features/notifications/` | Push Notifications, Message Notifications |
| `features/search/` | Search Users, Search Chats, Search Shared Documents |
| `features/admin/` | Role-gated management screens for Super Admin / PHQ Admin / Dept Head |

**Role-Based Access Control is deliberately in `core/`, not `auth/`.** Every module has to
ask "may this role do this?", and a feature must never import another feature's providers.

---

## Build order

Ordered by dependency, not by importance. Each phase is only started once the previous one
runs.

### Phase 0 — Foundation
Core plumbing with no UI: `ApiResponse<T>`, constants, theme, `NavigationService`,
`DialogService`, router skeleton, `ProviderScope`, code generation working.
**Exit criteria:** app launches to a placeholder screen, `build_runner` generates cleanly.

### Phase 1 — `auth` + role model
Login, logout, session persistence, the `UserRole` enum, and the permission guard that the
rest of the app will use. Static credentials for now.
**Exit criteria:** log in as each of the four roles, land on a role-appropriate home screen,
session survives an app restart.

### Phase 2 — `profile`
Small, self-contained CRUD. Its real job is to cement the six-layer pattern while the
stakes are low.
**Exit criteria:** view and edit a profile with loading and error states both visible.

### Phase 3 — `chat` (one-to-one)
Chat list, message thread, send message, message bubbles, timestamps. Static message list.
**Exit criteria:** open a conversation, send a message, see it appended.

### Phase 4 — `chat` (group) + `presence` + indicators
Department/group chat, online/offline status, typing indicator, read receipts. All faked
locally at this stage.
**Exit criteria:** group thread works; indicators render from state, not from hardcoded UI.

### Phase 5 — `files`
Image and document attachment, preview, download. Picking from the device is fully real
here — only the upload is stubbed.
**Exit criteria:** attach a local file, preview it, see it in the thread.

### Phase 6 — `search`
Reads data the other modules already hold. No new infrastructure, which makes it a good
checkpoint on whether the layering held up.
**Exit criteria:** search users, chats, and documents from one screen.

### Phase 7 — `location`
Runtime permission flow, own GPS position, map view. Other officers' positions are static
until there is a backend.
**Exit criteria:** permission handled gracefully when denied, own location on a map.

### Phase 8 — `emergency`
SOS trigger, broadcast composer, priority notification styling.
**Exit criteria:** SOS fires and is visibly distinct from ordinary messages.

### Phase 9 — `notifications`
FCM setup, permission, foreground/background handling, deep-link into the right thread.
**Exit criteria:** a test push opens the correct chat.

### Phase 10 — `calls`
Voice and video via a real-time SDK. Last because it is the largest and the least
faked-friendly.
**Exit criteria:** a call connects between two devices.

---

## What cannot be built with static data

Most of the MVP works fine against hardcoded repositories. These four do not, and pretending
otherwise will waste your time:

| Feature | Why | What you *can* build now |
| --- | --- | --- |
| Voice / Video Calling | Needs signalling + media servers (WebRTC, Agora, Twilio) | Full call UI: ringing, in-call, controls, missed-call entry |
| Push Notifications | Needs FCM and a server holding device tokens | Permission flow, in-app notification UI, local notifications |
| Real-time tracking of *others* | Needs a live location stream from a server | Your own GPS, the map, the permission flow — all fully real |
| Presence / typing / receipts | Need a live transport (sockets) | Drive them from state so the transport is a drop-in swap later |

The rule for all four: build the **UI and the state** properly now, and leave exactly one
method in the repository to be rewritten later.

---

## Decisions to make before Phase 1

These are cheap now and expensive after several features exist.

1. **Backend direction.** REST + sockets, or Firebase/Supabase realtime? The architecture
   docs assume REST via Dio, which handles request/response well but not live streams.
   Chat, presence, and tracking are all stream-shaped, so the repository layer needs a
   `Stream<T>` return path alongside `Future<ApiResponse<T>>`.

2. **Security posture.** This is police data, and these are structural, not bolt-on:
   - encryption at rest for the local message cache
   - tokens in secure storage, never `SharedPreferences`
   - certificate pinning
   - screenshot / screen-recording blocking on sensitive screens
   - remote wipe or forced logout when a device is reported lost

3. **Roles as data or as code.** A hardcoded `UserRole` enum is simpler and type-safe; a
   server-driven permission list is more flexible. Enum is the right call for v1, but it
   must be easy to replace.
