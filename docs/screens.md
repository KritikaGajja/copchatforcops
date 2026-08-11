# CopChat v1 — Complete Screen Inventory

Every screen needed to ship the [MVP scope](mvp-scope.md), with status against the Lovable
concept design.

- **Designed** — exists in the Lovable concept (6 screens)
- **Missing** — required by the MVP scope, not yet designed

**Total: 71 screens. Designed: 6. Missing: 65.**

That ratio is normal. A concept design shows the *happy path* to sell the idea; a build
needs the plumbing, the error states, and the admin side.

---

## The critical gap: there is no app shell

None of the six designed screens has a bottom navigation bar. Live Officer Location, SOS,
and Calls all exist as screens with no route into them. **This must be designed first** —
every other screen hangs off it.

### Proposed navigation

```
┌─────────────────────────────────────────────┐
│                                             │
│              (active screen)                │
│                                             │
├─────────────────────────────────────────────┤
│  Chats    Officers    [SOS]    Map    More  │
└─────────────────────────────────────────────┘
```

| Tab | Lands on | Why |
| --- | --- | --- |
| **Chats** | SCR-020 Chat List | Default tab, highest-frequency use |
| **Officers** | SCR-081 Officer Directory | Find and call anyone; entry to profiles |
| **SOS** | SCR-060 SOS Trigger | Centre, raised, red. Reachable in one tap from anywhere |
| **Map** | SCR-050 Live Officers Map | The tracking screen that currently has no route |
| **More** | SCR-091 Settings hub | Profile, calls, notifications, admin (role-gated) |

Two decisions inside this:

1. **SOS is centre and always visible.** An officer in danger cannot navigate two levels.
   Long-press arms it directly from the tab bar, so the SOS screen is a confirmation, not
   a gate.
2. **More is role-aware.** Admin entries appear only for Super Admin / PHQ Admin / Dept
   Head. The other four tabs are identical for all roles.

`SCR-000 App Shell` — **Missing** — the scaffold holding the nav bar, the connection-status
banner, and the incoming-call overlay.

---

## 1. Authentication — `features/auth/`

| ID | Screen | Status | Notes |
| --- | --- | --- | --- |
| SCR-001 | Splash / Token Check | Missing | Validates stored token, routes to Login or Shell |
| SCR-002 | Secure Login | **Designed** | Badge/Service ID + password |
| SCR-003 | OTP / 2FA Verification | Missing | Near-mandatory for police access |
| SCR-004 | Forgot Password | Missing | Likely routes to admin, not self-service |
| SCR-005 | Set New Password | Missing | Also used on first-ever login |
| SCR-006 | Device Pending Approval | Missing | New device must be approved by admin |
| SCR-007 | Access Denied / Blocked | Missing | Suspended or revoked account |
| SCR-008 | Force Update | Missing | Push a mandatory version on security patches |

**No signup screen — correct.** Accounts are created by administrators, never
self-registered. Worth stating explicitly so nobody adds one.

---

## 2. Profile & Identity — `features/profile/`

| ID | Screen | Status | Notes |
| --- | --- | --- | --- |
| SCR-010 | My Profile | Missing | Badge no., rank, station, department, photo |
| SCR-011 | Edit Profile | Missing | Limited fields — rank/badge are admin-controlled |
| SCR-012 | Officer Profile | Missing | Opened by tapping any name; chat/call/locate actions |
| SCR-013 | Change Password | Missing | |
| SCR-014 | My Devices | Missing | Active sessions, remote logout |
| SCR-015 | Duty Status | Missing | On-duty / off-duty toggle |
| SCR-016 | Logout Confirm | Missing | Dialog; must clear secure storage and close socket |

**SCR-015 is a gap the design exposes.** Screen 05 lists "Officers on duty" — but nothing
lets an officer set that status. Duty state also gates location sharing.

---

## 3. Chat — `features/chat/`

