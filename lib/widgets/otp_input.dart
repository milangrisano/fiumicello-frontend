import 'package:flutter/material.dart';

/// A visual 6-box OTP input (one digit per box, auto-advances).
///
/// Reusable across registration and password recovery. The entered value is
/// read via a `GlobalKey<OtpInputState>` -> `state.value`.
class OtpInput extends StatefulWidget {
  final ValueChanged<String> onChanged;
  final int length;

  const OtpInput({super.key, this.length = 6, required this.onChanged});

  @override
  OtpInputState createState() => OtpInputState();
}

class OtpInputState extends State<OtpInput> {
  final _controllers = <TextEditingController>[];
  final _focusNodes = <FocusNode>[];

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < widget.length; i++) {
      _controllers.add(TextEditingController());
      _focusNodes.add(FocusNode());
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    super.dispose();
  }

  String get value => _controllers.map((c) => c.text).join();

  void _onChanged(int index, String text) {
    // Keep only the last typed digit in this box.
    final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isNotEmpty) {
      final last = digits[digits.length - 1];
      _controllers[index].text = last;
      _controllers[index].selection = TextSelection.collapsed(offset: 1);
      // Move focus to the next empty box when a digit is entered.
      if (index + 1 < widget.length) {
        _focusNodes[index + 1].requestFocus();
      }
    } else if (index > 0) {
      // Backspace moves focus back to the previous box.
      _focusNodes[index - 1].requestFocus();
    }
    widget.onChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 0; i < widget.length; i++)
          SizedBox(
            width: 48,
            height: 56,
            child: TextField(
              controller: _controllers[i],
              focusNode: _focusNodes[i],
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 1,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                counterText: '',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onChanged: (t) => _onChanged(i, t),
            ),
          ),
      ],
    );
  }
}