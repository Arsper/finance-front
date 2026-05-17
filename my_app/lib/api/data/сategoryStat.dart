class CategoryStat {
  final int categoryId;
  final String categoryName;
  final double totalAmount;

  CategoryStat({
    required this.categoryId,
    required this.categoryName,
    required this.totalAmount,
  });

  factory CategoryStat.fromJson(Map<String, dynamic> json) {
    return CategoryStat(
      categoryId: json['categoryId'] ?? json['category_id'] ?? 0,
      categoryName:
          json['categoryName'] ?? json['category_name'] ?? 'Без названия',
      totalAmount: (json['amount'] ?? json['totalAmount'] ?? 0.0).toDouble(),
    );
  }
}
