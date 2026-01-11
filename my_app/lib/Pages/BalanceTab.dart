import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_app/CustomerWidgets/CustomerEdit.dart'; // Путь к виджету
import 'package:my_app/Pages/TransactionsPage.dart';
import 'package:my_app/api/DioClient.dart';
import 'package:my_app/api/data/сurrency.dart';
import 'package:my_app/api/sources/remoteDataSource.dart';
import 'package:my_app/helpers/validators.dart'; // Путь к валидаторам

class BalanceTab extends StatefulWidget {
  const BalanceTab({super.key});

  @override
  State<BalanceTab> createState() => _BalanceTabState();
}

class _BalanceTabState extends State<BalanceTab> {
  final UserRemoteDataSource api = UserRemoteDataSource(dio: Dioclient.instance);
  
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
    ) ?? false;
  }

  void _openWalletForm({Map<String, dynamic>? existingWallet}) {
    final _formKey = GlobalKey<FormState>(); // Ключ формы для валидации
    final nameController = TextEditingController(text: existingWallet?['name']);
    final balanceController = TextEditingController(text: existingWallet?['currentBalance']?.toString());
    
    String selectedType = existingWallet?['type'] ?? 'Debit';
    int? selectedCurrencyId; // Важно: тут нужно логику восстановления ID, если редактируем, но пока оставим как в оригинале

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text(existingWallet == null ? 'Новый счет' : 'Изменить счет'),
          content: SingleChildScrollView(
            child: Form(
              key: _formKey, // Обернули в Form
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CustomerEdit(
                    controller: nameController,
                    label: 'Название',
                    icon: Icons.account_balance_wallet,
                    validator: AppValidators.required, // Валидатор на пустоту
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 15),
                  CustomerEdit(
                    controller: balanceController,
                    label: 'Начальный баланс',
                    icon: Icons.attach_money,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    maxLength: 12,
                    // Разрешаем только цифры и точку
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*[.,]?\d{0,2}')),
                    ],
                    validator: AppValidators.amount, // Валидатор суммы
                  ),
                  const SizedBox(height: 15),
                  DropdownButtonFormField<int>(
                    hint: const Text("Выберите валюту"),
                    value: selectedCurrencyId,
                    isExpanded: true,
                    // Добавляем стиль как у CustomerEdit для единообразия
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.currency_exchange),
                      labelText: "Валюта"
                    ),
                    items: currencies.map((c) => DropdownMenuItem(
                      value: c.idCurrencies, 
                      child: Text("${c.code} (${c.symbol})")
                    )).toList(),
                    onChanged: (val) => setDialogState(() => selectedCurrencyId = val),
                    validator: (val) => val == null ? "Выберите валюту" : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
            ElevatedButton(
              onPressed: () async {
                // Запускаем валидацию всех полей (включая Dropdown и CustomerEdit)
                if (_formKey.currentState!.validate()) {
                  final data = {
                    "name": nameController.text,
                    "type": selectedType,
                    "startBalance": double.tryParse(balanceController.text.replaceAll(',', '.')) ?? 0.0,
                    "currencyId": selectedCurrencyId,
                  };

                  bool ok;
                  if (existingWallet == null) {
                    ok = await api.addWallet(data);
                  } else {
                    ok = await api.updateWallet(existingWallet['billId'], data);
                  }

                  if (ok) {
                    Navigator.pop(context);
                    _refreshData();
                  }
                }
              }, 
              child: const Text('Сохранить')
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator());

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
                
                // 1. Получаем числовое значение баланса для проверки
                // Если придет null, считаем за 0.0
                final double balanceValue = double.tryParse(wallet['currentBalance']?.toString() ?? '0') ?? 0.0;
                
                final String balance = wallet['currentBalance']?.toString() ?? '0';
                final String code = wallet['currencyCode'] ?? '';
                final String symbol = wallet['currencySymbol'] ?? code; 
                final int? billId = wallet['billId'];

                // 2. Определяем цвет: Если >= 0 то зеленый, иначе красный
                final Color balanceColor = balanceValue >= 0 ? Colors.green : Colors.red;

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    onTap: () async {
                      if (billId != null) {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TransactionsPage(
                              billId: billId,
                              billName: name,
                              currencySymbol: symbol, 
                            ),
                          ),
                        );
                        _refreshData();
                      }
                    },
                    leading: CircleAvatar(
                      backgroundColor: Colors.deepPurple.withOpacity(0.1),
                      child: const Icon(Icons.account_balance_wallet, color: Colors.deepPurple),
                    ),
                    title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("Валюта: $code"), 
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          balance, 
                          style: TextStyle( // Убрали const, так как цвет динамический
                            fontSize: 18, 
                            fontWeight: FontWeight.bold, 
                            color: balanceColor // 3. Подставляем цвет сюда
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(symbol, style: const TextStyle(color: Colors.grey, fontSize: 16)),
                         
                        PopupMenuButton<String>(
                          onSelected: (value) async {
                            if (value == 'edit') {
                              _openWalletForm(existingWallet: wallet);
                            } else if (value == 'delete') {
                              bool confirmed = await _showDeleteConfirmDialog(name);
                              if (confirmed) {
                                if (await api.deleteWallet(wallet['billId'])) {
                                  _refreshData();
                                }
                              }
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'edit', child: Text('Изменить')),
                            const PopupMenuItem(
                              value: 'delete', 
                              child: Text('Удалить', style: TextStyle(color: Colors.red))
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