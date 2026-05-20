import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:my_app/CustomerWidgets/CustomerEdit.dart';
import 'package:my_app/helpers/validators.dart';

class TransactionForm extends StatefulWidget {
  final Map<String, dynamic>? existing;
  final List<dynamic> categories;
  final String currencySymbol;
  final Function(Function(int id, [String? name]) callback) onCategoryTap;

  final Function(Map<String, dynamic> category)? onEditCategory;
  final Function(Map<String, dynamic> data) onSave;
  final VoidCallback? onDelete;
  final bool Function(Map<String, dynamic> cat) isCategoryEditable;

  const TransactionForm({
    super.key,
    this.existing,
    required this.categories,
    required this.currencySymbol,
    required this.onCategoryTap,
    required this.onSave,
    required this.isCategoryEditable,
    this.onEditCategory,
    this.onDelete,
  });

  @override
  State<TransactionForm> createState() => _TransactionFormState();
}

class _TransactionFormState extends State<TransactionForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController amountController;
  late TextEditingController descController;
  late TextEditingController dateController;
  late TextEditingController categoryNameController;
  int? selectedCategoryId;
  late bool isIncome;

  @override
  void initState() {
    super.initState();
    final num? rawAmount =
        widget.existing?['amount'] ?? widget.existing?['sum'];

    amountController = TextEditingController(
      text: rawAmount != null ? rawAmount.abs().toString() : "",
    );
    descController = TextEditingController(
      text: widget.existing?['description'] ?? "",
    );
    dateController = TextEditingController(
      text:
          widget.existing?['transactionDate'] ??
          DateFormat('yyyy-MM-dd').format(DateTime.now()),
    );

    selectedCategoryId = widget.existing?['categoryId'];
    isIncome = rawAmount != null ? rawAmount > 0 : false;

    final initialCat = widget.categories.firstWhere(
      (c) => (c['categoryId'] ?? c['id']) == selectedCategoryId,
      orElse: () => {"name": ""},
    );
    categoryNameController = TextEditingController(
      text: initialCat['name'] ?? "",
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(colors),
              const SizedBox(height: 15),
              _buildTypeToggle(),
              const SizedBox(height: 15),
              _buildCategoryRow(),
              const SizedBox(height: 15),
              _buildAmountField(),
              const SizedBox(height: 15),
              _buildDateField(),
              const SizedBox(height: 15),
              _buildDescriptionField(),
              const SizedBox(height: 20),
              _buildSaveButton(colors),
              const SizedBox(height: 25),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryRow() {
    return GestureDetector(
      onTap: () {
        widget.onCategoryTap((newId, [newName]) {
          setState(() {
            selectedCategoryId = newId;
            if (newName != null) {
              categoryNameController.text = newName;
            }
          });
        });
      },
      child: AbsorbPointer(
        child: CustomerEdit(
          controller: categoryNameController,
          label: "Категория",
          icon: Icons.widgets_outlined,
          validator: (v) =>
              (v == null || v.isEmpty) ? "Выберите категорию" : null,
        ),
      ),
    );
  }

  Widget _buildSaveButton(ColorScheme colors) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 55),
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
      onPressed: () {
        if (_formKey.currentState!.validate()) {
          double val =
              double.tryParse(amountController.text.replaceAll(',', '.')) ?? 0;
          widget.onSave({
            "categoryId": selectedCategoryId,
            "amount": isIncome ? val : -val,
            "description": descController.text,
            "transactionDate": dateController.text,
            "isIncome": isIncome,
          });
        }
      },
      child: const FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          "СОХРАНИТЬ",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme colors) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const SizedBox(width: 48),
        Text(
          widget.existing == null ? "Новая операция" : "Редактирование",
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        widget.existing != null
            ? IconButton(
                icon: Icon(Icons.delete_outline, color: colors.error),
                onPressed: widget.onDelete,
              )
            : const SizedBox(width: 48),
      ],
    );
  }

  Widget _buildTypeToggle() {
    return ToggleButtons(
      isSelected: [!isIncome, isIncome],
      onPressed: (index) => setState(() => isIncome = index == 1),
      borderRadius: BorderRadius.circular(10),
      selectedColor: Colors.white,
      fillColor: isIncome ? Colors.green : Colors.red,
      children: const [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 30),
          child: Text("Расход"),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 30),
          child: Text("Доход"),
        ),
      ],
    );
  }

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

  Widget _buildDateField() => CustomerEdit(
    controller: dateController,
    label: "Дата",
    icon: Icons.calendar_today,
    readOnly: true,
    onTap: () async {
      DateTime? picked = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(2020),
        lastDate: DateTime(2101),
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
}
