import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/data/research/company_event.dart';
import 'package:pickstock/repo/db/app_database.dart';
import 'package:pickstock/repo/research/research_note_repo.dart';
import 'package:pickstock/repo/research/web_search_repo.dart';

const String _cik = '0000320193';

void main() {
  late AppDatabase database;
  late ResearchNoteRepo repo;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    database = AppDatabase.forTesting(NativeDatabase.memory());
    GetIt.I.registerSingleton<AppDatabase>(database);
    repo = const LocalResearchNoteRepo();
  });

  tearDown(() async {
    await database.close();
    await GetIt.I.reset();
  });

  test('nothing is on file until something is asked', () async {
    expect(await repo.noteFor(_cik, 'business'), isNull);
  });

  test('an answer comes back with its pages, in order', () async {
    await repo.saveAnswer(
      cik: _cik,
      kind: 'business',
      text: 'Apple sells consumer hardware and services attached to it.',
      sources: const [
        SearchResult(title: 'Form 10-K', url: 'https://sec.gov/a', content: ''),
        SearchResult(
          title: 'Newsroom',
          url: 'https://apple.com/b',
          content: '',
        ),
      ],
    );

    final note = await repo.noteFor(_cik, 'business');
    expect(note!.text, startsWith('Apple sells'));
    // The order the model gave them in survives the round trip.
    expect(note.sources.map((source) => source.title), [
      'Form 10-K',
      'Newsroom',
    ]);
    expect(note.sources.first.url, 'https://sec.gov/a');
    // An insight has no developments; that is what tells the two apart.
    expect(note.events, isEmpty);
    expect(
      note.generatedAt.isAfter(
        DateTime.now().subtract(const Duration(minutes: 1)),
      ),
      isTrue,
    );
  });

  test('the news comes back with its dates', () async {
    await repo.saveEvents(
      cik: _cik,
      kind: 'events',
      events: [
        CompanyEvent(
          caption: 'Settles Siri class action',
          url: 'https://apnews.com/a',
          date: DateTime(2026, 9, 2),
        ),
        const CompanyEvent(
          caption: 'Undated development',
          url: 'https://example.com/b',
        ),
      ],
    );

    final note = await repo.noteFor(_cik, 'events');
    expect(note!.text, isNull);
    expect(note.events, hasLength(2));
    expect(note.events.first.date, DateTime(2026, 9, 2));
    // A page that did not say when comes back saying so, rather than dated to
    // whenever it was read.
    expect(note.events.last.date, isNull);
    expect(note.sources, isEmpty);
  });

  test('asking again replaces what was there', () async {
    await repo.saveAnswer(
      cik: _cik,
      kind: 'business',
      text: 'first',
      sources: const [
        SearchResult(title: 'a', url: 'https://a', content: ''),
        SearchResult(title: 'b', url: 'https://b', content: ''),
      ],
    );
    await repo.saveAnswer(
      cik: _cik,
      kind: 'business',
      text: 'second',
      sources: const [SearchResult(title: 'c', url: 'https://c', content: '')],
    );

    final note = await repo.noteFor(_cik, 'business');
    expect(note!.text, 'second');
    // The old pages go with the old answer rather than accumulating under it.
    expect(note.sources.map((source) => source.title), ['c']);
  });

  test('one question is not another, and one company is not another', () async {
    await repo.saveAnswer(
      cik: _cik,
      kind: 'business',
      text: 'about the business',
      sources: const [],
    );

    expect(await repo.noteFor(_cik, 'inputs'), isNull);
    expect(await repo.noteFor('0001045810', 'business'), isNull);
    expect((await repo.noteFor(_cik, 'business'))!.text, 'about the business');
  });

  test('clearing forgets it', () async {
    await repo.saveAnswer(
      cik: _cik,
      kind: 'business',
      text: 'x',
      sources: const [SearchResult(title: 'a', url: 'https://a', content: '')],
    );
    await repo.clear(_cik, 'business');

    expect(await repo.noteFor(_cik, 'business'), isNull);
    // And its pages went with it rather than being left behind.
    expect(
      await database
          .customSelect('SELECT COUNT(*) AS n FROM research_note_lines')
          .getSingle()
          .then((row) => row.read<int>('n')),
      0,
    );
  });

  test('an ingest leaves the notes alone', () async {
    await repo.saveAnswer(
      cik: _cik,
      kind: 'business',
      text: 'kept',
      sources: const [],
    );

    // The notes are about companies rather than read out of the archive, and
    // throwing them away with the figures would cost a minute of a local
    // model each to get back.
    await database.clearFinancials();

    expect((await repo.noteFor(_cik, 'business'))!.text, 'kept');
  });
}
