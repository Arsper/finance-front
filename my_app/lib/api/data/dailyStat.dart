class DailyStat {
  final DateTime date;
  final double amount;

  DailyStat({required this.date, required this.amount});

  factory DailyStat.fromJson(Map<String, dynamic> json) {
    return DailyStat(
      date: DateTime.parse(json['date']),
      amount: (json['amount'] as num).toDouble(),
    );
  }
}