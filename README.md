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
| History | **Annual** or **Quarterly**, chosen with a tab: up to ten fiscal years or the last eight quarters, line by line. An eight-column table where all of it fits, one card per period below that. Sortable, newest first by default. |
| All tickers | The whole EDGAR directory, filterable by symbol or company name and **sortable** by name or by growth; picking one loads its report. |

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

The ingest also fetches `company_tickers.json` (795 KB) first, because the bulk
archive carries **no ticker symbols at all** — its payloads hold only `cik`,
`entityName` and `facts`, and its files are named by CIK. That mapping is stored
in the database alongside the figures, so nothing is bundled with the app and
the symbol list is as current as the last ingest. `submissions.zip` is the only
bulk file that carries tickers, and at 1.5 GB it is a poor trade for 795 KB.

So: two requests, ~1.4 GB, once. After that the only network call is one HEAD
request per launch — SEC serves the archive with a `Last-Modified` header, so the
date of the loaded archive is stored with the ingest and compared against the
published one. An **Update available** button appears only when SEC has actually
rebuilt it; the archive changes every few days at most, and a permanently
visible refresh invites a pointless 1.4 GB download.

The download is a **blocking full-screen step** — there is no ticker directory
to search and no figures to report without it, and a refresh clears the tables
before repopulating them, so the gate blocks then too.

The panel shows a large progress ring with the percentage counting up, the three
stages as a live timeline (ticked when done, pulsing when running, dimmed until
reached), and a stats line with what is done, current throughput and an
estimated time remaining. Before the download starts the same stage list is
shown inert, so the shape of the job is clear before committing to 1.4 GB.

Loading is the slow stage — roughly two minutes of JSON decoding for 19 GB —
so it runs on background isolates, a slice of filers at a time, and the entry
count is read from the archive's central directory up front so the bar shows a
true fraction rather than a spinner.

### Browsing and ranking the directory

`/browse` is a **master–detail** view above 1000px: the list on the left, the
selected company's report on the right, so switching company swaps only the
report. Below that width the list takes the whole window and picking a company
returns to the report.

A **sector row** filters by industry. SEC classifies filers with Standard
Industrial Classification codes — the only category it publishes — exposed per
filer in `submissions`, and in bulk in the quarterly
[financial statement data sets](https://www.sec.gov/data-research/sec-markets-data/financial-statement-data-sets).
The ingest pulls the four most recent quarters (~60 MB each) rather than the
only other bulk file that carries SIC, `submissions.zip`, at 1.5 GB. SIC has
some 440 codes at a granularity a filter row cannot use
("Semiconductors & Related Devices"), so `SicSector` groups them into twelve
recognisable sectors; against real data that classifies **96.7%** of filers, and
the rest — agriculture, public administration — simply match no chip. The row
hides itself when nothing is classified, which is what an older database looks
like until the next ingest.

`/browse` lists every symbol as square tiles — symbol, company name over up to
three lines, and the ranked figure at the foot — which fits seven columns on a
wide window and three on a phone. It is filterable by symbol or company name and
sortable by name (case-insensitively) or by growth: revenue over 1, 2, 3, 5 or
10 years, or free cash flow over the last year. Each tile shows the figure it is
ranked on — the growth rate, or the latest revenue when the list is
alphabetical. Ordering, filter and scroll position survive opening a company and
coming back.

The search field on the report suggests matches as you type — symbol or company
name — so there is no submit button: pick a suggestion, or press enter to take
the best match.

Multi-year windows are **compound annual growth rates**, not the arithmetic mean
of each year's growth: doubling over three years reads as 26% a year rather than
33%, which is the standard measure and is not thrown off by one spiky year.

A rate is only quoted where it means something:

* Both ends of the window must be present, and beyond one year both must be
  positive — there is no real annual rate from a loss to a profit.
* The base must clear `minimumGrowthBase` (currently $1m). A shell company going
  from $8,000 of revenue to $97m is arithmetically a 10,000% annual rate and
  tells you nothing; without the floor those companies head every ranking.
* The window ends at the company's **latest fiscal year** — the same one the
  report headlines — not the latest year that happens to carry a figure, so the
  list and the report never disagree about which year they are talking about.

Companies that cannot be ranked sort last and show `—`. Growth is computed in
SQL, once per ordering, because ranking ten thousand companies otherwise means
pulling every fiscal year they have into memory.

### Why drift

It is the only mature typed-SQL layer covering macOS, Linux, Android and iOS
from one codebase. `sqflite` alone declares no Linux support; `hive` and `isar`
have not shipped since 2022 and 2023. `sqlite3` 3.x bundles the native library
(it replaced the now end-of-life `sqlite3_flutter_libs`).

`extractorVersion` in `app_database.dart` is stamped on every ingest. Bump it
when the XBRL extraction changes meaning, and rows written by the old code are
treated as absent rather than served as if correct.

### Quarterly figures

Quarters come from 10-Qs, with two wrinkles. A 10-Q restates earlier periods as
comparatives and also files the year-to-date total, so only the newest
three-month period in each filing is taken — the one its `fy`/`fp` describe.

And **the fourth quarter is generally never filed**: recent 10-Ks carry only
annual durations. So Q4's flow lines are derived as the full year less the
first three quarters, while its balance-sheet lines are taken as filed, since a
year-end instant *is* the closing position. Verified against NVIDIA: derived Q4
FY2026 revenue of $68,127M and Q4 FY2025 of $39,331M both match what NVIDIA
reported. The UI states this in a footnote when the quarterly tab is open.

Cash-flow lines are commonly filed year-to-date rather than per quarter, so
free cash flow shows `n/a` for many quarters rather than a wrong number.

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
```

Architecture follows [the project constitution](../fluf/doc/CONSTITUTION.md):
MVVM with `provider`, repositories behind `get_it`, sealed classes for screen
state, enhanced enums carrying their own presentation, every string in the ARB
bundle, and `Row`/`Column`'s `spacing` rather than spacer widgets.

Figures come from 10-K filings only, in USD. A sanity check on the shape of the
numbers — not investment advice.

**Net debt** is total borrowings less cash, so it is *negative* when a company
holds more cash than it owes. The table shows that sign directly; the highlight
card instead heads itself `Net cash` or `Net debt` and shows the amount unsigned,
because `Net cash −$2.14B` reads as a contradiction.
