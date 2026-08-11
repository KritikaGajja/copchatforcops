# CopChat

Flutter app for police / departmental chat. Package name: `copchatforcops`.

## Toolchain

- Flutter **3.44.6** stable, Dart **3.12.2**
- SDK path on this machine: `D:\flutter sdk\flutter_windows_3.19.6-stable\flutter`
  (the folder name is stale — the SDK inside it is 3.44.6)

## Architecture

This project follows a **feature-first MVVM** layout with **Riverpod** for state management
and DI. The full rules live in [docs/architecture/](docs/architecture/) and are imported
below so they are always in context.

@docs/architecture/core-architecture.md
@docs/architecture/data-layer.md
@docs/architecture/services.md
@docs/architecture/view-models.md
@docs/architecture/views.md

## Quick rules

- Views are `HookConsumerWidget`, never `StatefulWidget`.
- View models are `@riverpod` notifiers in `providers/`, named `*_view_model.dart`.
- Global services are `@Riverpod(keepAlive: true)`.
- Repositories extend `BaseApiService` and return `ApiResponse<T>`; `DioException` never
  escapes a repository.
- Models are `@immutable` with `fromJson` / `toJson` / `copyWith`.
- Use `withValues(alpha:)`, never `withOpacity`.
- No `dynamic`. No business logic in widgets. No `BuildContext` stored in state.

## Commands

```bash
flutter pub get
dart run build_runner watch -d     # keep running while developing
flutter analyze
flutter test
flutter run
```

Riverpod code generation is required: every `@riverpod` / `@Riverpod` annotated file has a
`part 'x.g.dart';` directive and will not compile until `build_runner` has run.

## Setup

See [docs/setup-guide.md](docs/setup-guide.md) for the step-by-step bootstrap checklist.

## Product

- [docs/mvp-scope.md](docs/mvp-scope.md) — the v1 feature spec (source of truth for scope)
- [docs/feature-roadmap.md](docs/feature-roadmap.md) — module map and phase order
- [docs/screens.md](docs/screens.md) — all 71 screens, IDs, and design status
- [docs/decisions.md](docs/decisions.md) — **read first.** Decisions made and their
  consequences (E2E encryption, spike-first build order, local Node backend)
- [docs/tech-choices.md](docs/tech-choices.md) — the free/self-hosted stack, no paid APIs
- [docs/api/supabase-structure.md](docs/api/supabase-structure.md) — **the live API spec**:
  table schema, RLS, realtime channels, Edge Functions
- [docs/api/api-conventions.md](docs/api/api-conventions.md) — superseded by the above;
  kept as the spec if CopChat is ever self-hosted behind a custom REST API
- [docs/api/screen-api-matrix.csv](docs/api/screen-api-matrix.csv) — every screen mapped to
  the endpoints and socket events it uses

**Phase 0: there is no backend.** Repositories return hardcoded data. Nothing above the
repository layer may assume that.

## Working agreement

The project owner is building this to learn the architecture. Guide, explain, and diagnose —
do not write feature code unless explicitly asked. Point at the concept and the doc, let
them type it, then review.
