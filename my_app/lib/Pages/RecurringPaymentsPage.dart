import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:my_app/CustomerWidgets/CustomerEdit.dart'; // Наш виджет
import 'package:my_app/api/DioClient.dart';
import 'package:my_app/api/sources/remoteDataSource.dart';
import 'package:my_app/helpers/validators.dart'; // Валидаторы

class RecurringPaymentsPage extends StatefulWidget {
  const RecurringPaymentsPage({super.key});

  @override
  State<RecurringPaymentsPage> createState() => _RecurringPaymentsPageState();
}

class _RecurringPaymentsPageState extends State<RecurringPaymentsPage> {
  final UserRemoteDataSource api = UserRemoteDataSource(dio: Dioclient.instance);

  List<dynamic> payments = [];
  List<dynamic> wallets = [];
  List<dynamic> categories = [];
  bool isLoading = true;

  // Маппинг для Backend
  final Map<String, String> periodicityMap = {
    'Ежедневно': 'DAYLY',
    'Еженедельно': 'WEEKLY',
    'Ежемесячно': 'MONTHLY',
    'Ежегодно': 'YEARLY',
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
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
    final _formKey = GlobalKey<FormState>(); // Ключ формы
    
    final descController = TextEditingController(text: existing?['description'] ?? "");
    // Берем модуль числа, чтобы в поле ввода не было минуса
    final amountController = TextEditingController(
        text: existing != null ? (existing['amount'] as num).abs().toString() : "");
    final dateController = TextEditingController(
        text: existing?['nextPaymentDate'] ?? DateFormat('yyyy-MM-dd').format(DateTime.now()));

    int? selectedBillId = existing?['billId'];
    int? selectedCategoryId = existing?['categoryId'];

    // Определяем, доход это или расход (по знаку числа)
    bool isIncome = existing != null ? (existing['amount'] as num) > 0 : false;
    
    String selectedPeriodicityKey = 'Ежемесячно';
    if (existing != null) {
      final entry = periodicityMap.entries.firstWhere(
        (element) => element.value == existing['periodicity'],
        orElse: () => const MapEntry('Ежемесячно', 'MONTHLY'),
      );
      selectedPeriodicityKey = entry.key;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey, // Оборачиваем в Form
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(existing == null ? "Новый шаблон" : "Редактирование", 
                       style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),

                  // --- ПЕРЕКЛЮЧАТЕЛЬ ДОХОД / РАСХОД ---
                  ToggleButtons(
                    isSelected: [!isIncome, isIncome],
                    onPressed: (index) {
                      setModalState(() {
                        isIncome = index == 1;
                      });
                    },
                    borderRadius: BorderRadius.circular(10),
                    selectedColor: Colors.white,
                    fillColor: isIncome ? Colors.green : Colors.red,
                    constraints: BoxConstraints(
                      minWidth: (MediaQuery.of(context).size.width - 60) / 2,
                      minHeight: 40
                    ),
                    children: const [
                      Text("Расход"),
                      Text("Доход"),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Выбор счета
                  DropdownButtonFormField<int>(
                    value: selectedBillId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: "Счет", 
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.account_balance_wallet_outlined)
                    ),
                    validator: (val) => val == null ? "Выберите счет" : null,
                    items: wallets.map((w) {
                      final sym = w['currencySymbol'] ?? w['currencyCode'] ?? '';
                      return DropdownMenuItem<int>(
                        value: w['billId'], 
                        child: Text("${w['name']} ($sym)")
                      );
                    }).toList(),
                    onChanged: (val) => setModalState(() => selectedBillId = val),
                  ),
                  const SizedBox(height: 15),

                  // Выбор категории
                  DropdownButtonFormField<int>(
                    value: selectedCategoryId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: "Категория", 
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.category_outlined)
                    ),
                    validator: (val) => val == null ? "Выберите категорию" : null,
                    items: categories.map((c) => DropdownMenuItem<int>(
                      value: c['categoryId'], 
                      child: Text(c['name'])
                    )).toList(),
                    onChanged: (val) => setModalState(() => selectedCategoryId = val),
                  ),
                  const SizedBox(height: 15),

