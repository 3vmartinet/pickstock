import 'package:intl/intl.dart';

const int _dollarsPerMillion = 1000000;
const String _plusSign = '+';
const String _millionsPattern = '#,##0';
const String _percentPattern = '0.0';
const String _timePattern = 'HH:mm';
const String _dateTimePattern = 'd MMM HH:mm';
const String _shortDatePattern = 'd MMM';
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
  final NumberFormat _compactCount = NumberFormat.compact();
  final DateFormat _time = DateFormat(_timePattern);
  final DateFormat _dateTime = DateFormat(_dateTimePattern);
  final DateFormat _shortDate = DateFormat(_shortDatePattern);
  final NumberFormat _price = NumberFormat.currency(
    symbol: _currencySymbol,
    decimalDigits: 2,
  );

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

  /// A day on its own, for a figure published once a day: `2 Sep`.
  String shortDate(DateTime day) => _shortDate.format(day.toLocal());

  /// When a price was true, as short as it can be while staying unambiguous:
  /// `14:20` for today, `31 Aug 14:20` for anything older.
  String timeOrDate(DateTime moment) {
    final local = moment.toLocal();
    final now = DateTime.now();
    final isToday =
        local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    return isToday ? _time.format(local) : _dateTime.format(local);
  }

  /// A rough remaining time, e.g. `12m` or `45s`. Rounded up to the minute
  /// past a minute: a scan measured in tens of minutes gains nothing from a
  /// seconds digit that changes while you read it.
  String duration(Duration remaining) {
    if (remaining.inMinutes < 1) return '${remaining.inSeconds}s';
    return '${(remaining.inSeconds / 60).ceil()}m';
  }

  /// A plain count at human scale, e.g. `24.1B` shares.
  String compactCount(double value) => _compactCount.format(value);

  /// A rate without a forced sign, e.g. `6.4%`.
  String percent(double value) => '${_percent.format(value)}%';

  /// A multiple, e.g. `24.8`. Ratios past three digits are rounded whole:
  /// the difference between 412.3 and 412 times earnings is not a difference.
  String ratio(double value) =>
      value.abs() >= 100 ? value.round().toString() : _percent.format(value);

  /// A price per share, e.g. `$182.40`.
  String price(double value) => _price.format(value);

  /// A growth rate, always signed, e.g. `+6.4%` or `-2.8%`.
  String signedPercent(double value) {
    final sign = value >= 0 ? _plusSign : '';
    return '$sign${_percent.format(value)}%';
  }
}
