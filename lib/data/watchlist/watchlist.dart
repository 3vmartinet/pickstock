import 'package:equatable/equatable.dart';

/// A named list of companies the user follows.
class Watchlist extends Equatable {
  const Watchlist({
    required this.id,
    required this.name,
    required this.colourIndex,
    required this.isDefault,
    this.companyCount = 0,
  });

  final int id;
  final String name;

  /// An index into the palette in `ThemeRepo`.
  final int colourIndex;

  /// The starred list. It cannot be deleted, and the star on a report toggles
  /// membership of this one.
  final bool isDefault;

  /// How many companies are in it.
  final int companyCount;

  Watchlist withCount(int count) => Watchlist(
    id: id,
    name: name,
    colourIndex: colourIndex,
    isDefault: isDefault,
    companyCount: count,
  );

  @override
  List<Object?> get props => [id, name, colourIndex, isDefault, companyCount];
}
