class UserModel {
  final String id;
  final String name;
  final String email;
  final String? photoUrl;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.photoUrl,
  });

  UserModel copyWith({String? name, String? photoUrl}) => UserModel(
        id: id,
        name: name ?? this.name,
        email: email,
        photoUrl: photoUrl ?? this.photoUrl,
      );
}
