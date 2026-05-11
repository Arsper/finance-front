import 'package:flutter/services.dart';

class AmountLimitFormatter extends TextInputFormatter {
  final double maxAmount;
  AmountLimitFormatter(this.maxAmount);

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;
    
    final double? enteredAmount = double.tryParse(newValue.text.replaceAll(',', '.'));

    if (enteredAmount == null) return newValue;

    if (enteredAmount > (maxAmount + 0.0001)) {
      return oldValue;
    }
    
    return newValue;
  }
}