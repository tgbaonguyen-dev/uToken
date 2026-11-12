import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BudgetLimitDialog extends StatefulWidget {
  const BudgetLimitDialog({super.key, required this.initialAmount});
  final num initialAmount;

  static String? validate(String input) {
    final value = double.tryParse(input.trim());
    return !RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(input.trim()) ||
            value == null ||
            !value.isFinite ||
            value < 1 ||
            value > 100000
        ? 'Enter 1–100000 USD, up to 2 decimals.'
        : null;
  }

  @override
  State<BudgetLimitDialog> createState() => _BudgetLimitDialogState();
}

class _BudgetLimitDialogState extends State<BudgetLimitDialog> {
  late String input = widget.initialAmount.toStringAsFixed(2);

  void submit() {
    if (BudgetLimitDialog.validate(input) != null) return;
    FocusScope.of(context).unfocus();
    Navigator.pop(context, double.parse(input.trim()));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        scrollable: true,
        title: const Text('Monthly limit (mock)'),
        content: TextFormField(
          key: const ValueKey('mock-budget-input'),
          initialValue: input,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.done,
          inputFormatters: [LengthLimitingTextInputFormatter(12)],
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: (value) => BudgetLimitDialog.validate(value ?? ''),
          decoration: const InputDecoration(
              prefixText: '\$', labelText: 'USD', errorMaxLines: 3),
          onChanged: (value) => setState(() => input = value),
          onTapOutside: (_) => FocusScope.of(context).unfocus(),
          onFieldSubmitted: (_) => submit(),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed:
                  BudgetLimitDialog.validate(input) == null ? submit : null,
              child: const Text('Apply')),
        ],
      );
}
