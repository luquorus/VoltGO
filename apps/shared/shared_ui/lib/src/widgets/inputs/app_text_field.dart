import 'package:flutter/material.dart';

/// Standard text field with consistent styling
class AppTextField extends StatelessWidget {
  final String? label;
  final String? hint;
  final String? initialValue;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String? errorText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final int? maxLines;
  final int? maxLength;
  final bool enabled;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final FocusNode? focusNode;
  final String? Function(String?)? validator;

  const AppTextField({
    super.key,
    this.label,
    this.hint,
    this.initialValue,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.errorText,
    this.obscureText = false,
    this.keyboardType,
    this.maxLines = 1,
    this.maxLength,
    this.enabled = true,
    this.prefixIcon,
    this.suffixIcon,
    this.focusNode,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      initialValue: initialValue,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      obscureText: obscureText,
      keyboardType: keyboardType,
      maxLines: maxLines,
      maxLength: maxLength,
      enabled: enabled,
      focusNode: focusNode,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: errorText,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
      ),
    );
  }
}

