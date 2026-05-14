import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_app/CustomerWidgets/CustomerEdit.dart';
import 'package:my_app/api/data/сurrency.dart';
import 'package:my_app/helpers/validators.dart';

class WalletFormSheet extends StatefulWidget {
  final Map<String, dynamic>? existingWallet;
  final List<Currency> currencies;
  final Function(Map<String, dynamic>) onSave;
  final VoidCallback? onDelete; // Добавили колбэк удаления

  const WalletFormSheet({
    super.key,
    required this.existingWallet,
    required this.currencies,
    required this.onSave,
    this.onDelete,
  });

  @override
  State<WalletFormSheet> createState() => WalletFormSheetState();
}

class WalletFormSheetState extends State<WalletFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController nameController;
  late TextEditingController balanceController;
  late TextEditingController currencyController;
  int? selectedCurrencyId;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(
      text: widget.existingWallet?['name'],
    );
    balanceController = TextEditingController(
      text: widget.existingWallet == null
          ? "0"
          : widget.existingWallet!['currentBalance']?.toString(),
    );

    final rawId = widget.existingWallet?['currencyId'];
    if (rawId != null) {
      selectedCurrencyId = int.tryParse(rawId.toString());
    }

    if (selectedCurrencyId == null &&
        widget.existingWallet?['currencyCode'] != null) {
      try {
        selectedCurrencyId = widget.currencies
            .firstWhere((c) => c.code == widget.existingWallet!['currencyCode'])
            .idCurrencies;
      } catch (_) {}
    }

    String initialCode = '???';
    if (selectedCurrencyId != null) {
      final curr = widget.currencies.firstWhere(
        (c) => c.idCurrencies == selectedCurrencyId,
        orElse: () =>
            Currency(idCurrencies: 0, code: '???', name: '', symbol: ''),
      );
      initialCode = curr.code;
    } else if (widget.currencies.isNotEmpty) {
      selectedCurrencyId = widget.currencies.first.idCurrencies;
      initialCode = widget.currencies.first.code;
    }

    currencyController = TextEditingController(text: initialCode);
  }

  @override
  void dispose() {
    nameController.dispose();
    balanceController.dispose();
    currencyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20,
        right: 20,
        top: 10, // Уменьшен для заголовка
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ЗАГОЛОВОК С КОРЗИНОЙ В УГЛУ
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 48),
                Text(
                  widget.existingWallet == null
                      ? 'Новый счет'
                      : 'Редактирование',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                widget.existingWallet != null
                    ? IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                        onPressed: widget.onDelete,
                      )
                    : const SizedBox(width: 48),
              ],
            ),
            const SizedBox(height: 10),
            CustomerEdit(
              controller: nameController,
              label: 'Название',
              icon: Icons.account_balance_wallet,
              validator: AppValidators.required,
            ),
            const SizedBox(height: 15),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: CustomerEdit(
                    controller: balanceController,
                    label: 'Баланс',
                    icon: Icons.attach_money,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*[.,]?\d{0,2}'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: _showCurrencyPicker,
                    child: AbsorbPointer(
                      child: CustomerEdit(
                        controller: currencyController,
                        label: "Валюта",
                        maxLength: 0,
                        showCounter: false,
                        icon: Icons.currency_exchange,
                        readOnly: true,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 25),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  widget.onSave({
                    "name": nameController.text.trim(),
                    "type": widget.existingWallet?['type'] ?? 'Debit',
                    "startBalance":
                        double.tryParse(
                          balanceController.text.replaceAll(',', '.'),
                        ) ??
                        0.0,
                    "currencyId": selectedCurrencyId,
                  });
                }
              },
              child: const Text(
                'СОХРАНИТЬ',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCurrencyPicker() {
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
              "Выберите валюту",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.currencies.length,
                itemBuilder: (context, index) {
                  final curr = widget.currencies[index];
                  final bool isSelected =
                      curr.idCurrencies == selectedCurrencyId;
                  return ListTile(
                    leading: Text(
                      curr.symbol,
                      style: const TextStyle(fontSize: 20),
                    ),
                    title: Text(curr.name),
                    subtitle: Text(curr.code),
                    trailing: isSelected
                        ? const Icon(
                            Icons.check_circle,
                            color: Colors.deepPurple,
                          )
                        : null,
                    onTap: () {
                      setState(() {
                        selectedCurrencyId = curr.idCurrencies;
                        currencyController.text = curr.code;
                      });
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
}
