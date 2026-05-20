import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:my_app/CustomerWidgets/AppFloatingButton.dart';
import 'package:my_app/Pages/RecurringPaymen/recurring_payment_form.dart';
import 'package:my_app/api/DioClient.dart';
import 'package:my_app/api/sources/remoteDataSource.dart';
import 'package:my_app/Pages/Transactions/components/category_search_picker.dart';

class RecurringPaymentsPage extends StatefulWidget {
  const RecurringPaymentsPage({super.key});

  @override
  State<RecurringPaymentsPage> createState() => _RecurringPaymentsPageState();
}

class _RecurringPaymentsPageState extends State<RecurringPaymentsPage> {
  final UserRemoteDataSource api = UserRemoteDataSource(
    dio: Dioclient.instance,
  );

  List<dynamic> payments = [];
  List<dynamic> wallets = [];
  List<dynamic> categories = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      DateTime dt = DateTime.parse(dateStr);
      DateTime now = DateTime.now();
      String pattern = dt.year == now.year ? 'd MMM' : 'd MMM yy';
      return DateFormat(pattern, 'ru').format(dt).replaceAll('.', '');
    } catch (e) {
      return dateStr;
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      final results = await Future.wait([
        api.getRecurringPayments(),
        api.getWallets(),
        api.getCategories(),
      ]);

      setState(() {
        payments = results[0];
        wallets = results[1];
        categories = results[2];
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Ошибка загрузки: $e");
      setState(() => isLoading = false);
    }
  }

  void _openPaymentForm({Map<String, dynamic>? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RecurringPaymentForm(
        existing: existing,
        wallets: wallets,
        categories: categories,
        onSave: (data) async {
          bool ok = existing == null
              ? await api.addRecurringPayment(data)
              : await api.updateRecurringPayment(existing['idPayment'], data);
          if (ok && context.mounted) {
            Navigator.pop(context);
            _loadData();
          }
        },
        onDelete: () => _confirmDelete(existing!['idPayment']),
        onShowPicker: (selectedBillId, callback) {
          if (selectedBillId == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Сначала выберите счет")),
            );
            return;
          }

          String symbol = "₽";
          try {
            final wallet = wallets.firstWhere(
              (w) => w['billId']?.toString() == selectedBillId.toString(),
            );
            final String code = wallet['currencyCode'] ?? 'RUB';
            symbol = NumberFormat.simpleCurrency(name: code).currencySymbol;
          } catch (e) {
            debugPrint("Кошелек не найден в пикере: $e");
          }

          showDialog(
            context: context,
            builder: (ctx) => CategorySearchPicker(
              billId: selectedBillId,
              currencySymbol: symbol,
              onChanged: _loadData,
              onSelect: (id, [name]) => callback(id, name),
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(int id) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Удаление"),
        content: const Text("Вы уверены?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("ОТМЕНА"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("УДАЛИТЬ", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true && await api.deleteRecurringPayment(id)) {
      if (mounted) {
        Navigator.pop(context);
        _loadData();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator());
    final colorScheme = Theme.of(context).colorScheme;
    final bool isLight = Theme.of(context).brightness == Brightness.light;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: payments.isEmpty
            ? Center(
                child: Text(
                  "Нет запланированных операций",
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                itemCount: payments.length,
                itemBuilder: (context, index) {
                  final p = payments[index];
                  final double amount = (p['amount'] as num).toDouble();
                  final bool isIncome = amount > 0;
                  final wallet = wallets.firstWhere(
                    (w) => w['billId']?.toString() == p['billId']?.toString(),
                    orElse: () => <String, dynamic>{},
                  );
                  final String walletName =
                      wallet['name'] ?? p['billName'] ?? 'Счет не указан';
                  final String currencyCode =
                      wallet['currencyCode'] ?? p['currencyCode'] ?? 'RUB';
                  final String currencySymbol = NumberFormat.simpleCurrency(
                    name: currencyCode,
                  ).currencySymbol;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => _openPaymentForm(existing: p),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color:
                                        (isIncome ? Colors.green : Colors.red)
                                            .withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isIncome
                                        ? Icons.add_rounded
                                        : Icons.remove_rounded,
                                    color: isIncome
                                        ? Colors.green
                                        : Colors.redAccent,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p['description']?.isNotEmpty == true
                                            ? p['description']
                                            : "Без описания",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: colorScheme.onSurface,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: colorScheme
                                                  .primaryContainer
                                                  .withValues(
                                                    alpha: isLight ? 0.4 : 0.6,
                                                  ),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              p['categoryName'] ?? 'Общее',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isLight
                                                    ? Colors.black
                                                    : colorScheme
                                                          .onPrimaryContainer,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Flexible(
                                            child: Text(
                                              walletName,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  flex: 2,
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      "${isIncome ? '+' : ''}${amount.toStringAsFixed(2)} $currencySymbol",
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        color: isIncome
                                            ? Colors.green
                                            : Colors.redAccent,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today_rounded,
                                      size: 14,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _formatDate(p['nextPaymentDate']),
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: colorScheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.repeat_rounded,
                                      size: 14,
                                      color: colorScheme.primary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _getPeriodLabel(p['periodicity']),
                                      style: TextStyle(
                                        color: colorScheme.primary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: AppFloatingButton(
        onPressed: () => _openPaymentForm(),
      ),
    );
  }

  String _getPeriodLabel(String? period) {
    switch (period) {
      case 'DAILY':
        return 'Каждый день';
      case 'WEEKLY':
        return 'Раз в неделю';
      case 'MONTHLY':
        return 'Раз в месяц';
      case 'YEARLY':
        return 'Раз в год';
      default:
        return period ?? 'Период';
    }
  }
}
