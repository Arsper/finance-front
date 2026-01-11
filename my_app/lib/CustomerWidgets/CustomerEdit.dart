import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CustomerEdit extends StatefulWidget {
  final String label;
  final IconData icon;
  final int maxLength;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  
  // Параметры конфигурации
  final bool isPassword;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final bool readOnly;
  final VoidCallback? onTap;
  
  // --- ДОБАВЛЕНО ---
  final TextInputAction? textInputAction; 

  const CustomerEdit({
    super.key,
    required this.label,
    required this.icon,
    this.controller,
    this.validator,
    this.maxLength = 64,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.readOnly = false,
    this.onTap,
    // --- ДОБАВЛЕНО ---
    this.textInputAction,
  });

  @override
  State<CustomerEdit> createState() => _CustomerEditState();
}

class _CustomerEditState extends State<CustomerEdit> {
  late bool _obscureText;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.isPassword;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); 

    return TextFormField(
      controller: widget.controller,
      obscureText: widget.isPassword ? _obscureText : false,
      obscuringCharacter: '☹',
      maxLength: widget.maxLength,
      keyboardType: widget.keyboardType,
      inputFormatters: widget.inputFormatters,
      textCapitalization: widget.textCapitalization,
      readOnly: widget.readOnly,
      onTap: widget.onTap,
      
      // --- ДОБАВЛЕНО: Передаем параметр в стандартное поле ---
      textInputAction: widget.textInputAction,

      onChanged: (val) {
        setState(() {}); 
      },

      buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,

      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: Icon(widget.icon),
        border: const OutlineInputBorder(),
        
        suffix: !widget.isPassword 
          ? Text(
              '${widget.controller?.text.length ?? 0}/${widget.maxLength}',
              style: TextStyle(fontSize: 12, color: theme.hintColor),
            )
          : null,

        suffixIcon: widget.isPassword
            ? IconButton(
                icon: Icon(
                  _obscureText ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () {
                  setState(() {
                    _obscureText = !_obscureText;
                  });
                },
              )
            : null,
      ),
      validator: widget.validator,
    );
  }
}