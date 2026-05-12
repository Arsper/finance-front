import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_app/CustomerWidgets/CustomerEdit.dart';
import 'package:my_app/Pages/Transactions/TransactionsPage.dart';
import 'package:my_app/api/DioClient.dart';
import 'package:my_app/api/data/сurrency.dart';
import 'package:my_app/api/sources/remoteDataSource.dart';
import 'package:my_app/helpers/validators.dart';

class BalanceTab extends StatefulWidget {
  const BalanceTab({super.key});

  @override
  State<BalanceTab> createState() => _BalanceTabState();
}

class _BalanceTabState extends State<BalanceTab> {
  final UserRemoteDataSource api = UserRemoteDataSource(
    dio: Dioclient.instance,
  );

  List<dynamic> wallets = [];
  List<Currency> currencies = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  Future<void> _refreshData() async {
    setState(() => isLoading = true);
    try {
      final w = await api.getWallets();
      final c = await api.getCurrencies();
      setState(() {
        wallets = w;
        currencies = c;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Ошибка загрузки: $e");
      setState(() => isLoading = false);
    }
  }

  Future<bool> _showDeleteConfirmDialog(String walletName) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Удаление счета'),
            content: Text('Вы уверены, что хотите удалить счет "$walletName"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Отмена', style: TextStyle(color: Colors.grey)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Удалить', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _openWalletForm({Map<String, dynamic>? existingWallet}) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: existingWallet?['name']);
    final balanceController = TextEditingController(
      text: existingWallet == null
          ? "0"
          : existingWallet['currentBalance']?.toString(),
    );

    String selectedType = existingWallet?['type'] ?? 'Debit';

    // Автовыбор первой валюты при создании нового счета
    int? selectedCurrencyId = existingWallet != null
        ? existingWallet['currencyId']
        : (currencies.isNotEmpty ? currencies.first.idCurrencies : null);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(existingWallet == null ? 'Новый счет' : 'Изменить счет'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CustomerEdit(
                    controller: nameController,
                    label: 'Название',
                    icon: Icons.account_balance_wallet,
                    validator: AppValidators.required,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 15),
                  // Баланс и валюта в одну строку
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: CustomerEdit(
                          controller: balanceController,
                          label: 'Баланс',
                          icon: Icons.attach_money,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d*[.,]?\d{0,2}')),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<int>(
                          initialValue: selectedCurrencyId,
                          isExpanded: true,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            labelText: "Валюта",
                          ),
                          items: currencies.map((c) => DropdownMenuItem(
                            value: c.idCurrencies,
                            child: Text(c.code),
                          )).toList(),
                          onChanged: (val) => setDialogState(() => selectedCurrencyId = val),
                          validator: (val) => val == null ? "!" : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  String text = balanceController.text.replaceAll(',', '.').trim();
                  double amount = text.isEmpty ? 0.0 : (double.tryParse(text) ?? 0.0);

                  final data = {
                    "name": nameController.text,
                    "type": selectedType,
                    "startBalance": amount,
                    "currencyId": selectedCurrencyId,
                  };

                  bool ok = existingWallet == null
                      ? await api.addWallet(data)
                      : await api.updateWallet(existingWallet['billId'], data);

                  if (ok) {
                    _refreshData();
                    if (context.mounted) Navigator.pop(context);
                  }
                }
              },
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator());
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: wallets.isEmpty
            ? const Center(child: Text("Счетов пока нет"))
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: wallets.length,
                itemBuilder: (context, index) {
                  final wallet = wallets[index];
                  final String name = wallet['name'] ?? 'Без названия';
                  final String balance = wallet['currentBalance']?.toString() ?? '0';
                  final double balanceValue = double.tryParse(balance) ?? 0.0;
                  final String code = wallet['currencyCode'] ?? '???';

                  // Поиск символа валюты в списке currencies по коду
                  final String symbol = currencies
                      .firstWhere(
                        (c) => c.code == code,
                        orElse: () => Currency(idCurrencies: 0, code: code, name: '', symbol: code),
                      )
                      .symbol;

                  final Color balanceColor = balanceValue == 0
                      ? colorScheme.onSurface
                      : (balanceValue > 0 ? Colors.green : Colors.red);

                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
                    ),
                    child: ListTile(
                      onTap: () async {
                        if (wallet['billId'] != null) {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TransactionsPage(
                                billId: wallet['billId'],
                                billName: name,
                                currencySymbol: symbol,
                              ),
                            ),
                          );
                          _refreshData();
                        }
                      },
                      leading: CircleAvatar(
                        backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                        child: Icon(Icons.account_balance_wallet, color: colorScheme.primary),
                      ),
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              RichText(
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: balance,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: balanceColor,
                                      ),
                                    ),
                                    TextSpan(
                                      text: " $symbol",
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: colorScheme.onSurfaceVariant,
                                        fontWeight: FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(code, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                            ],
                          ),
                          const SizedBox(width: 4),
                          PopupMenuButton<String>(
                            onSelected: (value) async {
                              if (value == 'edit') {
                                _openWalletForm(existingWallet: wallet);
                              } else if (value == 'delete') {
                                if (await _showDeleteConfirmDialog(name)) {
                                  if (await api.deleteWallet(wallet['billId'])) _refreshData();
                                }
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(value: 'edit', child: Text('Изменить')),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('Удалить', style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openWalletForm(),
        child: const Icon(Icons.add),
      ),
    );
  }
}