| ID | Screen | Status | Notes |
| --- | --- | --- | --- |
| SCR-020 | Chat List | **Designed** | Tabs: All / Direct / Groups / Broadcasts |
| SCR-021 | Chat Thread (1:1) | **Designed** | Receipts, typing, location bubble, file bubble |
| SCR-022 | Department / Group Thread | Missing | Needs sender names, member count, admin controls |
| SCR-023 | New Chat | Missing | The `+` FAB on SCR-020 currently goes nowhere |
| SCR-024 | Create Group | Missing | Name, department, members |
| SCR-025 | Group Info | Missing | Members, roles, mute, leave |
| SCR-026 | Add / Remove Members | Missing | |
| SCR-027 | Chat Info (1:1) | Missing | Shared media, mute, block, clear |
| SCR-028 | Message Info | Missing | Who read it and when — matters for orders |
| SCR-029 | Forward Message | Missing | |
| SCR-030 | Message Actions | Missing | Long-press sheet: reply, forward, copy, delete, star |
| SCR-031 | Shared Media & Docs | Missing | Per-chat: Media / Docs / Links tabs |
| SCR-032 | Search in Chat | Missing | |

---

## 4. Files — `features/files/`

| ID | Screen | Status | Notes |
| --- | --- | --- | --- |
| SCR-040 | Attachment Sheet | Missing | Camera / Gallery / Document / Location |
| SCR-041 | Image Preview & Send | Missing | Caption before sending |
| SCR-042 | Document Viewer | Missing | In-app PDF/DOC preview |
| SCR-043 | Full-screen Image Viewer | Missing | Pinch-zoom, save, share |
| SCR-044 | Downloads | Missing | Everything saved on this device |

SCR-021 shows a `duty-roster-w32.pdf` bubble — tapping it needs SCR-042, which doesn't exist
yet.

---

## 5. Location — `features/location/`

| ID | Screen | Status | Notes |
| --- | --- | --- | --- |
| SCR-050 | Live Officers Map | **Designed** | Pins, distances, on-duty list |
| SCR-051 | Officer Map Detail | Missing | Tap a pin → sheet with call / chat / navigate |
| SCR-052 | Share Location | Missing | One-time vs live; duration picker |
| SCR-053 | Live Location Expanded | Missing | Tapping the map bubble in a thread |
| SCR-054 | Location Permission Flow | Missing | Denied, denied-forever, service-off — all real states |
| SCR-055 | Nearby Officers | Missing | List view sorted by distance |
| SCR-056 | Location History | Missing | Track playback; **restricted by role** |
| SCR-057 | Location Privacy | Missing | Who can see me; stop sharing |

**SCR-052 is directly implied by the design.** SCR-021 shows `LIVE LOCATION · 15 MIN` — but
there's no screen where the officer chose "15 minutes".

---

## 6. Emergency — `features/emergency/`

| ID | Screen | Status | Notes |
| --- | --- | --- | --- |
| SCR-060 | SOS Trigger | **Designed** | Hold 3 s, 2 km radius, GPS locked |
| SCR-061 | SOS Active | Missing | **Critical.** After firing — status, responders, cancel |
| SCR-062 | SOS Alert Received | Missing | **Critical.** Full-screen alert with map + Respond |
| SCR-063 | SOS Coordination | Missing | Who is responding, ETA, live positions |
| SCR-064 | Broadcast Compose | Missing | Dept Head / PHQ only; the Broadcasts tab has no source |
| SCR-065 | Broadcast Detail | Missing | Read acknowledgements |
| SCR-066 | SOS History | Missing | Audit log, false-alarm resolution |

**SCR-061 and SCR-062 are the biggest holes in the whole design.** SOS as designed can be
sent but never cancelled, and no screen exists for the officers who *receive* it — which is
the entire point of the feature.

---

## 7. Calls — `features/calls/`

| ID | Screen | Status | Notes |
| --- | --- | --- | --- |
| SCR-070 | Call History | Missing | SCR-020 shows "Missed voice call" with no call log |
| SCR-071 | Outgoing / Ringing | Missing | |
| SCR-072 | Incoming Call | Missing | **Critical.** Full-screen, must work over lock screen |
| SCR-073 | Voice Call Active | Missing | Distinct from video — no video controls |
| SCR-074 | Video Call Active | **Designed** | Mute / Video / Share / Notes |

