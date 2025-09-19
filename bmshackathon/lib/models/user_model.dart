class AppUser {
  final String id;
  final String name;
  final String role; // 'patient' or 'admin'

  const AppUser({required this.id, required this.name, required this.role});

  bool get isAdmin => role.toLowerCase() == 'admin';
}
