import 'package:intl/intl.dart';

const int _dollarsPerMillion = 1000000;
const String _plusSign = '+';
const String _millionsPattern = '#,##0';
const String _percentPattern = '0.0';
const String _currencySymbol = r'$';

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

  /// Accounting-style millions: negatives are parenthesised rather than
  /// signed, e.g. `(62,723)`.
  String parenthesisedMillions(double dollars) {
    final value = dollars / _dollarsPerMillion;
    if (value >= 0) return _millions.format(value);
    return '(${_millions.format(value.abs())})';
  }

  /// A headline figure, e.g. `$416.2B`.
  String compactCurrency(double dollars) => _compactCurrency.format(dollars);

  /// A headline figure with the sign dropped, for use next to a label that
  /// already says whether it is debt or cash.
  String compactCurrencyMagnitude(double dollars) =>
      _compactCurrency.format(dollars.abs());

  /// A growth rate, always signed, e.g. `+6.4%` or `-2.8%`.
  String signedPercent(double value) {
    final sign = value >= 0 ? _plusSign : '';
    return '$sign${_percent.format(value)}%';
  }
}