                  // Сумма (CustomerEdit)
                  CustomerEdit(
                    controller: amountController,
                    label: "Сумма",
                    maxLength: 12, // ОГРАНИЧЕНИЕ 12 СИМВОЛОВ
                    icon: isIncome ? Icons.add_circle_outline : Icons.remove_circle_outline,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*[.,]?\d{0,2}')),
                    ],
                    validator: AppValidators.amount, // Валидатор суммы
                  ),
                  
                  const SizedBox(height: 15),

                  // Периодичность
                  DropdownButtonFormField<String>(
                    value: selectedPeriodicityKey,
                    decoration: const InputDecoration(
                      labelText: "Как часто?", 
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.repeat)
                    ),
                    items: periodicityMap.keys.map((k) => DropdownMenuItem(value: k, child: Text(k))).toList(),
                    onChanged: (val) => setModalState(() => selectedPeriodicityKey = val!),
                  ),
                  const SizedBox(height: 15),

                  // Дата (CustomerEdit - ReadOnly)
                  CustomerEdit(
                    controller: dateController,
                    label: "Дата след. операции",
                    icon: Icons.calendar_today,
                    readOnly: true, // Запрещаем ручной ввод
                    validator: AppValidators.required,
                    onTap: () async {
                      DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        dateController.text = DateFormat('yyyy-MM-dd').format(picked);
                      }
                    },
                  ),
                  
                  const SizedBox(height: 15),
                  
                  // Описание (CustomerEdit)
                  CustomerEdit(
                    controller: descController,
                    label: "Описание (необязательно)",
                    icon: Icons.description_outlined,
                    textCapitalization: TextCapitalization.sentences,
                    maxLength: 100,
                  ),
                  
                  const SizedBox(height: 20),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      // Проверка валидации формы
                      if (_formKey.currentState!.validate()) {
                        
                        double val = double.tryParse(amountController.text.replaceFirst(',', '.')) ?? 0;
                        
                        // ЕСЛИ ДОХОД -> отправляем +, ЕСЛИ РАСХОД -> отправляем -
                        double finalAmount = isIncome ? val : -val;

                        final data = {
                          "billId": selectedBillId,
                          "categoryId": selectedCategoryId,
                          "description": descController.text,
                          "amount": finalAmount, 
                          "periodicity": periodicityMap[selectedPeriodicityKey],
                          "nextPaymentDate": dateController.text,
                        };

                        bool ok = existing == null 
                            ? await api.addRecurringPayment(data)
                            : await api.updateRecurringPayment(existing['idPayment'], data);

                        if (ok && mounted) {
                          Navigator.pop(context);
                          _loadData();
                        }
                      }
                    },
                    child: const Text("Сохранить", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      body: payments.isEmpty
          ? const Center(child: Text("Нет запланированных операций"))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: payments.length,
              itemBuilder: (context, index) {
                final p = payments[index];
                
                // Данные о сумме
                final double amount = (p['amount'] as num).toDouble();
                final bool isIncome = amount > 0;

                // Находим кошелек и символ
                final wallet = wallets.firstWhere(
                  (w) => w['billId'] == p['billId'], 
                  orElse: () => <String, dynamic>{}
                );
                final symbol = wallet['currencySymbol'] ?? wallet['currencyCode'] ?? '';

                // Периодичность на русском
                final periodicityRu = periodicityMap.entries
                    .firstWhere((e) => e.value == p['periodicity'], 
                        orElse: () => const MapEntry("?", "?"))
                    .key;

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: CircleAvatar(
                      // ИЗМЕНЕНО: Фон теперь Красный (для расхода) или Зеленый (для дохода)
                      backgroundColor: isIncome ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                      child: Icon(
                        isIncome ? Icons.arrow_downward : Icons.arrow_upward, 
                        // ИЗМЕНЕНО: Иконка теперь Красная или Зеленая
                        color: isIncome ? Colors.green : Colors.red
                      ),
                    ),
                    title: Text(p['description']?.isNotEmpty == true ? p['description'] : p['categoryName']),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("${p['categoryName']} • ${p['billName']}"),
                        Text("След. дата: ${p['nextPaymentDate']}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              "${isIncome ? '+' : ''}$amount $symbol", 
                              style: TextStyle(
                                fontWeight: FontWeight.bold, 
                                fontSize: 16,
                                // ИЗМЕНЕНО: Если доход - Зеленый, если расход - Красный
                                color: isIncome ? Colors.green : Colors.red 
                              )
                            ),
                            Text(periodicityRu, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                        PopupMenuButton<String>(
                          onSelected: (val) async {
                            if (val == 'edit') _openPaymentForm(existing: p);
                            if (val == 'delete') {
                              if (await api.deleteRecurringPayment(p['idPayment'])) {
                                _loadData();
                              }
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'edit', child: Text("Изменить")),
                            const PopupMenuItem(value: 'delete', child: Text("Удалить", style: TextStyle(color: Colors.red))),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openPaymentForm(),
        backgroundColor: Colors.deepPurple,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}