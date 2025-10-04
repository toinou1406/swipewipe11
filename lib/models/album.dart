class Album {
  final int? id;
  final String name;
  final String? coverPath;
  final bool isPremium;
  final DateTime createdAt;

  const Album({
    this.id,
    required this.name,
    this.coverPath,
    this.isPremium = false,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'cover_path': coverPath,
      'is_premium': isPremium ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Album.fromMap(Map<String, dynamic> map) {
    return Album(
      id: map['id'] as int?,
      name: map['name'] as String,
      coverPath: map['cover_path'] as String?,
      isPremium: (map['is_premium'] as int) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Album copyWith({
    int? id,
    String? name,
    String? coverPath,
    bool? isPremium,
    DateTime? createdAt,
  }) {
    return Album(
      id: id ?? this.id,
      name: name ?? this.name,
      coverPath: coverPath ?? this.coverPath,
      isPremium: isPremium ?? this.isPremium,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}