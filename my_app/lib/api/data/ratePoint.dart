class RatePoint {
  final DateTime date;
  final double rate;

  RatePoint({required this.date, required this.rate});

  factory RatePoint.fromJson(Map<String, dynamic> json) {
    return RatePoint(
      date: DateTime.parse(json['date']),
      rate: (json['rate'] as num).toDouble(),
    );
  }
}