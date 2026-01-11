import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:my_app/CustomerWidgets/CustomerEdit.dart';
import 'package:my_app/api/DioClient.dart';
import 'package:my_app/api/sources/remoteDataSource.dart';
import 'package:my_app/helpers/validators.dart';

class GoalsListTab extends StatefulWidget {
  const GoalsListTab({super.key});

  @override
  State<GoalsListTab> createState() => GoalsListTabState();
}

class GoalsListTabState extends State<GoalsListTab> {
  final UserRemoteDataSource api = UserRemoteDataSource(dio: Dioclient.instance);
  List<dynamic> goals = [];
  List<dynamic> bills = []; 
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    try {
      final results = await Future.wait([
        api.getGoals(),
        api.getWallets() 
      ]);
      
      if (mounted) {
        setState(() {
          goals = results[0] as List<dynamic>;
          bills = results[1] as List<dynamic>;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Ошибка загрузки данных: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> loadGoals() => _loadData();

  // Надежный поиск счета через цикл
  Map<String, dynamic>? _findBill(dynamic goalBillId) {
    if (goalBillId == null || bills.isEmpty) return null;
    
    final String searchId = goalBillId.toString().replaceAll('.0', '').trim();

    for (var bill in bills) {
      final rawBillId = bill['billId'] ?? bill['id'];
      
      if (rawBillId != null) {
        String billIdStr = rawBillId.toString().replaceAll('.0', '').trim();
        if (billIdStr == searchId) {
          return bill;
        }
      }
    }
    return null;
  }

  String _getCurrency(Map<String, dynamic>? bill) {
    if (bill == null) return '';
    return bill['currencyCode'] ?? bill['currency']?.toString() ?? '';
  }

  double _getBalance(Map<String, dynamic>? bill) {
    if (bill == null) return 0.0;
    return (bill['currentBalance'] ?? bill['balance'] ?? 0).toDouble();
  }

  // --- ДИАЛОГ ПОПОЛНЕНИЯ ---
  void _showDepositDialog(Map<String, dynamic> goal) {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>(); 
    
    final linkedBill = _findBill(goal['billId']);

    String billName = "Неизвестный счет";
    String currencySymbol = "";
    double walletBalance = 0.0; 

    if (linkedBill != null) {
      billName = linkedBill['name'] ?? "Кошелек";
      walletBalance = _getBalance(linkedBill);
      currencySymbol = _getCurrency(linkedBill);
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Пополнить '${goal['name']}'"),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Списание с '$billName'", 
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color.fromARGB(255, 255, 153, 0)),
              ),
              if (linkedBill != null)
                Text(
                  "Баланс: $walletBalance $currencySymbol",
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                )
              else 
                const Text(
                  "Счет не найден или удален",
                  style: TextStyle(fontSize: 12, color: Colors.red),
                ),
              const SizedBox(height: 15),
              CustomerEdit(
                controller: controller,
                label: "Сумма ($currencySymbol)",
                icon: Icons.add_circle_outline,
                maxLength: 12,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*[.,]?\d{0,2}'))],
                validator: (val) {
                  String? standardError = AppValidators.amount(val);
                  if (standardError != null) return standardError;

                  if (val != null && linkedBill != null) {
                    double? amount = double.tryParse(val.replaceAll(',', '.'));
                    if (amount != null && amount > walletBalance) {
                      return "Недостаточно средств ($walletBalance)";
                    }
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), 
            child: const Text("Отмена")
          ),
          ElevatedButton(
            onPressed: linkedBill == null ? null : () async { 
              if (formKey.currentState!.validate()) {
                String text = controller.text.replaceAll(',', '.');
                double? addAmount = double.tryParse(text);
                if (addAmount == null || addAmount <= 0) return;

                double current = (goal['currentAmount'] ?? 0).toDouble();
                double newAmount = current + addAmount;

                String dateStr = goal['targetDate'].toString();
                if (dateStr.contains("T")) dateStr = dateStr.split("T")[0];

                final Map<String, dynamic> updateData = {
                  "name": goal['name'],
                  "targetAmount": goal['targetAmount'],
                  "targetDate": dateStr,
                  "currentAmount": newAmount, 
                  "billId": goal['billId'] 
                };

                try {
                  bool ok = await api.updateGoal(goal['id'], updateData);
                  if (ok && mounted) {
                      Navigator.pop(ctx);
                      _loadData(); 
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Внесено: $addAmount"))
                      );
                  }
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ошибка обновления")));
                }
              }
            },
            child: const Text("Внести"),
          )
        ],
      ),
    );
  }

