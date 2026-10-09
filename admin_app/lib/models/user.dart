import 'json_utils.dart';
import 'restaurant.dart';

class AppUser {
  const AppUser({required this.id, required this.name, required this.email});

  final String id;
  final String name;
  final String email;

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id']?.toString() ?? '',
        name: json['name'] as String? ?? '',
        email: json['email'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'email': email};
}

/// Respuesta de `POST /auth/login` y `POST /auth/register`.
class AuthResponse {
  const AuthResponse({
    required this.token,
    required this.expiresIn,
    required this.user,
    required this.restaurant,
  });

  final String token;

  /// Segundos de vigencia del JWT.
  final int expiresIn;
  final AppUser user;
  final Restaurant restaurant;

  factory AuthResponse.fromJson(Map<String, dynamic> json) => AuthResponse(
        token: json['token'] as String? ?? '',
        expiresIn: asInt(json['expiresIn'], 3600),
        user: AppUser.fromJson(asMap(json['user']) ?? const {}),
        restaurant: Restaurant.fromJson(asMap(json['restaurant']) ?? const {}),
      );
}
