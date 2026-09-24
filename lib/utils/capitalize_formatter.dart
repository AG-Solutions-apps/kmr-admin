import 'package:flutter/services.dart';

/// TextInputFormatter that auto-capitalizes the first letter of words or text
/// even when typing from physical laptop/desktop keyboards.
class FirstLetterCapitalizeFormatter extends TextInputFormatter {
  final bool capitalizeWords;

  FirstLetterCapitalizeFormatter({this.capitalizeWords = true});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    String text = newValue.text;
    if (capitalizeWords) {
      final buffer = StringBuffer();
      bool capitalizeNext = true;
      for (int i = 0; i < text.length; i++) {
        final char = text[i];
        if (capitalizeNext && char.trim().isNotEmpty) {
          buffer.write(char.toUpperCase());
          capitalizeNext = false;
        } else {
          buffer.write(char);
          if (char == ' ' || char == '\n' || char == '\t') {
            capitalizeNext = true;
          }
        }
      }
      text = buffer.toString();
    } else {
      final buffer = StringBuffer();
      bool capitalizeNext = true;
      for (int i = 0; i < text.length; i++) {
        final char = text[i];
        if (capitalizeNext && char.trim().isNotEmpty) {
          buffer.write(char.toUpperCase());
          capitalizeNext = false;
        } else {
          buffer.write(char);
        }
      }
      text = buffer.toString();
    }

    int selectionOffset = newValue.selection.end;
    if (selectionOffset > text.length) {
      selectionOffset = text.length;
    }

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: selectionOffset),
    );
  }
}
