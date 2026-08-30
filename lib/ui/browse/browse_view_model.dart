import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/data/snapshot/company.dart';
import 'package:pickstock/repo/sec/ticker_directory_repo.dart';

TickerDirectoryRepo get _tickerDirectoryRepo =>
    GetIt.I.get<TickerDirectoryRepo>();

/// Drives the browsable list of every symbol EDGAR knows about.
///
/// The directory is already parsed and held by [TickerDirectoryRepo], so
/// filtering is a pass over an in-memory list; results are recomputed only
/// when the query actually changes rather than on every rebuild.
class BrowseViewModel extends ChangeNotifier {
  BrowseViewModel() : _results = _tickerDirectoryRepo.allCompanies;

  final TextEditingController filterController = TextEditingController();

  String _query = '';
  String get query => _query;

  List<Company> _results;

  /// Companies matching [query], best symbol matches first.
  List<Company> get results => _results;

  /// How many symbols the directory holds in total.
  int get totalCount => _tickerDirectoryRepo.tickerCount;

  int get resultCount => _results.length;

  bool get hasResults => _results.isNotEmpty;

  /// Whether the list is currently narrowed by a query.
  bool get isFiltered => _query.isNotEmpty;

  void setQuery(String query) {
    final trimmed = query.trim();
    if (trimmed == _query) return;
    _query = trimmed;
    _results = _tickerDirectoryRepo.search(trimmed);
    notifyListeners();
  }

  /// The company at [index] of the current results, or `null` once the list
  /// has shrunk past it.
  Company? companyAt(int index) =>
      index >= 0 && index < _results.length ? _results[index] : null;

  @override
  void dispose() {
    filterController.dispose();
    super.dispose();
  }
}
