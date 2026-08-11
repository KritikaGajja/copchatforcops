# Data Layer — Models & Repositories

> Applies to: `lib/**/models/*.dart`, `lib/**/repositories/*.dart`

## Model Implementation

- Use `@immutable` annotation
- Implement `fromJson`/`toJson` methods
- Include `copyWith` methods
- Implement proper enum handling

### Example Model

```dart
enum ProfileStatus {
  approved,
  pending,
  rejected,
  block;

  static ProfileStatus fromString(String status) {
    return ProfileStatus.values.firstWhere(
      (e) => e.name == status.toLowerCase(),
      orElse: () => ProfileStatus.pending,
    );
  }
}

@immutable
class UserModel {
  final String id;
  final String name;
  final ProfileStatus status;

  const UserModel({
    required this.id,
    required this.name,
    required this.status,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    id: json['id'],
    name: json['name'],
    status: ProfileStatus.fromString(json['status']),
  );

  UserModel copyWith({
    String? id,
    String? name,
    ProfileStatus? status,
  }) => UserModel(
    id: id ?? this.id,
    name: name ?? this.name,
    status: status ?? this.status,
  );
}
```

## Repository Implementation

- Extend `BaseApiService`
- Return typed responses (`ApiResponse<T>`)
- Handle `DioException`
- Format dates properly
- Handle API errors consistently

### Example Repository

```dart
class UserRepository extends BaseApiService {
  Future<ApiResponse<UserModel>> getUser(String id) async {
    try {
      final response = await get('/users/$id');
      return ApiResponse.success(
        UserModel.fromJson(response.data),
      );
    } on DioException catch (e) {
      return ApiResponse.error(e.message);
    }
  }

  Future<ApiResponse<void>> updateUser(String id, Map<String, dynamic> data) async {
    try {
      await put('/users/$id', data: data);
      return const ApiResponse.success(null);
    } on DioException catch (e) {
      return ApiResponse.error(e.message);
    }
  }
}
```

## Notes

- Repositories are the **only** place raw JSON is touched. A view model never sees a
  `Map<String, dynamic>`.
- Never let a `DioException` escape a repository — always convert to `ApiResponse.error`.
