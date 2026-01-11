class CategoryStat {
  final String categoryName;
  final double totalAmount;

  CategoryStat({required this.categoryName, required this.totalAmount});

  factory CategoryStat.fromJson(Map<String, dynamic> json) {
    return CategoryStat(
      categoryName: json['categoryName'] ?? 'Без категории',
      totalAmount: (json['totalAmount'] as num).toDouble(),
    );
  }
}