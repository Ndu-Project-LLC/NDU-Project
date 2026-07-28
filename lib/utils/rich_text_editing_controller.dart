import 'package:flutter/material.dart';

/// Renders lightweight markdown-like tokens inline inside `TextField`/`TextFormField`.
/// Supported markers:
/// - `**bold**`
/// - `*italic*`
/// - `__underline__`
/// - `#`, `##`, `###` at the start of a line
///
/// The controller keeps the original tokenized text for persistence while
/// replacing formatting markers with zero-width characters during painting.
class RichTextEditingController extends TextEditingController {
  RichTextEditingController({super.text});

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    return buildInlineFormattedTextSpan(
      text: text,
      baseStyle: style ?? DefaultTextStyle.of(context).style,
    );
  }
}

TextSpan buildInlineFormattedTextSpan({
  required String text,
  required TextStyle baseStyle,
}) {
  if (text.isEmpty) {
    return TextSpan(style: baseStyle, text: text);
  }
  return TextSpan(
    style: baseStyle,
    children:
        _RichTextSpanParser(baseStyle).build(text.replaceAll('\r\n', '\n')),
  );
}

class _RichTextSpanParser {
  const _RichTextSpanParser(this.baseStyle);

  static const String _hiddenChar = '\u200B';

  final TextStyle baseStyle;

  List<InlineSpan> build(String value) {
    final spans = <InlineSpan>[];
    final lines = value.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final resolved = _resolveLine(lines[i]);
      spans.addAll(_parseInline(resolved.text, resolved.style));
      if (i < lines.length - 1) {
        spans.add(TextSpan(text: '\n', style: resolved.style));
      }
    }
    return spans;
  }

  _ResolvedLine _resolveLine(String line) {
    if (line.startsWith('### ')) {
      return _ResolvedLine(
        text: '${_hidden(4)}${line.substring(4)}',
        style: baseStyle.copyWith(
          fontSize: (baseStyle.fontSize ?? 14) + 2,
          fontWeight: FontWeight.w700,
        ),
      );
    }
    if (line.startsWith('## ')) {
      return _ResolvedLine(
        text: '${_hidden(3)}${line.substring(3)}',
        style: baseStyle.copyWith(
          fontSize: (baseStyle.fontSize ?? 14) + 4,
          fontWeight: FontWeight.w800,
        ),
      );
    }
    if (line.startsWith('# ')) {
      return _ResolvedLine(
        text: '${_hidden(2)}${line.substring(2)}',
        style: baseStyle.copyWith(
          fontSize: (baseStyle.fontSize ?? 14) + 8,
          fontWeight: FontWeight.w900,
        ),
      );
    }
    return _ResolvedLine(text: line, style: baseStyle);
  }

  List<InlineSpan> _parseInline(String input, TextStyle style) {
    final spans = <InlineSpan>[];
    var index = 0;

    while (index < input.length) {
      final marker = _nextMarker(input, index);
      if (marker == null) {
        spans.add(TextSpan(text: input.substring(index), style: style));
        break;
      }

      if (marker.start > index) {
        spans.add(
          TextSpan(text: input.substring(index, marker.start), style: style),
        );
      }

      final contentStart = marker.start + marker.token.length;
      final closingIndex = input.indexOf(marker.token, contentStart);
      if (closingIndex == -1) {
        spans.add(TextSpan(text: input.substring(marker.start), style: style));
        break;
      }

      spans.add(TextSpan(text: _hidden(marker.token.length), style: style));

      final inner = input.substring(contentStart, closingIndex);
      final nextStyle = _styleForToken(style, marker.token);
      spans.add(
        TextSpan(
          style: nextStyle,
          children: _parseInline(inner, nextStyle),
        ),
      );

      spans.add(TextSpan(text: _hidden(marker.token.length), style: style));
      index = closingIndex + marker.token.length;
    }

    return spans;
  }

  _Marker? _nextMarker(String input, int from) {
    for (var i = from; i < input.length; i++) {
      if (input.startsWith('**', i)) return _Marker(start: i, token: '**');
      if (input.startsWith('__', i)) return _Marker(start: i, token: '__');
      if (input[i] == '*') return _Marker(start: i, token: '*');
    }
    return null;
  }

  TextStyle _styleForToken(TextStyle style, String token) {
    switch (token) {
      case '**':
        return style.copyWith(fontWeight: FontWeight.w700);
      case '__':
        return style.copyWith(decoration: TextDecoration.underline);
      case '*':
        return style.copyWith(fontStyle: FontStyle.italic);
    }
    return style;
  }

  String _hidden(int length) => List.filled(length, _hiddenChar).join();
}

class _ResolvedLine {
  const _ResolvedLine({required this.text, required this.style});

  final String text;
  final TextStyle style;
}

class _Marker {
  const _Marker({required this.start, required this.token});

  final int start;
  final String token;
}
