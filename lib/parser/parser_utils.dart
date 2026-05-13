/// Shared utilities for all label parsers.
library;

/// Parse the first decimal or integer number from a string.
/// Handles full-width digits (Japanese OCR artefacts) and commas.
double? parseNumber(String? text) {
  if (text == null || text.isEmpty) return null;
  // Normalise full-width digits → ASCII
  final normalised = text.replaceAllMapped(RegExp(r'[０-９]'), (m) {
    return String.fromCharCode(m.group(0)!.codeUnitAt(0) - 0xFF10 + 0x30);
  }).replaceAll(',', ''); // remove thousands separator
  final m = RegExp(r'\d+(?:\.\d+)?').firstMatch(normalised);
  return m != null ? double.tryParse(m.group(0)!) : null;
}
