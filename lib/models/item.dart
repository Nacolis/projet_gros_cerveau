class Item {
  final int? id;
  final int itemNumber;
  final String name;

  Item({
    this.id,
    required this.itemNumber,
    required this.name,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'item_number': itemNumber,
      'name': name,
    };
  }

  factory Item.fromMap(Map<String, dynamic> map) {
    return Item(
      id: map['id'] as int?,
      itemNumber: map['item_number'] as int,
      name: map['name'] as String,
    );
  }

  Item copyWith({
    int? id,
    int? itemNumber,
    String? name,
  }) {
    return Item(
      id: id ?? this.id,
      itemNumber: itemNumber ?? this.itemNumber,
      name: name ?? this.name,
    );
  }
}
