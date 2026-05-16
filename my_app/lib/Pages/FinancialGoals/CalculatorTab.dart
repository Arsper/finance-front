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
  final UserRemoteDataSource api = UserRemoteDataSource(
    dio: Dioclient.instance,
  );
  final _formKey = GlobalKey<FormState>();

  int calculationType = 0;
  final _amountController = TextEditingController();
  final _paramController = TextEditingController();

  double? _calculatedTargetAmount;
  String? _calculatedTargetDate;
  String? _resultMessage;

  String _resMainValue = '';
  String _resSubText = '';

  bool isLoading = false;
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

  void _showCalculationTypeSelector(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 5),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  "Выберите режим расчета",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                leading: Icon(
                  Icons.savings_outlined,
                  color: calculationType == 0
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                title: const Text("Накопление"),
                subtitle: const Text(
                  "Узнать итоговую сумму при регулярных депозитах",
                ),
                trailing: calculationType == 0
                    ? Icon(Icons.check_circle, color: colorScheme.primary)
                    : null,
                onTap: () {
                  _changeCalculationType(0);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.calendar_month_outlined,
                  color: calculationType == 1
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                title: const Text("Планирование"),
                subtitle: const Text(
                  "Рассчитать ежемесячный платеж под конкретную дату",
                ),
                trailing: calculationType == 1
                    ? Icon(Icons.check_circle, color: colorScheme.primary)
                    : null,
                onTap: () {
                  _changeCalculationType(1);
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _changeCalculationType(int type) {
    if (calculationType == type) return;
    setState(() {
      calculationType = type;
      _amountController.clear();
      _paramController.clear();
      _resultMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildPremiumCard(
              context,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Параметры расчета",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 16),

                  InkWell(
                    onTap: () => _showCalculationTypeSelector(context),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.15)
                            : Colors.grey[50],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? colorScheme.outline
                              : colorScheme.outlineVariant.withValues(
                                  alpha: 0.5,
                                ),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            calculationType == 0
                                ? Icons.savings_outlined
                                : Icons.calendar_month_outlined,
                            size: 20,
                            color: isDark
                                ? colorScheme.onSurface
                                : colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Режим расчета",
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: colorScheme.onSurfaceVariant
                                        .withValues(alpha: 0.8),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  calculationType == 0
                                      ? "Накопление"
                                      : "Планирование",
                                  style: TextStyle(
                                    color: colorScheme.onSurface,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.expand_more_rounded,
                            color: isDark
                                ? colorScheme.onSurface
                                : colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  CustomerEdit(
                    controller: _amountController,
                    label: calculationType == 0
                        ? "Сколько откладывать в месяц"
                        : "Желаемая сумма цели",
                    icon: Icons.payments_outlined,
                    maxLength: 12,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*[.,]?\d{0,2}'),
                      ),
                    ],
                    validator: AppValidators.amount,
                  ),
                  const SizedBox(height: 16),
                  if (calculationType == 0)
                    CustomerEdit(
                      controller: _paramController,
                      label: "Период накопления (месяцев)",
                      icon: Icons.timelapse_rounded,
                      maxLength: 3,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: AppValidators.required,
                    )
                  else
                    CustomerEdit(
                      controller: _paramController,
                      label: "Целевая дата",
                      icon: Icons.event_repeat_rounded,
                      readOnly: true,
                      validator: AppValidators.required,
                      onTap: () async {
                        DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now().add(
                            const Duration(days: 30),
                          ),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          _paramController.text = DateFormat(
                            'yyyy-MM-dd',
                          ).format(picked);
                        }
                      },
                    ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        shadowColor: colorScheme.primary.withValues(alpha: 0.3),
                      ),
                      onPressed: isLoading ? null : _calculate,
                      child: isLoading
                          ? SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: colorScheme.onPrimary,
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Text(
                              "Рассчитать",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.2,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),

            if (_resultMessage != null) ...[
              const SizedBox(height: 16),
              _buildPremiumCard(
                context,
                isAccent: true,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.auto_graph_rounded,
                                color: Colors.green,
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              "Анализ расчета",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          calculationType == 0
                              ? "Итог накоплений"
                              : "План в месяц",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(height: 1, color: Colors.grey),
                    ),
                    Text(
                      _resMainValue,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: colorScheme.onSurface,
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _resSubText,
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.8,
                        ),
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    InkWell(
                      onTap: () => _showCreateGoalBottomSheet(context),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: colorScheme.primary.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_task_rounded,
                              size: 18,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "Создать финансовую цель",
                              style: TextStyle(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumCard(
    BuildContext context, {
    required Widget child,
    bool isAccent = false,
  }) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? colors.surfaceContainerLow : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: isAccent
              ? Colors.green.withValues(alpha: 0.3)
              : colors.outlineVariant.withValues(alpha: isDark ? 0.15 : 0.4),
          width: 1,
        ),
      ),
      child: child,
    );
  }

  Future<void> _calculate() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => isLoading = true);
    final double inputAmount =
        double.tryParse(_amountController.text.replaceFirst(',', '.')) ?? 0;

    try {
      if (calculationType == 0) {
        int months = int.tryParse(_paramController.text) ?? 0;
        final res = await api.calculateAccumulation(inputAmount, months);
        if (res != null) {
          setState(() {
            _calculatedTargetAmount = (res['finalAccumulationAmount'] as num)
                .toDouble();
            _calculatedTargetDate = res['finalDate'];

            _resMainValue = "${_calculatedTargetAmount!.toStringAsFixed(2)} ₽";
            _resSubText =
                "Будет накоплено к вашей финальной дате: $_calculatedTargetDate";
            _resultMessage = _resMainValue;
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

            _resMainValue = "$monthly ₽ / мес.";
            _resSubText =
                "Необходимо откладывать регулярно, чтобы собрать цель $inputAmount ₽";
            _resultMessage = _resMainValue;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Ошибка расчета")));
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showWalletSelector(
    BuildContext context,
    int? currentSelectedId,
    Function(int) onSelected,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 5),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  "Выберите счет накоплений",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              if (bills.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    "Нет доступных счетов",
                    style: TextStyle(color: Colors.red),
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: bills.length,
                    itemBuilder: (context, index) {
                      final wallet = bills[index];
                      final isSelected = wallet['billId'] == currentSelectedId;
                      return ListTile(
                        leading: Icon(
                          Icons.account_balance_wallet_outlined,
                          color: isSelected
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
                        ),
                        title: Text(
                          wallet['name'],
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(
                                Icons.check_circle,
                                color: colorScheme.primary,
                              )
                            : null,
                        onTap: () {
                          onSelected(wallet['billId']);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showCreateGoalBottomSheet(BuildContext parentContext) {
    final dialogFormKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final amountCtrl = TextEditingController(
      text: _calculatedTargetAmount?.toStringAsFixed(2) ?? "",
    );
    final dateCtrl = TextEditingController(text: _calculatedTargetDate ?? "");

    int? selectedBillId = bills.isNotEmpty ? bills.first['billId'] : null;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: parentContext,
      isScrollControlled: true,
      backgroundColor: Theme.of(parentContext).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final colorScheme = Theme.of(context).colorScheme;
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final currentWalletName = bills.firstWhere(
            (b) => b['billId'] == selectedBillId,
            orElse: () => {"name": "Не выбрано"},
          )['name'];

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              left: 20,
              right: 20,
              top: 12,
            ),
            child: Form(
              key: dialogFormKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.2,
                        ),
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Новая цель",
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                      color: colorScheme.onSurface,
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  CustomerEdit(
                    controller: nameCtrl,
                    label: "Название вашей цели",
                    icon: Icons.assignment_outlined,
                    textCapitalization: TextCapitalization.sentences,
                    validator: AppValidators.required,
                  ),
                  const SizedBox(height: 16),
                  CustomerEdit(
                    controller: amountCtrl,
                    label: "Целевая сумма",
                    icon: Icons.payments_outlined,
                    maxLength: 12,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*[.,]?\d{0,2}'),
                      ),
                    ],
                    validator: AppValidators.amount,
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: isSubmitting
                        ? null
                        : () => _showWalletSelector(context, selectedBillId, (
                            id,
                          ) {
                            setDialogState(() => selectedBillId = id);
                          }),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.15)
                            : Colors.grey[50],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? colorScheme.outline
                              : colorScheme.outlineVariant.withValues(
                                  alpha: 0.5,
                                ),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.account_balance_wallet_outlined,
                            size: 20,
                            color: isDark
                                ? colorScheme.onSurface
                                : colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Накопительный счет",
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: colorScheme.onSurfaceVariant
                                        .withValues(alpha: 0.8),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  currentWalletName,
                                  style: TextStyle(
                                    color: colorScheme.onSurface,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.expand_more_rounded,
                            color: isDark
                                ? colorScheme.onSurface
                                : colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  CustomerEdit(
                    controller: dateCtrl,
                    label: "Прогнозируемая дата завершения",
                    icon: Icons.calendar_today_outlined,
                    readOnly: true,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: isSubmitting
                              ? null
                              : () => Navigator.pop(ctx),
                          child: const Text(
                            "Отмена",
                            style: TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            foregroundColor: colorScheme.onPrimary,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  if (dialogFormKey.currentState!.validate()) {
                                    if (selectedBillId == null) return;
                                    setDialogState(() => isSubmitting = true);

                                    final data = {
                                      "name": nameCtrl.text,
                                      "targetAmount":
                                          double.tryParse(
                                            amountCtrl.text.replaceFirst(
                                              ',',
                                              '.',
                                            ),
                                          ) ??
                                          0,
                                      "currentAmount": 0,
                                      "targetDate": dateCtrl.text,
                                      "billId": selectedBillId,
                                    };

                                    try {
                                      bool ok = await api.addGoal(data);
                                      if (ok && ctx.mounted) {
                                        Navigator.pop(ctx);
                                        ScaffoldMessenger.of(
                                          parentContext,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              "Цель успешно создана!",
                                            ),
                                          ),
                                        );
                                        widget.onGoalCreated();
                                      } else {
                                        setDialogState(
                                          () => isSubmitting = false,
                                        );
                                      }
                                    } catch (e) {
                                      setDialogState(
                                        () => isSubmitting = false,
                                      );
                                    }
                                  }
                                },
                          child: isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  "Создать",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
