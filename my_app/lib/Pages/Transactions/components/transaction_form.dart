import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:my_app/CustomerWidgets/CustomerEdit.dart';
import 'package:my_app/helpers/validators.dart';

class TransactionForm extends StatefulWidget {
  final Map<String, dynamic>? existing;
  final List<dynamic> categories;
  final String currencySymbol;
  final Function(Function(int?) callback) onCategoryTap;
  final VoidCallback onAddCategory;
  final Function(Map<String, dynamic> category)? onEditCategory;
  final Function(Map<String, dynamic> data) onSave;
  final bool Function(Map<String, dynamic> cat) isCategoryEditable;

  const TransactionForm({
    super.key,
    this.existing,
    required this.categories,
    required this.currencySymbol,
    required this.onCategoryTap,
    required this.onAddCategory,
    required this.onSave,
    required this.isCategoryEditable,
    this.onEditCategory,
  });

  @override
  State<TransactionForm> createState() => _TransactionFormState();
}

class _TransactionFormState extends State<TransactionForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController amountController;
  late TextEditingController descController;
  late TextEditingController dateController;
  int? selectedCategoryId;
  late bool isIncome;

  @override
  void initState() {
    super.initState();
    amountController = TextEditingController(
      text: widget.existing != null
          ? (widget.existing!['amount'] as num).abs().toString()
          : "",
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
    isIncome = widget.existing != null
        ? (widget.existing!['amount'] as num) > 0
        : false;
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.existing == null ? "Новая операция" : "Редактирование",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            ToggleButtons(
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
            ),
            const SizedBox(height: 15),
            _buildCategoryRow(),
            const SizedBox(height: 15),
            CustomerEdit(
              controller: amountController,
              label: "Сумма",
              icon: isIncome
                  ? Icons.add_circle_outline
                  : Icons.remove_circle_outline,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*[.,]?\d{0,2}')),
              ],
              validator: AppValidators.amount,
            ),
            const SizedBox(height: 15),
            CustomerEdit(
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
                  // Добавили открывающую скобку
                  setState(
                    () => dateController.text = DateFormat(
                      'yyyy-MM-dd',
                    ).format(picked),
                  );
                } 
              },
            ),
            const SizedBox(height: 15),
            CustomerEdit(
              controller: descController,
              label: "Описание",
              icon: Icons.description_outlined,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: colors.primary,
                foregroundColor: colors.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  double val =
                      double.tryParse(
                        amountController.text.replaceAll(',', '.'),
                      ) ??
                      0;
                  widget.onSave({
                    "categoryId": selectedCategoryId,
                    "amount": isIncome ? val : -val,
                    "description": descController.text,
                    "transactionDate": dateController.text,
                    "isIncome":
                        isIncome, // Передаем флаг для проверки лимита в основном файле
                  });
                }
              },
              child: const Text(
                "Сохранить",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryRow() {
    final selectedCat = widget.categories.firstWhere(
      (c) => c['categoryId'] == selectedCategoryId,
      orElse: () => <String, dynamic>{},
    );

    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              widget.onCategoryTap((newId) {
                if (newId != null) {
                  setState(() {
                    selectedCategoryId = newId;
                  });
                }
              });
            },
            child: AbsorbPointer(
              child: TextFormField(
                decoration: InputDecoration(
                  labelText: "Категория",
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.category),
                  hintText: selectedCat.isEmpty
                      ? 'Выберите категорию'
                      : selectedCat['name'],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          onPressed: widget.onAddCategory,
          icon: const Icon(Icons.add),
        ),
        if (selectedCategoryId != null &&
            widget.isCategoryEditable(selectedCat))
          IconButton.outlined(
            onPressed: () => widget.onEditCategory?.call(selectedCat),
            icon: const Icon(Icons.edit),
          ),
      ],
    );
  }
}
