class College {
  final int? id;
  final String name;

  College({
    this.id,
    required this.name,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
    };
  }

  factory College.fromMap(Map<String, dynamic> map) {
    return College(
      id: map['id'] as int?,
      name: map['name'] as String,
    );
  }

  College copyWith({
    int? id,
    String? name,
  }) {
    return College(
      id: id ?? this.id,
      name: name ?? this.name,
    );
  }
}
