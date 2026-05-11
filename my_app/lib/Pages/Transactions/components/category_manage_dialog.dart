import 'package:flutter/material.dart';
import 'package:my_app/CustomerWidgets/CustomerEdit.dart';
import 'package:my_app/helpers/validators.dart';

class CategoryManageDialog extends StatefulWidget {
  final Map<String, dynamic>? existing;
  final Function(Map<String, dynamic> data) onSave;
  final Function(int id)? onDelete;

  const CategoryManageDialog({
    super.key,
    this.existing,
    required this.onSave,
    this.onDelete,
  });

  @override
  State<CategoryManageDialog> createState() => _CategoryManageDialogState();
}

class _CategoryManageDialogState extends State<CategoryManageDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController nameController;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.existing?['name'] ?? "");
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? "Новая категория" : "Изменить категорию"),
      content: Form(
        key: _formKey,
        child: CustomerEdit(
          controller: nameController,
          label: "Название",
          icon: Icons.label_outline,
          validator: AppValidators.required,
          textCapitalization: TextCapitalization.sentences,
        ),
      ),
      actions: [
        if (widget.existing != null)
          TextButton(
            onPressed: () => widget.onDelete?.call(widget.existing!['categoryId']),
            child: const Text("Удалить", style: TextStyle(color: Colors.red)),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Отмена"),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              widget.onSave({"name": nameController.text});
            }
          },
          child: const Text("Сохранить"),
        ),
      ],
    );
  }
}