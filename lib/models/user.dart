class User {
  final int id;
  final String username;
  final String email;
  final String? token;
  final List<String>? roles;

  User({
    required this.id,
    required this.username,
    required this.email,
    this.token,
    this.roles,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? 0,
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      token: json['token'],
      roles: json['roles'] != null ? List<String>.from(json['roles']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'token': token,
      'roles': roles,
    };
  }
}
