import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CustomerEdit extends StatefulWidget {
  final String label;
  final IconData? icon;
  final int? maxLength;
  final bool showCounter;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final bool isPassword;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final bool readOnly;
  final VoidCallback? onTap;
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;

  const CustomerEdit({
    super.key,
    required this.label,
    this.icon,
    this.controller,
    this.validator,
    this.errorText,
    this.onChanged,
    this.maxLength = 64,
    this.showCounter = true,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.readOnly = false,
    this.onTap,
    this.textInputAction,
    this.focusNode, // ИСПРАВЛЕНО: Добавлено в конструктор
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

    final effectiveMaxLength =
        (widget.maxLength != null && widget.maxLength! > 0)
        ? widget.maxLength
        : null;

    return TextFormField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      obscureText: widget.isPassword ? _obscureText : false,
      obscuringCharacter: '☹',
      maxLength: effectiveMaxLength,
      keyboardType: widget.keyboardType,
      inputFormatters: widget.inputFormatters,
      textCapitalization: widget.textCapitalization,
      readOnly: widget.readOnly,
      onTap: widget.onTap,
      textInputAction: widget.textInputAction,
      onChanged: (val) {
        if (widget.onChanged != null) widget.onChanged!(val);
        if (widget.showCounter) setState(() {});
      },
      buildCounter:
          (context, {required currentLength, required isFocused, maxLength}) =>
              null,
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: widget.icon != null ? Icon(widget.icon) : null,
        errorText: widget.errorText,
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        suffix:
            (widget.showCounter &&
                !widget.isPassword &&
                widget.errorText == null &&
                effectiveMaxLength != null)
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
                onPressed: () => setState(() => _obscureText = !_obscureText),
              )
            : null,
      ),
      validator: widget.validator,
    );
  }
}
