import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_app/CustomerWidgets/CustomerEdit.dart';
import 'package:my_app/helpers/validators.dart';

class LimitManageDialog extends StatefulWidget {
  final int? categoryId;
  final Map<String, dynamic>? existingLimit;
  final Function(Map<String, dynamic> data) onSave;
  final Function(int id) onDelete;

  const LimitManageDialog({
    super.key,
    this.categoryId,
    this.existingLimit,
    required this.onSave,
    required this.onDelete,
  });

  @override
  State<LimitManageDialog> createState() => _LimitManageDialogState();
}

class _LimitManageDialogState extends State<LimitManageDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController amountController;
  late String selectedPeriod;

  @override
  void initState() {
    super.initState();
    // Приводим к строке безопасно
    final amount = widget.existingLimit?['limitAmount'];
    amountController = TextEditingController(
      text: amount != null ? amount.toString() : "",
    );
    // Убеждаемся, что значение соответствует одному из пунктов списка
    selectedPeriod = widget.existingLimit?['periodicity'] ?? 'MONTHLY';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.existingLimit == null ? "Установить лимит" : "Изменить лимит",
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomerEdit(
              controller: amountController,
              label: "Сумма лимита",
              icon: Icons.speed,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*[.,]?\d{0,2}')),
              ],
              validator: AppValidators.amount,
            ),
            const SizedBox(height: 15),
            DropdownButtonFormField<String>(
              key: ValueKey(selectedPeriod), // Важно для обновления
              value: selectedPeriod,
              decoration: const InputDecoration(
                labelText: "Период",
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'DAILY', child: Text("Ежедневно")),
                DropdownMenuItem(value: 'WEEKLY', child: Text("Еженедельно")),
                DropdownMenuItem(value: 'MONTHLY', child: Text("Ежемесячно")),
                DropdownMenuItem(value: 'YEARLY', child: Text("Ежегодно")),
              ],
              onChanged: (val) => setState(() => selectedPeriod = val!),
            ),
          ],
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Column(
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    // Парсим ID в int, так как API обычно ждет число
                    final rawId =
                        widget.categoryId ??
                        widget.existingLimit?['categoryId'];
                    final categoryId = int.tryParse(rawId.toString());

                    widget.onSave({
                      "categoryId": categoryId,
                      "limitAmount": double.parse(
                        amountController.text.replaceAll(',', '.'),
                      ),
                      "periodicity": selectedPeriod,
                    });
                  }
                },
                child: const Text(
                  "СОХРАНИТЬ",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("ОТМЕНА"),
              ),
              if (widget.existingLimit != null) ...[
                const Divider(),
                TextButton(
                  onPressed: () {
                    final limitId = int.tryParse(
                      widget.existingLimit!['id'].toString(),
                    );
                    if (limitId != null) widget.onDelete(limitId);
                  },
                  child: const Text(
                    "УДАЛИТЬ ЛИМИТ",
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
