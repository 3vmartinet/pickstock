import 'package:get_it/get_it.dart';
import 'package:pickstock/repo/format_repo.dart';
import 'package:pickstock/repo/market/market_rates_repo.dart';
import 'package:pickstock/repo/price_repo.dart';
import 'package:pickstock/repo/quote/finnhub_quote_repo.dart';
import 'package:pickstock/repo/quote/quote_repo.dart';
import 'package:pickstock/repo/sec/mock_sec_repo.dart';
import 'package:pickstock/repo/db/app_database.dart';
import 'package:pickstock/repo/sec/bulk_ingest_repo.dart';
import 'package:pickstock/repo/sec/local_sec_repo.dart';
import 'package:pickstock/repo/sec/sec_repo.dart';
import 'package:pickstock/repo/sec/ticker_directory_repo.dart';
import 'package:pickstock/repo/report/report_repo.dart';
import 'package:pickstock/repo/settings/settings_repo.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/repo/watchlist/watchlist_repo.dart';

/// Run with `--dart-define=PICKSTOCK_MOCK_DATA=true` to drive the UI from the
/// canned fixture instead of the live EDGAR API.
const bool usesMockData = bool.fromEnvironment('PICKSTOCK_MOCK_DATA');

/// The one place every dependency is wired up.
abstract final class DependenciesRepo {
  static void register() {
    GetIt.I
      ..registerLazySingleton<ThemeRepo>(ThemeRepo.new)
      ..registerLazySingleton<FormatRepo>(FormatRepo.new)
      ..registerLazySingleton<TickerDirectoryRepo>(TickerDirectoryRepo.new)
      ..registerLazySingleton<AppDatabase>(AppDatabase.new)
      ..registerLazySingleton<BulkIngestRepo>(BulkIngestRepo.new)
      ..registerLazySingleton<SecRepo>(
        () => usesMockData ? const MockSecRepo() : const LocalSecRepo(),
      )
      ..registerLazySingleton<PriceRepo>(
        () => usesMockData ? MemoryPriceRepo() : const LocalPriceRepo(),
      )
      ..registerLazySingleton<QuoteRepo>(FinnhubQuoteRepo.new)
      ..registerLazySingleton<MarketRatesRepo>(
        () => usesMockData
            ? const UnavailableMarketRatesRepo()
            : LiveMarketRatesRepo(),
      )
      ..registerLazySingleton<WatchlistRepo>(LocalWatchlistRepo.new)
      ..registerLazySingleton<ReportRepo>(LocalReportRepo.new)
      ..registerLazySingleton<SettingsRepo>(
        () => usesMockData ? MemorySettingsRepo() : LocalSettingsRepo(),
      );
  }
}
