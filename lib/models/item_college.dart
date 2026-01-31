class ItemCollege {
  final int? id;
  final int itemId;
  final int collegeId;

  ItemCollege({
    this.id,
    required this.itemId,
    required this.collegeId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'item_id': itemId,
      'college_id': collegeId,
    };
  }

  factory ItemCollege.fromMap(Map<String, dynamic> map) {
    return ItemCollege(
      id: map['id'] as int?,
      itemId: map['item_id'] as int,
      collegeId: map['college_id'] as int,
    );
  }

  ItemCollege copyWith({
    int? id,
    int? itemId,
    int? collegeId,
  }) {
    return ItemCollege(
      id: id ?? this.id,
      itemId: itemId ?? this.itemId,
      collegeId: collegeId ?? this.collegeId,
    );
  }
}
