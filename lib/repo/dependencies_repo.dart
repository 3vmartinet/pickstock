import 'package:drift/native.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/repo/format_repo.dart';
import 'package:pickstock/repo/price_repo.dart';
import 'package:pickstock/repo/quote/bulk_price_refresh.dart';
import 'package:pickstock/repo/quote/bulk_price_repo.dart';
import 'package:pickstock/repo/quote/finnhub_quote_repo.dart';
import 'package:pickstock/repo/quote/quote_repo.dart';
import 'package:pickstock/repo/research/ollama_repo.dart';
import 'package:pickstock/repo/research/research_note_repo.dart';
import 'package:pickstock/repo/research/local_first_search_repo.dart';
import 'package:pickstock/repo/research/web_search_repo.dart';
import 'package:pickstock/repo/sec/mock_sec_repo.dart';
import 'package:pickstock/repo/db/app_database.dart';
import 'package:pickstock/repo/sec/bulk_ingest_repo.dart';
import 'package:pickstock/repo/sec/local_sec_repo.dart';
import 'package:pickstock/repo/sec/sec_repo.dart';
import 'package:pickstock/repo/sec/ticker_directory_repo.dart';
import 'package:pickstock/repo/report/report_repo.dart';
import 'package:pickstock/repo/settings/settings_repo.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/report/research_queue.dart';
import 'package:pickstock/repo/watchlist/watchlist_repo.dart';

/// Run with `--dart-define=PICKSTOCK_MOCK_DATA=true` to drive the UI from the
/// canned fixture instead of the live EDGAR API.
///
/// Nothing on disk is opened in that mode: the database is held in memory, so
/// the lists, the saved scans and the browse filters all work against tables
/// that start empty and vanish with the app, and a fixture run can never
/// migrate, seed or write the real `pickstock.sqlite`.
const bool usesMockData = bool.fromEnvironment('PICKSTOCK_MOCK_DATA');

/// The one place every dependency is wired up.
abstract final class DependenciesRepo {
  static void register() {
    GetIt.I
      ..registerLazySingleton<ThemeRepo>(ThemeRepo.new)
      ..registerLazySingleton<FormatRepo>(FormatRepo.new)
      ..registerLazySingleton<TickerDirectoryRepo>(TickerDirectoryRepo.new)
      // In memory rather than a second set of repos: the watchlists, the
      // saved reports and the browse filters all read the same tables, and
      // one empty database covers every one of them — including the screens
      // that query it directly — where a mock per repo would leave whichever
      // was forgotten writing to the real file.
      ..registerLazySingleton<AppDatabase>(
        () => usesMockData
            ? AppDatabase.forTesting(NativeDatabase.memory())
            : AppDatabase(),
      )
      ..registerLazySingleton<BulkIngestRepo>(BulkIngestRepo.new)
      ..registerLazySingleton<SecRepo>(
        () => usesMockData ? const MockSecRepo() : const LocalSecRepo(),
      )
      ..registerLazySingleton<PriceRepo>(
        () => usesMockData ? MemoryPriceRepo() : const LocalPriceRepo(),
      )
      ..registerLazySingleton<QuoteRepo>(FinnhubQuoteRepo.new)
      ..registerLazySingleton<BulkPriceRepo>(
        () => usesMockData
            ? const UnavailableBulkPriceRepo()
            : MassiveBulkPriceRepo(),
      )
      ..registerLazySingleton<BulkPriceRefresh>(BulkPriceRefresh.new)
      ..registerLazySingleton<ResearchNoteRepo>(
        () => usesMockData
            ? MemoryResearchNoteRepo()
            : const LocalResearchNoteRepo(),
      )
      ..registerLazySingleton<WebSearchRepo>(LocalFirstSearchRepo.new)
      ..registerLazySingleton<OllamaRepo>(
        () => OllamaRepo(search: GetIt.I.get<WebSearchRepo>()),
      )
      // App-level rather than screen-level: a question to the local model
      // takes about a minute and the reader will have moved on well before it
      // is answered.
      ..registerLazySingleton<ResearchQueue>(ResearchQueue.new)
      ..registerLazySingleton<WatchlistRepo>(LocalWatchlistRepo.new)
      ..registerLazySingleton<ReportRepo>(LocalReportRepo.new)
      ..registerLazySingleton<SettingsRepo>(
        () => usesMockData ? MemorySettingsRepo() : LocalSettingsRepo(),
      );
  }
}