  // --- ДИАЛОГ РЕДАКТИРОВАНИЯ ---
  void _showEditDialog(Map<String, dynamic> goal) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: goal['name']);
    final targetCtrl = TextEditingController(text: goal['targetAmount'].toString());
    final dateCtrl = TextEditingController(text: goal['targetDate']);
    
    dynamic currentBillVal;
    
    final existingBill = _findBill(goal['billId']);
    
    if (existingBill != null) {
      currentBillVal = existingBill['billId'] ?? existingBill['id'];
    } else if (bills.isNotEmpty) {
      currentBillVal = bills.first['billId'] ?? bills.first['id'];
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Изменить параметры"),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CustomerEdit(
                    controller: nameCtrl, 
                    label: "Название", 
                    icon: Icons.title,
                    validator: AppValidators.required
                  ),
                  const SizedBox(height: 15),
                  
                  CustomerEdit(
                    controller: targetCtrl, 
                    label: "Цель (Сумма)",
                    icon: Icons.flag,
                    maxLength: 12,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*[.,]?\d{0,2}'))],
                    validator: AppValidators.amount,
                  ),
                  const SizedBox(height: 15),
                  
                  DropdownButtonFormField<dynamic>(
                    value: currentBillVal, 
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: "Привязанный счет",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.account_balance_wallet)
                    ),
                    items: bills.map((b) {
                        final val = b['billId'] ?? b['id'];
                        if (val == null) return null;

                        String cur = _getCurrency(b);
                        
                        return DropdownMenuItem<dynamic>(
                          value: val, 
                          child: Text("${b['name']} ($cur)", overflow: TextOverflow.ellipsis)
                        );
                    }).whereType<DropdownMenuItem<dynamic>>().toList(),
                    onChanged: (val) {
                      setDialogState(() => currentBillVal = val);
                    },
                    validator: (val) => val == null ? "Выберите счет" : null,
                  ),
                  const SizedBox(height: 15),
                  
                  CustomerEdit(
                    controller: dateCtrl,
                    label: "Дата",
                    icon: Icons.calendar_today,
                    readOnly: true,
                    onTap: () async {
                      DateTime? picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime(2100));
                      if(picked != null) dateCtrl.text = DateFormat('yyyy-MM-dd').format(picked);
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Отмена")),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate() && currentBillVal != null) {
                   
                   String dateStr = dateCtrl.text;
                   if (dateStr.contains("T")) dateStr = dateStr.split("T")[0];

                   final data = {
                    "name": nameCtrl.text,
                    "targetAmount": double.tryParse(targetCtrl.text.replaceAll(',', '.')) ?? 0,
                    "targetDate": dateStr,
                    "billId": currentBillVal 
                  };
                  
                  bool success = await api.updateGoal(goal['id'], data);
                  
                  if (success && mounted) {
                    Navigator.pop(ctx);
                    _loadData();
                  }
                }
              },
              child: const Text("Сохранить"),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    if (isLoading) return const Center(child: CircularProgressIndicator());
    
    return Scaffold(
      body: goals.isEmpty 
        ? Center(child: Text("Нет целей", style: TextStyle(color: colors.onSurfaceVariant)))
        : RefreshIndicator(
            onRefresh: _loadData,
            child: ListView.builder(
              itemCount: goals.length,
              padding: const EdgeInsets.all(15),
              itemBuilder: (context, index) {
                final goal = goals[index];
                
                final double target = (goal['targetAmount'] as num).toDouble();
                final double current = (goal['currentAmount'] ?? 0).toDouble();
                
                final linkedBill = _findBill(goal['billId']);

                String symbol = goal['currencyCode'] ?? '';
                String walletName = "Счет не найден"; 
                
                if (linkedBill != null) {
                   walletName = linkedBill['name'] ?? "Без названия";
                   if (symbol.isEmpty) symbol = _getCurrency(linkedBill);
                }

                double progress = target == 0 ? 0 : (current / target);
                if (progress > 1.0) progress = 1.0;
                int percent = (progress * 100).toInt();

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: Padding(
                    padding: const EdgeInsets.all(15.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: Text(goal['name'] ?? "Цель", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                            PopupMenuButton<String>(
                              onSelected: (val) async {
                                if (val == 'edit') _showEditDialog(goal);
                                if (val == 'delete') {
                                  if (await api.deleteGoal(goal['id'])) _loadData();
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(value: 'edit', child: Text("Изменить")),
                                const PopupMenuItem(value: 'delete', child: Text("Удалить", style: TextStyle(color: Colors.red))),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Накоплено: $current $symbol", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                            Text("Цель: $target $symbol", style: TextStyle(color: colors.onSurfaceVariant)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: LinearProgressIndicator(
                                      value: progress,
                                      minHeight: 10,
                                      backgroundColor: colors.surfaceContainerHighest, 
                                      valueColor: AlwaysStoppedAnimation<Color>(percent >= 100 ? Colors.green : colors.primary),
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    percent >= 100 ? "Цель достигнута! 🎉" : "Осталось: ${(target - current).toStringAsFixed(2)} $symbol", 
                                    style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant)
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            if (percent < 100)
                              IconButton.filled(
                                onPressed: () => _showDepositDialog(goal),
                                icon: const Icon(Icons.add),
                                tooltip: "Внести",
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.green, 
                                  foregroundColor: Colors.white
                                ),
                              )
                            else
                              const Icon(Icons.check_circle, color: Colors.green, size: 30)
                          ],
                        ),
                        
                        const SizedBox(height: 10),
                        const Divider(height: 1, thickness: 0.5),
                        const SizedBox(height: 8),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Icon(Icons.account_balance_wallet, size: 14, color: linkedBill != null ? colors.onSurfaceVariant : Colors.red),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    // ЗДЕСЬ ИЗМЕНЕНИЕ: УБРАЛ ID
                                    child: Text(
                                      walletName, 
                                      style: TextStyle(
                                        fontSize: 11, 
                                        color: linkedBill != null ? colors.onSurfaceVariant : Colors.red,
                                        fontWeight: FontWeight.w500
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                Icon(Icons.calendar_month, size: 14, color: colors.onSurfaceVariant),
                                const SizedBox(width: 4),
                                Text(
                                  "${goal['targetDate']}".split('T')[0], 
                                  style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant)
                                ),
                              ],
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
    );
  }
}