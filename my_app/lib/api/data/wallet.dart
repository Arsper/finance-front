class Wallet {
  final int? id; // null для новых
  final String name;
  final String type;
  final double startBalance;
  final int currencyId;

  Wallet({this.id, required this.name, required this.type, required this.startBalance, required this.currencyId});

  Map<String, dynamic> toJson() => {
    "name": name,
    "type": type,
    "startBalance": startBalance,
    "currencyId": currencyId,
  };
}