import 'package:flutter/material.dart';
import '../inputs/app_text_field.dart';

/// Search field with search icon
class SearchField extends StatefulWidget {
  final String? hint;
  final String? initialValue;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;

  const SearchField({
    super.key,
    this.hint,
    this.initialValue,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.onClear,
  });

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  late TextEditingController _controller;
  bool _isControllerOwned = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController(text: widget.initialValue);
    _isControllerOwned = widget.controller == null;
    if (widget.controller != null) {
      widget.controller!.addListener(_onTextChanged);
    } else {
      _controller.addListener(_onTextChanged);
    }
  }

  @override
  void dispose() {
    if (_isControllerOwned) {
      _controller.dispose();
    } else {
      widget.controller?.removeListener(_onTextChanged);
    }
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final hasText = _controller.text.isNotEmpty;
    
    return AppTextField(
      hint: widget.hint ?? 'Search...',
      controller: _controller,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      prefixIcon: const Icon(Icons.search),
      suffixIcon: hasText
          ? IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _controller.clear();
                widget.onClear?.call();
              },
            )
          : null,
    );
  }
}

