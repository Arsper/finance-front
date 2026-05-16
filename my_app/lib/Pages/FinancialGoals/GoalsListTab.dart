import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_app/CustomerWidgets/CustomerEdit.dart';
import 'package:my_app/api/DioClient.dart';
import 'package:my_app/api/sources/remoteDataSource.dart';
import 'package:my_app/helpers/AmountLimitFormatte.dart';
import 'package:my_app/helpers/validators.dart';

class GoalsListTab extends StatefulWidget {
  const GoalsListTab({super.key});

  @override
  State<GoalsListTab> createState() => GoalsListTabState();
}

class GoalsListTabState extends State<GoalsListTab> {
  final UserRemoteDataSource api = UserRemoteDataSource(
    dio: Dioclient.instance,
  );
  List<dynamic> goals = [];
  List<dynamic> bills = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      final results = await Future.wait([api.getGoals(), api.getWallets()]);
      if (mounted) {
        setState(() {
          goals = results[0];
          bills = results[1];
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> loadGoals() => _loadData();

  Map<String, dynamic>? _findBill(dynamic goalBillId) {
    if (goalBillId == null || bills.isEmpty) return null;
    final String searchId = goalBillId.toString().replaceAll('.0', '').trim();
    for (var bill in bills) {
      final rawBillId = bill['billId'] ?? bill['id'];
      if (rawBillId != null) {
        if (rawBillId.toString().replaceAll('.0', '').trim() == searchId) {
          return bill;
        }
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator());
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(title: Text("Финансовые цели"), actions: []),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: goals.isEmpty
            ? Center(
                child: Text(
                  "У вас пока нет целей",
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              )
            : ListView.builder(
                itemCount: goals.length,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                itemBuilder: (context, index) {
                  final goal = goals[index];
                  final double target = (goal['targetAmount'] as num)
                      .toDouble();
                  final double current = (goal['currentAmount'] ?? 0)
                      .toDouble();
                  final double remaining = (target - current) < 0
                      ? 0
                      : (target - current);
                  final linkedBill = _findBill(goal['billId']);

                  String symbol =
                      goal['currencyCode'] ?? linkedBill?['currencyCode'] ?? '';
                  double progress = target == 0 ? 0 : (current / target);
                  if (progress > 1.0) progress = 1.0;
                  final bool isCompleted = progress >= 1.0;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? colorScheme.surfaceContainer
                          : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.4,
                        ),
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () => _showEditDialog(goal),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Column(
                              children: [
                                Text(
                                  goal['name'] ?? "Цель",
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Цель: ${target.toStringAsFixed(0)} $symbol",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: _buildSliderWithText(
                                    context,
                                    progress,
                                    current,
                                    remaining,
                                    symbol,
                                    isCompleted,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                _buildPlusButton(context, isCompleted, goal),
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
    );
  }

  Widget _buildSliderWithText(
    BuildContext context,
    double progress,
    double current,
    double remaining,
    String symbol,
    bool isCompleted,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final progressColor = isCompleted ? Colors.green : colorScheme.primary;
    final backgroundColor = isDark
        ? const Color(0xFF262130)
        : const Color(0xFFF3F4F6);

    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                width: constraints.maxWidth * progress,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: progressColor,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          current.toStringAsFixed(0),
                          style: TextStyle(
                            color: progress > 0.15
                                ? Colors.white
                                : colorScheme.onSurface,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (!isCompleted)
                        Expanded(
                          child: Text(
                            remaining.toStringAsFixed(0),
                            style: TextStyle(
                              color: progress > 0.85
                                  ? Colors.white
                                  : (isDark
                                        ? colorScheme.onSurface
                                        : Colors.black87),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.end,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      if (isCompleted)
                        const Icon(
                          Icons.check_circle_outline,
                          color: Colors.white,
                          size: 22,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPlusButton(
    BuildContext context,
    bool isCompleted,
    dynamic goal,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: isCompleted
          ? Colors.green.withValues(alpha: 0.1)
          : colorScheme.primary,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: isCompleted ? null : () => _showDepositDialog(goal),
        child: SizedBox(
          width: 52,
          height: 52,
          child: Icon(
            isCompleted ? Icons.check : Icons.add,
            color: isCompleted ? Colors.green : Colors.white,
            size: 26,
          ),
        ),
      ),
    );
  }

  void _showDepositDialog(Map<String, dynamic> initialGoal) {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final goal = goals.firstWhere(
            (g) => g['id'] == initialGoal['id'],
            orElse: () => initialGoal,
          );
          final linkedBill = _findBill(goal['billId']);
          double walletBalance = linkedBill != null
              ? (linkedBill['currentBalance'] ?? linkedBill['balance'] ?? 0)
                    .toDouble()
              : 0.0;
          double current = (goal['currentAmount'] ?? 0).toDouble();
          double target = (goal['targetAmount'] as num).toDouble();
          double remaining = target - current < 0 ? 0 : target - current;
          double maxPossibleInput = remaining < walletBalance
              ? remaining
              : walletBalance;

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              "Пополнить цель",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Доступно: ${walletBalance.toStringAsFixed(2)}",
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Text(
                    "Максимум: ${maxPossibleInput.toStringAsFixed(2)}",
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.blueAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 14),
                  CustomerEdit(
                    key: ValueKey("limit_$maxPossibleInput"),
                    controller: controller,
                    label: "Сумма",
                    icon: Icons.account_balance_wallet_outlined,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*[.,]?\d{0,2}'),
                      ),
                      AmountLimitFormatter(maxPossibleInput),
                    ],
                    onChanged: (val) => setDialogState(() {}),
                    validator: (val) =>
                        (val == null || val.isEmpty) ? "Введите сумму" : null,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  "ОТМЕНА",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              TextButton(
                onPressed: maxPossibleInput <= 0
                    ? null
                    : () async {
                        if (formKey.currentState!.validate()) {
                          double addAmount = double.parse(
                            controller.text.replaceAll(',', '.'),
                          );
                          final Map<String, dynamic> updateData = {
                            "name": goal['name'],
                            "targetAmount": goal['targetAmount'],
                            "targetDate": goal['targetDate'].toString().split(
                              "T",
                            )[0],
                            "currentAmount": current + addAmount,
                            "billId": goal['billId'],
                          };
                          if (await api.updateGoal(goal['id'], updateData)) {
                            await _loadData();
                            if (ctx.mounted) Navigator.pop(ctx);
                          }
                        }
                      },
                child: Text(
                  "ВНЕСТИ",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditDialog(Map<String, dynamic> goal) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: goal['name']);
    final targetCtrl = TextEditingController(
      text: goal['targetAmount'].toString(),
    );
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Параметры",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.red,
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  if (await api.deleteGoal(goal['id'])) _loadData();
                },
              ),
            ],
          ),
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
                    validator: AppValidators.required,
                  ),
                  const SizedBox(height: 12),
                  CustomerEdit(
                    controller: targetCtrl,
                    label: "Цель",
                    icon: Icons.outlined_flag,
                    maxLength: 12,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*[.,]?\d{0,2}'),
                      ),
                    ],
                    validator: AppValidators.amount,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<dynamic>(
                    initialValue: currentBillVal,
                    isExpanded: true,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 16,
                    ),
                    iconEnabledColor: Theme.of(context).colorScheme.onSurface,
                    decoration: InputDecoration(
                      labelText: "Привязанный счет",
                      labelStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: Theme.of(
                            context,
                          ).colorScheme.outlineVariant.withValues(alpha: 0.6),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      prefixIcon: Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 20,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    items: bills.map((b) {
                      final val = b['billId'] ?? b['id'];
                      return DropdownMenuItem<dynamic>(
                        value: val,
                        child: Text(
                          "${b['name']}",
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) =>
                        setDialogState(() => currentBillVal = val),
                    validator: (val) => val == null ? "Выберите счет" : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("ОТМЕНА", style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () async {
                if (formKey.currentState!.validate() &&
                    currentBillVal != null) {
                  String dateStr = dateCtrl.text;
                  if (dateStr.contains("T")) dateStr = dateStr.split("T")[0];
                  final data = {
                    "name": nameCtrl.text,
                    "targetAmount":
                        double.tryParse(targetCtrl.text.replaceAll(',', '.')) ??
                        0,
                    "targetDate": dateStr,
                    "billId": currentBillVal,
                  };
                  if (await api.updateGoal(goal['id'], data) && ctx.mounted) {
                    Navigator.pop(ctx);
                    _loadData();
                  }
                }
              },
              child: Text(
                "СОХРАНИТЬ",
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
