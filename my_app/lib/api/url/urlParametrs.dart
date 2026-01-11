class UrlParameters {
  static String getFullUrl(String url) =>
      'http://localhost:8080/api/$url';

  static String registrationUrl = getFullUrl('auth/register');
  static String loginUrl = getFullUrl('auth/login');

  static String currenciesUrl = getFullUrl('currencies');
  static String billsUrl = getFullUrl('bills');
  static String transactionsUrl = getFullUrl('transactions');
  static String categoriesUrl = getFullUrl('categories');
  static String recurringPaymentsUrl = getFullUrl('recurring-payments');
  static String goalsUrl = getFullUrl('goals');
  static String calcAccumulationUrl = getFullUrl('goals/calculate-accumulation');
  static String calcDepositUrl = getFullUrl('goals/calculate-deposit');
  static String statsCategoriesUrl = getFullUrl('stats/categories');
  static String statsDailyUrl = getFullUrl('stats/daily');

  static String exchangeConvertUrl = getFullUrl('exchange/convert');
  static String exchangeHistoryUrl = getFullUrl('exchange/history');
}