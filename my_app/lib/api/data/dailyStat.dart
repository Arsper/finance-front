class DailyStat {
  final DateTime date;
  final double expenses;
  final double incomes;

  DailyStat({
    required this.date,
    required this.expenses,
    required this.incomes,
  });

  factory DailyStat.fromJson(Map<String, dynamic> json) {
    return DailyStat(
      date: json['transactionDate'] != null
          ? DateTime.parse(json['transactionDate'])
          : (json['date'] != null
                ? DateTime.parse(json['date'])
                : DateTime.now()),
      expenses: (json['expenses'] ?? json['expense'] ?? 0.0).toDouble().abs(),
      incomes: (json['incomes'] ?? json['income'] ?? 0.0).toDouble(),
    );
  }
}