---

## 8. Search — `features/search/`

| ID | Screen | Status | Notes |
| --- | --- | --- | --- |
| SCR-080 | Global Search | Missing | Tabs: All / Officers / Chats / Documents |
| SCR-081 | Officer Directory | Missing | Browse by department, rank, station |
| SCR-082 | Document Library | Missing | Every shared document, filterable |

The search icon on SCR-020 currently has no destination.

---

## 9. Notifications & Settings — `features/notifications/`, `core/`

| ID | Screen | Status | Notes |
| --- | --- | --- | --- |
| SCR-090 | Notification Centre | Missing | |
| SCR-091 | Settings Hub | Missing | Root of the More tab |
| SCR-092 | Notification Settings | Missing | Per-channel; SOS channel not mutable |
| SCR-093 | Privacy & Security | Missing | Screenshot block, biometric lock, auto-lock |
| SCR-094 | Storage & Data | Missing | Cache, auto-download on mobile data |
| SCR-095 | About & Help | Missing | Version, support contact, policy |

---

## 10. Administration — `features/admin/`

**Role-gated. Entirely absent from the concept design.**

| ID | Screen | Status | Notes |
| --- | --- | --- | --- |
| SCR-100 | Admin Dashboard | Missing | Active officers, open SOS, alerts |
| SCR-101 | User Management | Missing | Search, filter, suspend |
| SCR-102 | Create / Edit Officer | Missing | The only way an account is created |
| SCR-103 | Role Assignment | Missing | The four-tier RBAC |
| SCR-104 | Department Management | Missing | Departments, stations, hierarchy |
| SCR-105 | Device Approvals | Missing | Approve/reject new device logins |
| SCR-106 | Audit Log | Missing | Who accessed what — likely a legal requirement |
| SCR-107 | Broadcast Management | Missing | History and reach of broadcasts |

The MVP names four roles — Super Admin, PHQ Administrator, Department Head, Police Officer —
but the design only shows the Police Officer view. **Three of your four roles have no
interface at all.**

---

## 11. Cross-cutting states

Not screens, but every screen needs them, and they are the most commonly skipped work.

| State | Where it matters |
| --- | --- |
| Loading / skeleton | Every list and detail screen |
| Empty | No chats, no officers on duty, no search results, no documents |
| Error + retry | Every network call |
| **Offline / socket disconnected** | A persistent banner in the shell — non-negotiable for a chat app |
| Permission denied | Location, camera, microphone, notifications, storage |
| Role denied | Any screen a role cannot open |

---

## Design questions to resolve

Raised by the concept, and cheaper to settle now than after the backend exists.

1. **"End-to-end encrypted" vs. audit logging — these conflict.** Real E2EE means the
   server cannot read messages. That rules out server-side message search (SCR-080) and
   makes a message audit log (SCR-106) impossible. For police work an audit trail usually
   outranks true E2EE. Decide which it is, because it changes the entire backend design.
   If the answer is "encrypted in transit and at rest, not end-to-end", the UI should say
   that instead.

2. **The 2 km SOS radius — fixed or configurable?** It's hardcoded in the design. Dense
   Jaipur vs. a rural district are very different. Recommend server-configurable per
   district.

3. **Who may see live location, and when?** Continuous tracking of officers is a serious
   privacy question. Options: always while on duty, only during an active SOS, or
   officer-initiated. This needs a policy answer from PHQ before SCR-057 can be designed.

4. **Does the app work offline at all?** Field officers lose signal constantly. If queued
   messages and cached threads are expected, that changes the repository layer and needs a
   local database from Phase 3 — not bolted on later.

---

## Suggested design order

1. **SCR-000 App Shell** — unblocks everything
2. **SCR-062, SCR-061** — the missing half of SOS
3. **SCR-072** — incoming call
4. **SCR-012, SCR-081** — officer profile and directory; everything links to these
5. **SCR-023, SCR-024, SCR-025** — the chat flows the `+` button needs
6. **SCR-100–SCR-107** — the admin app, effectively a second product
7. Cross-cutting states, applied across the whole set
