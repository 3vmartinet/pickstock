import 'package:intl/intl.dart';

const int _dollarsPerMillion = 1000000;
const String _plusSign = '+';
const String _millionsPattern = '#,##0';
const String _percentPattern = '0.0';
const String _currencySymbol = r'$';

/// Byte scales, largest first, with how many decimals each deserves.
const List<({int threshold, int digits, String suffix})> _byteUnits = [
  (threshold: 1073741824, digits: 2, suffix: 'GB'),
  (threshold: 1048576, digits: 0, suffix: 'MB'),
  (threshold: 1024, digits: 0, suffix: 'kB'),
  (threshold: 1, digits: 0, suffix: 'B'),
];

/// Every number the user sees is formatted here, so the same figure never
/// renders two different ways in two different widgets.
class FormatRepo {
  final NumberFormat _millions = NumberFormat(_millionsPattern);
  final NumberFormat _percent = NumberFormat(_percentPattern);

  /// Compact notation keeps three significant digits, so a headline reads
  /// `$416B` next to `$62.7B` rather than padding both to the same decimals.
  final NumberFormat _compactCurrency = NumberFormat.compactCurrency(
    symbol: _currencySymbol,
  );

  /// Whole dollars rendered as millions, e.g. `383,285`.
  String millions(double dollars) =>
      _millions.format(dollars / _dollarsPerMillion);

  /// A headline figure, e.g. `$416.2B`.
  String compactCurrency(double dollars) => _compactCurrency.format(dollars);

  /// A headline figure with the sign dropped, for use next to a label that
  /// already says whether it is debt or cash.
  String compactCurrencyMagnitude(double dollars) =>
      _compactCurrency.format(dollars.abs());

  /// A byte count at human scale, e.g. `412 MB` or `1.41 GB`.
  String bytes(num value) {
    for (final unit in _byteUnits) {
      if (value >= unit.threshold) {
        return '${(value / unit.threshold).toStringAsFixed(unit.digits)} '
            '${unit.suffix}';
      }
    }
    return '${value.round()} ${_byteUnits.last.suffix}';
  }

  /// A growth rate, always signed, e.g. `+6.4%` or `-2.8%`.
  String signedPercent(double value) {
    final sign = value >= 0 ? _plusSign : '';
    return '$sign${_percent.format(value)}%';
  }
}
