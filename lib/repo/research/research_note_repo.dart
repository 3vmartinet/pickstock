import 'package:get_it/get_it.dart';
import 'package:pickstock/data/research/company_event.dart';
import 'package:pickstock/repo/db/app_database.dart';
import 'package:pickstock/repo/research/web_search_repo.dart';

AppDatabase get _database => GetIt.I.get<AppDatabase>();

/// A stored answer, and when it was arrived at.
///
/// The age is the point: a reader coming back to a company needs to know
/// whether they are looking at this morning's reading or last month's, and a
/// month-old answer about a company's news is worth re-asking.
class ResearchNote {
  const ResearchNote({
    required this.generatedAt,
    this.text,
    this.sources = const [],
    this.events = const [],
  });

  final DateTime generatedAt;

  /// The prose of an insight. Null for the news, which is only its lines.
  final String? text;

  /// The pages an insight was read from.
  final List<SearchResult> sources;

  /// The developments, where the note is the news.
  final List<CompanyEvent> events;
}

/// Keeps what a model has said, so it is not asked twice.
///
/// An interface so a test can hold notes in memory rather than reaching for a
/// database it does not need.
abstract interface class ResearchNoteRepo {
  /// What is on file for [cik] under [kind], or `null` if nothing is.
  Future<ResearchNote?> noteFor(String cik, String kind);

  /// Stores an insight: its prose and the pages behind it.
  Future<void> saveAnswer({
    required String cik,
    required String kind,
    required String text,
    required List<SearchResult> sources,
  });

  /// Stores the news: developments, each with the page it was read on.
  Future<void> saveEvents({
    required String cik,
    required String kind,
    required List<CompanyEvent> events,
  });

  /// Forgets it, which is what a reader asking for it again means.
  Future<void> clear(String cik, String kind);
}

class LocalResearchNoteRepo implements ResearchNoteRepo {
  const LocalResearchNoteRepo();

  @override
  Future<ResearchNote?> noteFor(String cik, String kind) async {
    final stored = await _database.researchNote(cik, kind);
    if (stored == null) return null;
    final (note, lines) = stored;

    // A note with prose is an insight and its lines are citations; one without
    // is the news and its lines are the developments themselves.
    final isAnswer = note.body != null;
    return ResearchNote(
      generatedAt: note.generatedAt,
      text: note.body,
      sources: [
        if (isAnswer)
          for (final line in lines)
            SearchResult(title: line.label, url: line.url, content: ''),
      ],
      events: [
        if (!isAnswer)
          for (final line in lines)
            CompanyEvent(
              caption: line.label,
              url: line.url,
              date: line.happenedAt,
            ),
      ],
    );
  }

  @override
  Future<void> saveAnswer({
    required String cik,
    required String kind,
    required String text,
    required List<SearchResult> sources,
  }) {
    // The page text itself is not kept: it runs to hundreds of thousands of
    // characters, the answer above is what it was read for, and the link is
    // there for anyone who wants the rest.
    return _database.saveResearchNote(
      cik: cik,
      kind: kind,
      generatedAt: DateTime.now(),
      body: text,
      lines: [
        for (final source in sources)
          (
            label: source.title.isEmpty ? source.url : source.title,
            url: source.url,
            happenedAt: null,
          ),
      ],
    );
  }

  @override
  Future<void> saveEvents({
    required String cik,
    required String kind,
    required List<CompanyEvent> events,
  }) {
    return _database.saveResearchNote(
      cik: cik,
      kind: kind,
      generatedAt: DateTime.now(),
      // Deliberately null: it is what tells a restored note apart from an
      // insight when it is read back.
      lines: [
        for (final event in events)
          (label: event.caption, url: event.url, happenedAt: event.date),
      ],
    );
  }

  @override
  Future<void> clear(String cik, String kind) =>
      _database.clearResearchNote(cik, kind);
}

/// Remembers nothing beyond the run, for the mock build and for tests with no
/// database.
class MemoryResearchNoteRepo implements ResearchNoteRepo {
  final Map<String, ResearchNote> _notes = {};

  String _key(String cik, String kind) => '$cik/$kind';

  @override
  Future<ResearchNote?> noteFor(String cik, String kind) async =>
      _notes[_key(cik, kind)];

  @override
  Future<void> saveAnswer({
    required String cik,
    required String kind,
    required String text,
    required List<SearchResult> sources,
  }) async => _notes[_key(cik, kind)] = ResearchNote(
    generatedAt: DateTime.now(),
    text: text,
    sources: sources,
  );

  @override
  Future<void> saveEvents({
    required String cik,
    required String kind,
    required List<CompanyEvent> events,
  }) async => _notes[_key(cik, kind)] = ResearchNote(
    generatedAt: DateTime.now(),
    events: events,
  );

  @override
  Future<void> clear(String cik, String kind) async =>
      _notes.remove(_key(cik, kind));
}
