enum Difficulty {
  easy('Facile'),
  medium('Moyen'),
  hard('Difficile');

  const Difficulty(this.label);
  final String label;

  static Difficulty fromString(String value) {
    return Difficulty.values.firstWhere(
      (e) => e.name == value,
      orElse: () => Difficulty.medium,
    );
  }
}
