# CopChat — Decision Record

Decisions made by the project owner, with their consequences. Recorded so they are not
silently re-litigated later.

---

## D-001 — Build order: spike the hard parts first

**Decided:** Realtime chat, encryption, live tracking and calls are built **before** the
UI screens, as proof-of-concept spikes.

**Why:** These four carry all the technical risk. Proving they work costs days; discovering
they don't after building 65 screens costs months.

**Consequence:** The phase order in [feature-roadmap.md](feature-roadmap.md) is now the
*second* half of the plan. Auth, profile and the screen build follow the spikes.

---

## D-002 — Encryption: true end-to-end

**Decided:** Messages are end-to-end encrypted. Only the sender and recipient devices can
read message content. The server stores and relays ciphertext it cannot decrypt.

**Consequences — these are not negotiable side effects, they follow directly:**

| Impacted | What changes |
| --- | --- |
| **Server-side message search** | Impossible. SCR-080 can search officers, chat names and file metadata — **not message text**. In-chat search (SCR-032) must run locally on the device against decrypted messages. |
| **Message audit log** | SCR-106 can record *who messaged whom and when* (metadata), but **never message content**. If PHQ requires content auditing for compliance, this decision must be revisited. |
| **Group / department chat** | Substantially harder than 1:1. Each message must be encrypted for every member, or a sender-key scheme is needed. Adding or removing a member requires key rotation. |
| **Changing phone** | Old messages become unreadable on the new device unless a key-backup scheme is designed up front. |
| **Server push notifications** | The server cannot include message text in a push, because it cannot read it. Notifications show "New message from SI Sharma" only. |
| **The server itself** | Gets *simpler*. It becomes a dumb relay that stores and forwards opaque blobs. |

**Open risk:** PHQ has not confirmed that no content audit trail is required. If that
requirement arrives later, the message layer is rebuilt. Flag this to the project owner
before the group-chat work starts.

**Approach for the spike:** X25519 key exchange + AES-GCM message encryption via the
`cryptography` package. Full Signal Protocol (double ratchet, forward secrecy) is a later
hardening step, not a spike goal.

---

## D-003 — Backend: Supabase Realtime

**Decided:** Supabase, not a self-written Node server. Supabase Realtime provides the
WebSocket layer.

**Why:** Realtime chat, live tracking and calls cannot be faked with static data — they
need a server by definition. Supabase supplies one without writing or hosting server code,
and it is still WebSockets underneath, so nothing about the concept is hidden.

### The three Realtime features and what each is for

| Feature | Used for |
| --- | --- |
| **Broadcast** | Chat messages, typing indicators, WebRTC call signalling, live location pings |
| **Presence** | Online/offline officers and the "on duty" list — otherwise a build-it-yourself feature |
| **Postgres Changes** | Keeping the local message list in sync with the stored history |

Presence is the standout: SCR-020 presence indicators and the SCR-050 on-duty list come
almost free.

### Fits the E2E encryption decision cleanly

[D-002](#d-002--encryption-true-end-to-end) makes the server a dumb relay. Supabase stores
and forwards ciphertext in the message payload and never needs to read it, so nothing about
E2EE is compromised by not owning the server.

### Consequences and cautions

- **Region is chosen once, at project creation, and cannot be changed afterwards without a
  migration.** For police data this matters — pick deliberately, not by accepting the
  default.
- **Free-tier projects pause after a period of inactivity.** Fine for development; wake it
  before a demo.
- **Data sovereignty:** for production, police data sitting on a third party's
  infrastructure needs PHQ sign-off. Mitigation: **Supabase is open source and
  self-hostable** — the same client code can point at a self-hosted instance later. Verify
  this is acceptable before field deployment, not after.
- Postgres Row Level Security replaces a lot of hand-written role checks. It must be
  configured before any real data exists; RLS off means every officer can read everything.

**Environment on this machine:** Node v24.19.0 and npm 11.17.0 are installed if a
self-hosted or custom server is ever needed.

---

## Still open

- **Who may see live officer location, and when?** Needs a PHQ policy answer before the
  tracking spike becomes a real feature.
- **Does the app work offline?** Affects whether a local message database is needed.
- **Is the 2 km SOS radius fixed or configurable?**
