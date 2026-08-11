# View Models

> Applies to: `lib/**/providers/*_view_model.dart`

## View Model Implementation

- Use `@riverpod` annotation
- Handle loading states
- Implement error handling
- Use service injection
- Handle navigation through `NavigationService`

### Example ViewModel

```dart
@riverpod
class RegisterViewModel extends _$RegisterViewModel {
  NavigationService get _navigationService =>
      ref.read(navigationServiceProvider.notifier);
  DialogService get _dialogService =>
      ref.read(dialogServiceProvider.notifier);

  @override
  RegisterState build() => const RegisterState();

  Future<void> validateForm({
    required String name,
    required String email,
    required String phone,
    required String zipCode,
    required String dateOfBirth,
    required String address,
    required String city,
    required String state,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      // Validation logic
      final addressValidation = await ref.read(addressServiceProvider).validateAddress(
        address: address,
        city: city,
        state: state,
        postalCode: zipCode,
      );

      if (addressValidation != null) {
        _dialogService.showError(context, addressValidation);
        return;
      }

      // Handle success
      state = state.copyWith(
        validation: RegisterValidationState(),
        currentStep: 2,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
      _dialogService.showError(context, e.toString());
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }
}
```

## State Management

### 1. State Classes

```dart
@immutable
class RegisterState {
  final bool isLoading;
  final String? error;
  final RegisterValidationState validation;
  final int currentStep;

  const RegisterState({
    this.isLoading = false,
    this.error,
    this.validation = const RegisterValidationState(),
    this.currentStep = 1,
  });

  RegisterState copyWith({
    bool? isLoading,
    String? error,
    RegisterValidationState? validation,
    int? currentStep,
  }) => RegisterState(
    isLoading: isLoading ?? this.isLoading,
    error: error,  // Allow setting to null
    validation: validation ?? this.validation,
    currentStep: currentStep ?? this.currentStep,
  );
}
```

### 2. State Updates

```dart
// Atomic updates
state = state.copyWith(isLoading: true);

// Batch updates
state = state.copyWith(
  isLoading: false,
  error: null,
  currentStep: 2,
);

// Conditional updates
state = state.copyWith(
  validation: state.validation.copyWith(
    emailError: email.isEmpty ? 'Email required' : null,
  ),
);
```

## Notes

- `error` in `copyWith` is intentionally assigned directly (not `??`) so it can be cleared
  back to `null`. Follow that pattern for any field that must be resettable.
- Always reset `isLoading` in a `finally` block so a thrown exception cannot leave the UI
  stuck in a spinner.
