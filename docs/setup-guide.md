# CopChat — Setup Guide

A step-by-step bootstrap checklist. Run these yourself, in order. Each step says what
"done" looks like so you can tell when something went wrong.

> **Phase 0 — no backend yet.** Repositories return hardcoded data instead of calling an
> API. Every other layer is built exactly as the architecture docs specify. When the real
> API arrives, only the *bodies* of the repository methods change — models, view models,
> views, and states are untouched. That swap is the proof the architecture works, so
> nothing above the repository layer may ever assume data is static.

---

## Step 1 — Verify the toolchain

```bash
flutter --version
flutter doctor
```

**Expect:** Flutter 3.44.6, Dart 3.12.2. `flutter doctor` should show ✓ for
Flutter, Android toolchain, and at least one device. Chrome/Windows desktop is enough to
start; you don't need iOS on Windows.

---

## Step 2 — Add dependencies

Use `pub add` rather than hand-editing `pubspec.yaml` — it resolves versions compatible
with your SDK automatically.

```bash
# State management + DI + hooks
flutter pub add flutter_riverpod hooks_riverpod flutter_hooks riverpod_annotation

# Storage
flutter pub add shared_preferences

# Networking — add when a real backend exists (Phase 1), not now
# flutter pub add dio flutter_secure_storage

# Navigation
flutter pub add go_router

# Code generation + lints (dev only)
flutter pub add --dev build_runner riverpod_generator custom_lint riverpod_lint
```

**Expect:** `pubspec.yaml` gains a `dependencies` and `dev_dependencies` block with all of
the above, and `pub get` finishes with `Got dependencies!`.

> Why both `flutter_riverpod` and `hooks_riverpod`: `HookConsumerWidget` (required by
> [views.md](architecture/views.md)) comes from `hooks_riverpod`. Keep both listed so the
> import you reach for always resolves.

---

## Step 3 — Turn on the lints

Edit `analysis_options.yaml` at the project root and add the `custom_lint` plugin:

```yaml
include: package:flutter_lints/flutter.yaml

analyzer:
  plugins:
    - custom_lint
  errors:
    invalid_annotation_target: ignore

linter:
  rules:
    - avoid_print
    - prefer_const_constructors
    - prefer_final_locals
```

**Expect:** `dart run custom_lint` runs and reports Riverpod-specific issues (e.g. "use
`ref.read` inside callbacks, `ref.watch` in build").

---

## Step 4 — Create the folder skeleton

```bash
mkdir lib/core/constants lib/core/services lib/core/theme lib/core/utils lib/core/routes lib/core/widgets
mkdir lib/features
```

On PowerShell, `mkdir a, b, c` takes a comma-separated list instead.

**Expect:** the tree in [core-architecture.md](architecture/core-architecture.md).
Empty directories won't survive a `git add` — that's fine, they fill up in Step 5.

---

## Step 5 — Write the core plumbing (in this order)

These four are the foundation everything else builds on. Build them one at a time and run
`flutter analyze` after each.

1. **`lib/core/services/api_response.dart`** — the `ApiResponse<T>` class, copied verbatim
   from [services.md](architecture/services.md). No dependencies, so start here.

2. **`lib/core/constants/app_constants.dart`** — app-wide constants. In Phase 1 this gains
   the base URL, timeouts, and endpoint paths; keep every URL string in this one file.

3. **`lib/core/services/base_api_service.dart`** — **deferred to Phase 1.** For now each
   repository stands alone and returns `ApiResponse.success(<hardcoded data>)` after a
   short `Future.delayed` so loading states are actually visible and testable.

   When the backend lands, this class wraps a `Dio` instance and exposes
   `get` / `post` / `put` / `delete`, and repositories start extending it. It will own:
   - base options (base URL, connect/receive timeouts)
   - an interceptor that attaches the auth token from secure storage
   - an interceptor that logs requests in debug mode only

4. **`lib/core/services/navigation_service.dart`** and
   **`lib/core/services/dialog_service.dart`** — both `@Riverpod(keepAlive: true)`.
   View models call these instead of touching `Navigator` or `showDialog` directly, which
   is what keeps `BuildContext` out of the view model layer.

**Expect:** `flutter analyze` clean except for missing `.g.dart` parts — Step 6 fixes those.

---

## Step 6 — Wire up code generation

Every file with `@riverpod` needs a `part` directive matching its own filename:

```dart
// lib/core/services/navigation_service.dart
part 'navigation_service.g.dart';
```

Then start the generator and leave it running in its own terminal:

```bash
dart run build_runner watch -d
```

**Expect:** `.g.dart` files appear next to each annotated file, and the `xViewModelProvider`
/ `xServiceProvider` symbols start resolving.

---

## Step 7 — Wrap the app in ProviderScope

Edit `lib/main.dart`:

```dart
void main() {
  runApp(const ProviderScope(child: CopChatApp()));
}
```

**Expect:** `flutter run` launches. Any `ref.watch` outside a `ProviderScope` throws at
runtime, so this must happen before the first provider is used.

---

## Step 8 — Build the first feature vertically

Pick one feature — `auth` is the natural first — and build **all six folders** for it
before starting a second feature:

```
lib/features/auth/
├── models/          # UserModel, AuthType enum
├── repositories/    # AuthRepository extends BaseApiService
├── providers/       # auth_view_model.dart + auth_state.dart
├── services/        # token storage, session refresh
├── views/           # login_screen.dart, auth_wrapper.dart
└── widgets/         # feature-local widgets only
```

Building one feature end-to-end surfaces every gap in the core layer while it's still
cheap to change. Two half-features surface none of them.

---

## Common failure points

| Symptom | Cause | Fix |
| --- | --- | --- |
| `Undefined name 'xProvider'` | `build_runner` hasn't generated the `.g.dart` | Run `dart run build_runner watch -d` |
| `part 'x.g.dart' not found` | Missing/misspelled `part` directive | Filename in `part` must exactly match the `.dart` file |
| Conflicting outputs on build | Stale generated files | `dart run build_runner build --delete-conflicting-outputs` |
| `ProviderNotFoundException` | No `ProviderScope` above the widget | Step 7 |
| `ref.watch` used in a callback | Riverpod lint violation | Use `ref.read` outside `build` |
| Version solving failed | A package predates your Dart SDK | `flutter pub upgrade --major-versions` |
| `withOpacity` deprecation warning | Old API | `withValues(alpha: …)` — see [views.md](architecture/views.md) |
