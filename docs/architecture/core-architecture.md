# Core Architecture

> Applies to: `lib/**/*.dart`

Core architectural principles and project structure for the CopChat app.

## Architecture Principles

- **Feature-First**: Each feature module is self-contained and independent
- **Clean Architecture**: Implement MVVM pattern with clear layer separation
- **Type Safety**: Use strong typing, avoid `dynamic`
- **Single Responsibility**: Each class and file serves one clear purpose
- **Dependency Injection**: Use Riverpod for state management and DI
- **UI/UX Consistency**: Follow standardized component patterns

## Project Structure

```
lib/
├── core/              # Shared code and utilities
│   ├── constants/     # Configuration constants
│   ├── services/      # Core services (API, Auth, Navigation, Dialog)
│   ├── theme/         # App styling
│   ├── utils/         # Helper functions
│   ├── routes/        # Navigation
│   └── widgets/       # Shared widgets
└── features/          # Feature modules
    └── feature_name/
        ├── models/        # Data models
        ├── providers/     # State management (view models + state)
        ├── repositories/  # Data access
        ├── services/      # Feature services
        ├── views/         # UI screens
        └── widgets/       # Feature widgets
```

## Layer Rules

| Layer | May depend on | Must never depend on |
| --- | --- | --- |
| `views/`, `widgets/` | providers, models, theme | repositories, dio |
| `providers/` (view models) | services, repositories, models | Flutter widgets, `BuildContext` held in state |
| `repositories/` | `BaseApiService`, models | providers, views |
| `services/` | core services, models | views |
| `models/` | nothing app-specific | everything else |

A feature never imports another feature's `repositories/` or `providers/` directly. If two
features need the same thing, it belongs in `core/`.
