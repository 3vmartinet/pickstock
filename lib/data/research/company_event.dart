import 'package:equatable/equatable.dart';

/// Something that happened to a company, with the page it was read on.
///
/// Not only the results: a filer's own quarter is one kind of development and
/// a lawsuit, a launch or a change of chief executive is another, and a reader
/// deciding whether to buy needs both. What the model is asked for is the
/// three most recent that would matter to an investor.
class CompanyEvent extends Equatable {
  const CompanyEvent({required this.caption, required this.url, this.date});

  /// One line, as the model wrote it.
  final String caption;

  /// The page it came from — checked against what the search actually
  /// returned, since this is what opens in a browser when clicked.
  final String url;

  /// When it happened. `null` where the page did not say, which is worth
  /// showing without a date rather than dropping.
  final DateTime? date;

  @override
  List<Object?> get props => [caption, url, date];
}
