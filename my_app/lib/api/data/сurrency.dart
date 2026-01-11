class Currency {
  final int idCurrencies;
  final String code;
  final String name;
  final String symbol;

  Currency({
    required this.idCurrencies, 
    required this.code, 
    required this.name, 
    required this.symbol
  });

  factory Currency.fromJson(Map<String, dynamic> json) {
    return Currency(
      idCurrencies: json['idCurrencies'],
      code: json['code'],
      name: json['name'],
      symbol: json['symbol'],
    );
  }
}