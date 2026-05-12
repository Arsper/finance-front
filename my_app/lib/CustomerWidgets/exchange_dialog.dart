import 'package:flutter/material.dart';

class ExchangeTransferDialog extends StatefulWidget {
  final List<dynamic> allWallets;
  final List<dynamic> fromWallets;
  final List<dynamic> toWallets;
  final String fromCode;
  final String toCode;
  final double initialAmount;
  final double exchangeRate;
  final Function(int sourceId, int targetId, double amount, double targetAmount) onConfirm;

  const ExchangeTransferDialog({
    super.key,
    required this.allWallets,
    required this.fromWallets,
    required this.toWallets,
    required this.fromCode,
    required this.toCode,
    required this.initialAmount,
    required this.exchangeRate,
    required this.onConfirm,
  });

  @override
  State<ExchangeTransferDialog> createState() => _ExchangeTransferDialogState();
}

class _ExchangeTransferDialogState extends State<ExchangeTransferDialog> {
  late TextEditingController _amountController;
  late double _currentAmount;
  late double _calculatedResult;
  int? _sourceBillId;
  int? _targetBillId;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(text: widget.initialAmount.toString());
    _currentAmount = widget.initialAmount;
    _calculatedResult = widget.initialAmount * widget.exchangeRate;
    
    if (widget.fromWallets.isNotEmpty) _sourceBillId = widget.fromWallets.first['billId'];
    if (widget.toWallets.isNotEmpty) _targetBillId = widget.toWallets.first['billId'];
  }

  void _updateAmount(String value) {
    final newAmount = double.tryParse(value.replaceFirst(',', '.')) ?? 0;
    setState(() {
      _currentAmount = newAmount;
      _calculatedResult = newAmount * widget.exchangeRate;
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedWallet = widget.fromWallets.cast<Map<String, dynamic>?>().firstWhere(
          (w) => w?['billId'] == _sourceBillId,
          orElse: () => null,
        );
    final double balance = (selectedWallet?['currentBalance'] ?? 0).toDouble();
    final bool isOverLimit = _sourceBillId != null && _currentAmount > balance;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 20, right: 20, top: 12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHandle(),
          const SizedBox(height: 24),
          const Text("Обмен валюты", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          
          _buildInputBlock(isOverLimit, balance),
          _buildArrowSeparator(),
          _buildResultBlock(),
          
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          
          _buildWalletSelectors(),
          const SizedBox(height: 32),
          
          _buildConfirmButton(isOverLimit),
        ],
      ),
    );
  }

  // --- Вспомогательные методы UI ---

  Widget _buildHandle() => Container(
    width: 36, height: 4,
    decoration: BoxDecoration(
      color: Colors.grey.withOpacity(0.3),
      borderRadius: BorderRadius.circular(2),
    ),
  );

  Widget _buildInputBlock(bool isOverLimit, double balance) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Вы отдаете", style: TextStyle(color: Colors.grey, fontSize: 12)),
                  TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(border: InputBorder.none, hintText: "0.00"),
                    onChanged: _updateAmount,
                  ),
                ],
              ),
            ),
            _buildCurrencyBadge(widget.fromCode, Colors.deepPurple),
          ],
        ),
        if (isOverLimit)
          Align(
            alignment: Alignment.centerLeft,
            child: Text("Недостаточно: ${balance.toStringAsFixed(2)}", 
              style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
          ),
      ],
    );
  }

  Widget _buildResultBlock() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Вы получите", style: TextStyle(color: Colors.grey, fontSize: 12)),
              Text(_calculatedResult.toStringAsFixed(2),
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green)),
            ],
          ),
        ),
        _buildCurrencyBadge(widget.toCode, Colors.green),
      ],
    );
  }

  Widget _buildWalletSelectors() {
    return Row(
      children: [
        Expanded(
          child: _CompactSelector(
            label: "Откуда",
            value: _sourceBillId,
            wallets: widget.fromWallets,
            onChanged: (val) => setState(() => _sourceBillId = val),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _CompactSelector(
            label: "Куда",
            value: _targetBillId,
            wallets: widget.toWallets,
            onChanged: (val) => setState(() => _targetBillId = val),
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmButton(bool isOverLimit) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 56),
        backgroundColor: Colors.deepPurple,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      onPressed: (_sourceBillId == null || _targetBillId == null || isOverLimit || _currentAmount <= 0)
          ? null
          : () => widget.onConfirm(_sourceBillId!, _targetBillId!, _currentAmount, _calculatedResult),
      child: const Text("ПОДТВЕРДИТЬ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildCurrencyBadge(String code, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
    child: Text(code, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
  );

  Widget _buildArrowSeparator() => const Padding(
    padding: EdgeInsets.symmetric(vertical: 8),
    child: Icon(Icons.arrow_downward, color: Colors.grey, size: 20),
  );
}

class _CompactSelector extends StatelessWidget {
  final String label;
  final int? value;
  final List<dynamic> wallets;
  final ValueChanged<int?> onChanged;

  const _CompactSelector({required this.label, required this.value, required this.wallets, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: value,
              isExpanded: true,
              items: wallets.map((w) => DropdownMenuItem<int>(
                value: w['billId'],
                child: Text(w['name'] ?? 'Счет', style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
              )).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}