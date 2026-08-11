# Services

> Applies to: `lib/**/services/*.dart`

## Service Implementation

- Use `@Riverpod(keepAlive: true)` for global services
- Implement as singletons
- Clear responsibility
- Handle cleanup
- Manage token storage securely

### Example Service

```dart
@Riverpod(keepAlive: true)
class AddressService extends _$AddressService {
  Future<String?> validateGoogleSuggestedAddress({
    required String address,
    required String city,
    required String state,
    required String postalCode,
    required String autoFetchedPostalCode,
    required double placeLatitude,
    required double placeLongitude,
  }) async {
    // Only validate if the postal code has been manually changed
    if (postalCode == autoFetchedPostalCode) return null;

    try {
      final List<Location> postalLocations = await locationFromAddress(
        '$address, $city, $state, $postalCode',
      );

      if (postalLocations.isEmpty) {
        return 'Unable to validate postal code.';
      }

      final distance = Geolocator.distanceBetween(
        postalLocations.first.latitude,
        postalLocations.first.longitude,
        placeLatitude,
        placeLongitude,
      );

      if (distance > 1000) {
        return 'The entered postal code is too far from the selected address.';
      }

      return null;
    } catch (e) {
      return 'Unable to validate postal code.';
    }
  }
}
```

## Error Handling

### 1. Service-Level Errors

- Return nullable types for operations that might fail
- Use custom error types for specific failures
- Provide meaningful error messages

### 2. API Response Handling

```dart
@immutable
class ApiResponse<T> {
  final bool isSuccess;
  final T? data;
  final String? error;
  final String? message;

  const ApiResponse({
    required this.isSuccess,
    this.data,
    this.error,
    this.message,
  });

  factory ApiResponse.success(T data, {String? message}) =>
    ApiResponse(isSuccess: true, data: data, message: message);

  factory ApiResponse.error(String error) =>
    ApiResponse(isSuccess: false, error: error);
}
```
