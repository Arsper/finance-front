import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:my_app/CustomerWidgets/CustomerEdit.dart';
import 'package:my_app/helpers/validators.dart';

class RecurringPaymentForm extends StatefulWidget {
  final Map<String, dynamic>? existing;
  final List<dynamic> wallets;
  final List<dynamic> categories;
  final Function(Map<String, dynamic>) onSave;
  final VoidCallback onDelete;
  final Function(int?, Function(int, String?)) onShowPicker;

  const RecurringPaymentForm({
    super.key,
    this.existing,
    required this.wallets,
    required this.categories,
    required this.onSave,
    required this.onDelete,
    required this.onShowPicker,
  });

  @override
  State<RecurringPaymentForm> createState() => _RecurringPaymentFormState();
}

class _RecurringPaymentFormState extends State<RecurringPaymentForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController amountController;
  late TextEditingController descController;
  late TextEditingController dateController;
  late TextEditingController categoryNameController;

  int? selectedBillId;
  int? selectedCategoryId;
  late bool isIncome;
  late String selectedPeriodicityKey;

  final Map<String, String> periodicityMap = {
    'Ежедневно': 'DAILY',
    'Еженедельно': 'WEEKLY',
    'Ежемесячно': 'MONTHLY',
    'Ежегодно': 'YEARLY',
  };

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    amountController = TextEditingController(
      text: p != null ? (p['amount'] as num).abs().toString() : "",
    );
    descController = TextEditingController(text: p?['description'] ?? "");
    dateController = TextEditingController(
      text:
          p?['nextPaymentDate'] ??
          DateFormat('yyyy-MM-dd').format(DateTime.now()),
    );

    selectedBillId = p?['billId'];
    selectedCategoryId = p?['categoryId'];
    isIncome = p != null ? (p['amount'] as num) > 0 : false;

    selectedPeriodicityKey = periodicityMap.entries
        .firstWhere(
          (e) => e.value == p?['periodicity'],
          orElse: () => const MapEntry('Ежемесячно', 'MONTHLY'),
        )
        .key;

    final initialCat = widget.categories.firstWhere(
      (c) => (c['categoryId'] ?? c['id']) == selectedCategoryId,
      orElse: () => <String, dynamic>{"name": ""},
    );
    categoryNameController = TextEditingController(
      text: initialCat['name'] ?? "",
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              const SizedBox(height: 15),
              _buildTypeToggle(),
              const SizedBox(height: 15),
              _buildWalletDropdown(),
              const SizedBox(height: 15),
              _buildCategoryField(),
              const SizedBox(height: 15),
              _buildAmountField(),
              const SizedBox(height: 15),
              _buildPeriodicityDropdown(),
              const SizedBox(height: 15),
              _buildDateField(),
              const SizedBox(height: 15),
              _buildDescriptionField(),
              const SizedBox(height: 20),
              _buildSaveButton(),
              const SizedBox(height: 25),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      const SizedBox(width: 48),
      Text(
        widget.existing == null ? "Новый платёж" : "Редактирование",
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      widget.existing != null
          ? IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: widget.onDelete,
            )
          : const SizedBox(width: 48),
    ],
  );

  Widget _buildTypeToggle() => ToggleButtons(
    isSelected: [!isIncome, isIncome],
    onPressed: (index) => setState(() => isIncome = index == 1),
    borderRadius: BorderRadius.circular(10),
    selectedColor: Colors.white,
    fillColor: isIncome ? Colors.green : Colors.red,
    constraints: BoxConstraints(
      minWidth: (MediaQuery.of(context).size.width - 60) / 2,
      minHeight: 40,
    ),
    children: const [Text("Расход"), Text("Доход")],
  );

  Widget _buildWalletDropdown() {
    final selectedWallet = widget.wallets.firstWhere(
      (w) => w['billId'] == selectedBillId,
      orElse: () => <String, dynamic>{},
    );

    return GestureDetector(
      onTap: _showWalletPicker,
      child: AbsorbPointer(
        child: CustomerEdit(
          controller: TextEditingController(
            text: (selectedWallet.isNotEmpty) ? selectedWallet['name'] : "",
          ),
          label: "Счет списания",
          icon: Icons.account_balance_wallet_outlined,
          readOnly: true,
          validator: (val) => (selectedBillId == null) ? "Выберите счет" : null,
        ),
      ),
    );
  }

  void _showWalletPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Выберите счет",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.wallets.length,
                itemBuilder: (context, index) {
                  final wallet = widget.wallets[index];
                  final bool isSelected = wallet['billId'] == selectedBillId;

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.deepPurple.withValues(alpha: 0.1),
                      child: const Icon(
                        Icons.wallet,
                        color: Colors.deepPurple,
                        size: 20,
                      ),
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
                        ? const Icon(
                            Icons.check_circle,
                            color: Colors.deepPurple,
                          )
                        : null,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    onTap: () {
                      setState(() => selectedBillId = wallet['billId']);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryField() => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () {
      widget.onShowPicker(selectedBillId, (id, name) {
        setState(() {
          selectedCategoryId = id;
          categoryNameController.text = name ?? "";
        });
      });
    },
    child: IgnorePointer(
      child: CustomerEdit(
        controller: categoryNameController,
        label: "Категория",
        icon: Icons.category_outlined,
        readOnly: true,
        validator: (val) =>
            (val == null || val.isEmpty) ? "Выберите категорию" : null,
      ),
    ),
  );

  Widget _buildAmountField() => CustomerEdit(
    controller: amountController,
    label: "Сумма",
    icon: isIncome ? Icons.add_circle_outline : Icons.remove_circle_outline,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    inputFormatters: [
      FilteringTextInputFormatter.allow(RegExp(r'^\d*[.,]?\d{0,2}')),
    ],
    validator: AppValidators.amount,
  );

  Widget _buildPeriodicityDropdown() {
    return GestureDetector(
      onTap: _showPeriodicityPicker,
      child: AbsorbPointer(
        child: CustomerEdit(
          controller: TextEditingController(text: selectedPeriodicityKey),
          label: "Как часто?",
          icon: Icons.repeat,
          readOnly: true,
        ),
      ),
    );
  }

  void _showPeriodicityPicker() {
    final Map<String, IconData> periodicityIcons = {
      'Ежедневно': Icons.today,
      'Еженедельно': Icons.date_range,
      'Ежемесячно': Icons.calendar_month,
      'Ежегодно': Icons.event_note,
    };

    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Повторение платежа",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 15),
            ...periodicityMap.keys.map((key) {
              final bool isSelected = key == selectedPeriodicityKey;

              return ListTile(
                leading: Icon(
                  periodicityIcons[key] ?? Icons.circle,
                  color: isSelected
                      ? Colors.deepPurple
                      : colorScheme.onSurfaceVariant,
                ),
                title: Text(
                  key,
                  style: TextStyle(
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: isSelected
                        ? Colors.deepPurple
                        : colorScheme.onSurface,
                  ),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check_circle, color: Colors.deepPurple)
                    : null,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                onTap: () {
                  setState(() => selectedPeriodicityKey = key);
                  Navigator.pop(context);
                },
              );
            }),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildDateField() => CustomerEdit(
    controller: dateController,
    label: "Дата след. операции",
    icon: Icons.calendar_today,
    readOnly: true,
    onTap: () async {
      DateTime? picked = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime.now(),
        lastDate: DateTime(2100),
      );
      if (picked != null) {
        setState(
          () => dateController.text = DateFormat('yyyy-MM-dd').format(picked),
        );
      }
    },
  );

  Widget _buildDescriptionField() => CustomerEdit(
    controller: descController,
    label: "Описание",
    icon: Icons.description_outlined,
  );

  Widget _buildSaveButton() => ElevatedButton(
    style: ElevatedButton.styleFrom(
      minimumSize: const Size(double.infinity, 55),
      backgroundColor: Colors.deepPurple,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
    ),
    onPressed: () {
      if (_formKey.currentState!.validate()) {
        double val =
            double.tryParse(amountController.text.replaceFirst(',', '.')) ?? 0;
        widget.onSave({
          "billId": selectedBillId,
          "categoryId": selectedCategoryId,
          "description": descController.text,
          "amount": isIncome ? val : -val,
          "periodicity": periodicityMap[selectedPeriodicityKey],
          "nextPaymentDate": dateController.text,
        });
      }
    },
    child: const Text(
      "СОХРАНИТЬ",
      style: TextStyle(fontWeight: FontWeight.bold),
    ),
  );
}
