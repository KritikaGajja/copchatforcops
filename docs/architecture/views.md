# Views & Widgets

> Applies to: `lib/**/views/**/*.dart`

## View Implementation

- Use `HookConsumerWidget`
- Watch state with `ref.watch`
- Handle loading/errors
- Validate inputs
- Implement proper auth flow

### Example View

```dart
class AuthWrapper extends HookConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authServiceProvider);
    final profileState = ref.watch(profileViewModelProvider);

    // Effect to fetch profile when authenticated
    useEffect(() {
      if (authState.hasValue && authState.value != AuthType.none) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(profileViewModelProvider.notifier).getUserProfile();
        });
      }
      return null;
    }, [authState.hasValue]);

    // Handle loading state
    if (authState.isLoading || profileState.isLoading) {
      return const LoadingScreen();
    }

    // Handle profile status based on auth type
    if (profileState.profile != null) {
      switch (profileState.profile!.status) {
        case ProfileStatus.approved:
          return const HomeScreen();
        case ProfileStatus.pending:
          return const PendingApprovalScreen();
        case ProfileStatus.rejected:
          return const RejectedScreen();
        case ProfileStatus.block:
          return const BlockedScreen();
      }
    }

    return const LoginScreen();
  }
}
```

## Form Handling

### 1. Form Controllers

```dart
// Using useMemoized for controllers
final controllers = useMemoized(
  () => {
    'email': TextEditingController(),
    'password': TextEditingController(),
  },
  const [],
);

// Dispose controllers
useEffect(() {
  return () {
    for (final controller in controllers.values) {
      controller.dispose();
    }
  };
}, const []);
```

### 2. Input Validation

```dart
// Phone number
FilteringTextInputFormatter.digitsOnly,
LengthLimitingTextInputFormatter(10),

// Date formatter
TextInputFormatter dateFormatter() {
  return TextInputFormatter.withFunction((oldValue, newValue) {
    var text = newValue.text;
    if (text.length > 8) return oldValue;
    text = text.replaceAll(RegExp(r'[^\d]'), '');
    if (text.length >= 2) {
      text = '${text.substring(0, 2)}/${text.substring(2)}';
    }
    if (text.length >= 5) {
      text = '${text.substring(0, 5)}/${text.substring(5)}';
    }
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  });
}
```

## UI Feedback

1. **Success Messages**
   - Green color (`0xFF4CAF50`)
   - Auto-dismiss after 8s
   - Clear action description

2. **Error Messages**
   - Red color (`0xFFE64238`)
   - Auto-dismiss after 8s
   - User-friendly error description
   - Actionable solution when possible

3. **Loading States**
   - Show progress indicators
   - Disable interactions
   - Maintain UI consistency

4. **Color Opacity**
   - Use `withValues(alpha: value)` for all color opacity modifications
   - Never use the deprecated `withOpacity` method
   - For animated opacity, use `withValues(alpha: value * animationValue)`

   ```dart
   // Static opacity
   Colors.red.withValues(alpha: 0.2)

   // Animated opacity
   Colors.red.withValues(alpha: 0.1 * (1 - animation.value))

   // Gradient opacity
   const Color(0XFFFFF1E8).withValues(alpha: 0)
   ```
