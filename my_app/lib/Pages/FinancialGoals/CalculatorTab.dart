import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:my_app/CustomerWidgets/CustomerEdit.dart';
import 'package:my_app/api/DioClient.dart';
import 'package:my_app/api/sources/remoteDataSource.dart';
import 'package:my_app/helpers/validators.dart';

class CalculatorTab extends StatefulWidget {
  final VoidCallback onGoalCreated;
  const CalculatorTab({super.key, required this.onGoalCreated});

  @override
  State<CalculatorTab> createState() => _CalculatorTabState();
}

class _CalculatorTabState extends State<CalculatorTab> {
  final UserRemoteDataSource api = UserRemoteDataSource(dio: Dioclient.instance);
  final _formKey = GlobalKey<FormState>();

  int calculationType = 0;
  final _amountController = TextEditingController();
  final _paramController = TextEditingController();

  double? _calculatedTargetAmount;
  String? _calculatedTargetDate;
  String? _resultMessage;

  bool isLoading = false;
  
  // Храним список счетов
  List<Map<String, dynamic>> bills = [];

  @override
  void initState() {
    super.initState();
    _loadBills();
  }

  Future<void> _loadBills() async {
    try {
      final list = await api.getWallets();
      if (mounted) setState(() => bills = list);
    } catch (e) {
      debugPrint("Ошибка загрузки счетов: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text("Накопление"), icon: Icon(Icons.savings_outlined)),
                ButtonSegment(value: 1, label: Text("Планирование"), icon: Icon(Icons.calendar_month_outlined)),
              ],
              selected: {calculationType},
              onSelectionChanged: (Set<int> newSelection) {
                setState(() {
                  calculationType = newSelection.first;
                  _amountController.clear();
                  _paramController.clear();
                  _resultMessage = null;
                  _calculatedTargetAmount = null;
                  _calculatedTargetDate = null;
                });
              },
              style: ButtonStyle(
                backgroundColor: MaterialStateProperty.resolveWith<Color>((states) {
                  if (states.contains(MaterialState.selected)) return colors.secondaryContainer;
                  return Colors.transparent;
                }),
                foregroundColor: MaterialStateProperty.resolveWith<Color>((states) {
                  if (states.contains(MaterialState.selected)) return colors.onSecondaryContainer;
                  return colors.onSurface;
                }),
              ),
            ),
            const SizedBox(height: 20),

            Text(
              calculationType == 0
                  ? "Сколько я накоплю, если буду откладывать..."
                  : "Хочу накопить сумму к определенной дате...",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),

            CustomerEdit(
              controller: _amountController,
              label: calculationType == 0 ? "Сумма в месяц" : "Желаемая сумма (Цель)",
              icon: Icons.attach_money,
              maxLength: 12,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*[.,]?\d{0,2}'))],
              validator: AppValidators.amount,
            ),

            const SizedBox(height: 15),

            if (calculationType == 0)
              CustomerEdit(
                controller: _paramController,
                label: "Количество месяцев",
                icon: Icons.access_time,
                maxLength: 3,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: AppValidators.required,
              )
            else
              CustomerEdit(
                controller: _paramController,
                label: "К какой дате?",
                icon: Icons.event,
                readOnly: true,
                validator: AppValidators.required,
                onTap: () async {
                  DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 30)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    _paramController.text = DateFormat('yyyy-MM-dd').format(picked);
                  }
                },
              ),

            const SizedBox(height: 25),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: isLoading ? null : _calculate,
              child: isLoading
                  ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: colors.onPrimary, strokeWidth: 2))
                  : const Text("Рассчитать", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),

            if (_resultMessage != null) ...[
              const SizedBox(height: 30),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.withOpacity(0.5)),
                ),
                child: Column(
                  children: [
                    const Text("Результат расчета:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                    const SizedBox(height: 10),
                    Text(_resultMessage!,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colors.onSurface),
                        textAlign: TextAlign.center
                    ),
                    const SizedBox(height: 15),

                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _showCreateGoalDialog(),
                      icon: const Icon(Icons.flag),
                      label: const Text("Сохранить как цель"),
                    )
                  ],
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Future<void> _calculate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);
    final double inputAmount = double.tryParse(_amountController.text.replaceFirst(',', '.')) ?? 0;

    try {
      if (calculationType == 0) {
        int months = int.tryParse(_paramController.text) ?? 0;
        final res = await api.calculateAccumulation(inputAmount, months);
        if (res != null) {
          setState(() {
            _calculatedTargetAmount = (res['finalAccumulationAmount'] as num).toDouble();
            _calculatedTargetDate = res['finalDate'];
            _resultMessage = "Вы накопите: ${_calculatedTargetAmount!.toStringAsFixed(2)}\nДата: $_calculatedTargetDate";
          });
        }
      } else {
        String date = _paramController.text;
        final res = await api.calculateDeposit(inputAmount, date);
        if (res != null) {
          setState(() {
            _calculatedTargetAmount = inputAmount;
            _calculatedTargetDate = date;
            final monthly = res['requiredMonthlyDeposit'];
            _resultMessage = "Откладывайте в месяц: $monthly\nЧтобы накопить: $inputAmount";
          });
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ошибка расчета")));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showCreateGoalDialog() {
    final _dialogFormKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final amountCtrl = TextEditingController(text: _calculatedTargetAmount?.toStringAsFixed(2) ?? "");
    final dateCtrl = TextEditingController(text: _calculatedTargetDate ?? "");
    
    // ИСПРАВЛЕНИЕ: Используем 'billId', а не 'id'
    int? selectedBillId;
    if (bills.isNotEmpty) {
      selectedBillId = bills.first['billId'];
    }
    
    final colors = Theme.of(context).colorScheme;
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text("Сохранить цель"),
            content: SingleChildScrollView(
              child: Form(
                key: _dialogFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("Данные перенесены из калькулятора", style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant)),
                    const SizedBox(height: 15),
                    
                    CustomerEdit(
                      controller: nameCtrl, 
                      label: "Название цели",
                      icon: Icons.title,
                      textCapitalization: TextCapitalization.sentences,
                      validator: AppValidators.required,
                    ),
                    const SizedBox(height: 15),
                    
                    CustomerEdit(
                      controller: amountCtrl, 
                      label: "Целевая сумма",
                      icon: Icons.attach_money,
                      maxLength: 12,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*[.,]?\d{0,2}'))],
                      validator: AppValidators.amount,
                    ),
                    const SizedBox(height: 15),

                    // Dropdown
                    if (bills.isNotEmpty)
                      DropdownButtonFormField<int>(
                        value: selectedBillId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: "Привязать к счету",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.account_balance_wallet),
                        ),
                        items: bills.map((b) {
                          // ИСПРАВЛЕНИЕ: Берем правильные поля из логов
                          final id = b['billId'];
                          final name = b['name'];
                          final currencyCode = b['currencyCode'] ?? ""; 

                          return DropdownMenuItem<int>(
                            value: id,
                            child: Text("$name ($currencyCode)", overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: isSubmitting ? null : (int? newValue) {
                          setDialogState(() => selectedBillId = newValue);
                        },
                      )
                    else
                      const Text("Нет доступных счетов. Создайте кошелек!", style: TextStyle(color: Colors.red)),

                    const SizedBox(height: 15),
                    
                    CustomerEdit(
                      controller: dateCtrl,
                      label: "Дата окончания",
                      icon: Icons.calendar_today,
                      readOnly: true,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(ctx), 
                child: const Text("Отмена")
              ),
              ElevatedButton(
                onPressed: isSubmitting ? null : () async {
                  if (_dialogFormKey.currentState!.validate()) {
                    if (selectedBillId == null) {
                       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Выберите счет")));
                       return;
                    }

                    setDialogState(() => isSubmitting = true);

                    final data = {
                      "name": nameCtrl.text,
                      "targetAmount": double.tryParse(amountCtrl.text.replaceFirst(',', '.')) ?? 0,
                      "currentAmount": 0,
                      "targetDate": dateCtrl.text,
                      "billId": selectedBillId // Правильное поле
                    };

                    try {
                      bool ok = await api.addGoal(data);
                      
                      if (ok && mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Цель успешно создана!")));
                        widget.onGoalCreated();
                        setState(() {
                          _resultMessage = null;
                          _amountController.clear();
                          _paramController.clear();
                        });
                      } else {
                        if (mounted) {
                           setDialogState(() => isSubmitting = false);
                           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ошибка сохранения (попробуйте позже)")));
                        }
                      }
                    } catch (e) {
                      if (mounted) {
                         setDialogState(() => isSubmitting = false);
                         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Ошибка сети: $e")));
                      }
                    }
                  }
                },
                child: isSubmitting 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text("Создать"),
              )
            ],
          );
        }
      ),
    );
  }
}