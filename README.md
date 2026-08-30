# PickStock

A quick pre-investment sanity check on any US-listed company, sourced from SEC
EDGAR's XBRL *company facts*: revenue growth, profitability, free cash flow, and
whether the company holds more cash than debt — for the last ten fiscal years.

Enter a ticker, get a report. No API key, no account, and after the initial
download, no network.

## What it shows

| Block | Content |
| --- | --- |
| Sanity check | Three yes/no questions about the most recent fiscal year: revenue growing, profitable, more cash than debt. |
| Highlights | Revenue, net income, free cash flow and net debt/(cash) for the latest year, each with its year-over-year move. |
| History | Up to ten fiscal years, line by line — an eight-column table where all of it fits, one card per year below that. Sortable by year, newest first by default. |
| All tickers | The whole EDGAR directory, filterable by symbol or company name; picking one loads its report. |

## Platforms

macOS and Linux. The stack (drift/SQLite) also covers Android and iOS, so
`flutter create --platforms=android,ios .` is all those would need. **Web is not
supported** — the browser cannot call EDGAR at all (no CORS headers, and a
required `User-Agent` that scripts are forbidden to set), and a 1.4 GB bulk
ingest has no place in a tab.

## Data: one download, then local

Everything the app reports comes from SEC's bulk archive:

* `companyfacts.zip` — **1.4 GB**, 20,290 filers, ~19 GB of JSON once expanded.
* Streamed to a temp file, read one entry at a time, parsed, and written into a
  local SQLite database. The archive is deleted afterwards.
* One request instead of twenty thousand, which is what SEC's fair-use guidance
  ([10 requests/second](https://www.sec.gov/search-filings/edgar-search-assistance/accessing-edgar-data))
  asks for.

Press **Download SEC data** in the app bar to populate it. After that the app
makes no network calls at all.

`assets/sec/company_tickers.json` stays bundled: it maps symbols to CIKs, which
the bulk archive doesn't carry — its files are named by CIK only.

### Why drift

It is the only mature typed-SQL layer covering macOS, Linux, Android and iOS
from one codebase. `sqflite` alone declares no Linux support; `hive` and `isar`
have not shipped since 2022 and 2023. `sqlite3` 3.x bundles the native library
(it replaced the now end-of-life `sqlite3_flutter_libs`).

`extractorVersion` in `app_database.dart` is stamped on every ingest. Bump it
when the XBRL extraction changes meaning, and rows written by the old code are
treated as absent rather than served as if correct.

### Fiscal-year attribution

A fact's `fy` is the fiscal year of the **filing**, not of the value: a 10-K
restates the two years before it, and a 10-K also carries quarterly facts. So
facts are grouped by filing, ordered by period end, and the newest in each
filing takes that filing's `fy` while the comparatives beneath take `fy - 1` and
`fy - 2`. Durations outside 330–400 days are discarded. Reading `fy` directly
reports a prior year's figure — or a quarter — under the wrong heading.

## Running it

The Flutter SDK is managed by [fvm](https://fvm.app) and tracked to the `stable`
channel in `.fvmrc`, so no version is pinned. Run `fvm install` once, then:

```shell
fvm flutter run -d macos     # or -d linux
```

`--dart-define=PICKSTOCK_MOCK_DATA=true` swaps the database for a fixture
carrying Apple's filed figures, which is what most widget tests run against.

macOS is sandboxed: `com.apple.security.network.client` is set in both
entitlements files, without which the bulk download fails silently.

## Layout

```
lib/
  data/          Immutable models and the enums that describe them
  repo/
    db/          drift schema and generated code
    sec/         Bulk ingest, XBRL parsing, database-backed reads
  ui/            Screens, view models and widgets
  l10n/          ARB bundle and the generated AppLocalizations
assets/
  sec/           Bundled snapshot of EDGAR's ticker directory
```

Architecture follows [the project constitution](../fluf/doc/CONSTITUTION.md):
MVVM with `provider`, repositories behind `get_it`, sealed classes for screen
state, enhanced enums carrying their own presentation, every string in the ARB
bundle, and `Row`/`Column`'s `spacing` rather than spacer widgets.

Figures come from 10-K filings only, in USD. Parenthesised values are negative
(a net cash position). A sanity check on the shape of the numbers — not
investment advice.
