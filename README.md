# PickStock

A quick pre-investment sanity check on any US-listed company, sourced from SEC
EDGAR's XBRL *company facts*: revenue growth, profitability, free cash flow, and
whether the company holds more cash than debt — for the last ten fiscal years.

Enter a ticker, get a report. After the initial download the filings are local
and need no network. A free Finnhub key adds live share prices for the valuation
— without one, the price is typed in and everything else works unchanged.

## What it shows

The report has two tabs — **Overview** and **Valuation** — under a fixed company
header. In one column it ran to 3,445 pixels once a price arrived: nearly four
screens on a laptop, with the figures table below all of it, and the whole page
growing by 2,220 pixels the moment a quote landed.

The valuation is what made it unreadable, so that is what moved. The filings —
sanity checks, highlights and the history table — are a fixed 1,174 pixels and
stay together on the overview, where the table sits with the summary of it. The
valuation grows from 424 to 2,644 pixels when a price lands and no longer drags
anything with it.

The tab bar uses `Tabs` with `expand`, so the two share the available width. The
underlined `TabList` sizes each tab to its content, which ran past the right
edge of a narrow window — unreachable, with nothing to say there was more.

| Block | Tab | Content |
| --- | --- | --- |
| Sanity check | Overview | Three yes/no questions about the most recent fiscal year: revenue growing, profitable, more cash than debt. |
| Highlights | Overview | Revenue, net income, free cash flow and net debt/(cash) for the latest year, each with its year-over-year move. |
| History | Overview | **Annual** or **Quarterly**, chosen with a tab: up to ten fiscal years or the last eight quarters, line by line. An eight-column table where all of it fits, one card per period below that. Sortable, newest first by default. |
| Valuation | Valuation | Whether the price is above or below the range the filings support, with the multiples, the cash stream and the growth premium behind it, plus P/E, EV/FCF, FCF yield, PEG and P/S. |
| What the price is asking | Valuation | The growth rate the current price requires, solved out of a reverse DCF, set against the growth the company has actually delivered. |
| How this was worked out | Valuation | The same valuation as a seven-step worked example in plain words, with the company's own numbers in it, beside the cards it explains. |
| All tickers | — | The whole EDGAR directory, filterable by symbol or company name and **sortable** by name or by growth; picking one loads its report. |
| Watchlists | — | Named, colour-coded lists of companies. Star one for the built-in list, or put it in as many of your own as you like, then narrow the directory to a list. |

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

So the first run fetches, in this order:

1. the **ticker directory** (795 KB) — symbols, which the archive has none of;
2. the **industry codes** — up to four quarterly data sets, ~60 MB each;
3. the **bulk archive** (1.4 GB), streamed to disk;
4. then loads it all into SQLite.

Roughly 1.7 GB, once. After that the only network call is one HEAD
request per launch — SEC serves the archive with a `Last-Modified` header, so the
date of the loaded archive is stored with the ingest and compared against the
published one. An **Update available** button appears only when SEC has actually
rebuilt it; the archive changes every few days at most, and a permanently
visible refresh invites a pointless 1.4 GB download.

The download is a **blocking full-screen step** — there is no ticker directory
to search and no figures to report without it, and a refresh clears the tables
before repopulating them, so the gate blocks then too.

The panel shows a large progress ring with the percentage counting up, the four
stages as a live timeline (ticked when done, pulsing when running, dimmed until
reached), and the figures for the running stage — what is done, current
throughput, time remaining — each in its own column under a heading that does
not move. Three changing numbers on one line shoved each other sideways as they
updated; equal columns and a placeholder for a value not yet measured keep
everything still. Before the download starts the same stage list is
shown inert, so the shape of the job is clear before committing to it.

Only the archive is essential. A missing quarterly data set is skipped rather
than failing the ingest — sectors are a nice-to-have, the figures are not.

Loading is the slow stage — roughly two minutes of JSON decoding for 19 GB —
so it runs on background isolates, a slice of filers at a time, and the entry
count is read from the archive's central directory up front so the bar shows a
true fraction rather than a spinner.

### Browsing and ranking the directory

The ticker list **is the app's main screen** — there is no separate search
screen, because the filter above the list is the search and the list is its
results. It is a **master–detail** view above 1000px: the list on the left, the
selected company's report on the right, so switching company swaps only the
report. The divider drags — between 260px and 900px — so widening the list fits
more tile columns without giving up the report beside it. Below the breakpoint
the list takes the whole window and picking a company returns to the report.

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

Tiles are twice as wide as tall: symbol over company name on the left, and the
ranked figure on the right so it lines up down the edge for comparison rather
than sitting under each name. It is filterable by symbol or company name and
sortable by name (case-insensitively) or by growth: revenue over 1, 2, 3, 5 or
10 years, or free cash flow over the last year. Each tile shows the figure it is
ranked on — the growth rate, or the latest revenue when the list is
alphabetical. Ordering, filter and scroll position survive opening a company and
coming back.

The search field sits flush left above the list and filters on symbol or company
name. There is no submit button and no suggestion dropdown: the list is the
result set, and enter opens whatever is at the top of it. Below the master–detail
breakpoint a company gets its own screen, reached by tapping a tile and left via
the back arrow.

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

### Valuation: the one number that is not in EDGAR

EDGAR files financial statements, not quotes, so the share price comes from
[Finnhub](https://finnhub.io) — the only part of PickStock that talks to a
commercial provider, and the only part that needs a key.

**The key is not in this repository.** Copy `env.example.json` to `env.json`,
paste a key, and it reaches the app through `--dart-define-from-file=env.json`
(already wired into every entry in `.vscode/launch.json`). `env.json` is
gitignored. Without a key the app runs exactly as it did before quotes existed:
the price is typed in.

Two things about the free tier, both confirmed against the live endpoint rather
than the documentation:

* **60 calls a minute**, reported in the `x-ratelimit-limit`/`-remaining`
  headers, and 429 beyond it — verified by walking into the wall at call 56.
  `FinnhubQuoteRepo` tracks the budget locally and refuses before asking, so a
  burst of report views cannot get the key throttled.
* **A symbol it does not cover answers `{"c":0}`**, not an error. Zero is read
  as "no price" rather than as free.

Share classes are spelled differently at each end: EDGAR writes `BRK-A`,
Finnhub quotes `BRK.A`. The hyphen is translated on the way out.

A fetched price is stored per company and reused for 15 minutes, so clicking
between companies does not spend the budget and the report still opens with a
price when the network is down.

The price lives in the fair-value gauge rather than in a field of its own: it is
the `Price today` mark, with a refresh control and an explanation beside the
heading, and its provenance in the slot the bounds use for their percentages —
`Last quote · 31 Aug 14:20` rather than passed off as live. Clicking the price
opens an editor to type one, marked `Your price`, because you may know something
the provider does not or simply want to ask what if. Where there is no price at
all the section says why the quote failed and offers the same editor, since the
gauge that normally carries both does not exist yet.

Everything else comes out of the filings:

| Figure | How |
| --- | --- |
| Market value | price × shares outstanding (`dei:EntityCommonStockSharesOutstanding` from the newest filing's cover, falling back to `us-gaap:CommonStockSharesOutstanding`) |
| Enterprise value | market value + net debt, so a company that borrowed to buy its earnings does not look cheap |
| Earnings per share | net income ÷ diluted weighted-average shares, the divisor the company itself reports against |
| Fair range | 12× to 18× the latest year's free cash flow — net income where there is no usable cash flow — **less net debt**, over the share count |
| Growth premium | +0.6 of a turn per point of annualised revenue growth, capped at 25 points, so a fast grower is not called expensive for growing and a 300% year is not extrapolated for a decade |

The band is drawn to scale with the price marked on it, and each bound carries
its own distance from the price — `Range low $93.67, +134.2%` beside `Range
high $133.61, +234.0%`. A single percentage to the midpoint of the range read
as precision it did not have: the midpoint is not something the arithmetic
produces, and it left the reader to work out which bound the number referred
to. The figures under the bar run in value order, so they read left to right in
the same order as the marks above them.

The verdict is where the price falls: below the range is **undervalued**, inside
it **fairly valued**, above it **overvalued**. A company that reports neither a
profit nor free cash flow **cannot be valued** and says so rather than producing
a number; one whose debts exceed the range's own valuation of it bottoms out at
zero.

This is a heuristic, and the report shows its working on purpose — the
multiples, the stream they are struck against and the premium are all on the
card, so the number can be argued with rather than trusted. The five supporting
ratios are there for the same reason: each is coloured by where it falls, and
left blank rather than made meaningless where it cannot be struck (P/E at a
loss, for instance).

`test/live_quote_test.dart` hits Finnhub for real and is skipped unless a key is
built in:

```sh
fvm flutter test --dart-define-from-file=env.json test/live_quote_test.dart
```

**Ranking the whole directory by valuation is not offered.** At 60 calls a
minute, pricing 10,391 companies takes about three hours, so it would have to be
an overnight batch rather than a sort you can click.

### What the app remembers

The theme, the directory's ordering, the sector filter and the chosen list
survive a restart. They live in a key/value `settings` table — one row per
setting, so the next one is not a migration — and like prices and watchlists
they sit out a schema rebuild.

They are read **once in `main`, before `runApp`**, so every getter on
`SettingsRepo` is synchronous and the view models can seed themselves in their
constructors. A view model that awaited its own initial state would render the
default first and the remembered value a frame later: a flash of the wrong
theme, and a list that reorders itself as you look at it.

Two things are deliberately not remembered. The **search text** is typed rather
than chosen, and reopening the app filtered to `aa` with no memory of why would
be a puzzle. A **deleted list** is forgotten rather than restored — the id is
checked against the lists that still exist on the way up, and cleared if it is
gone.

An enum stored by name is read back tolerantly: a value this build no longer has
resets that filter instead of stopping the app from starting.

### Watchlists

Favourites is not a separate mechanism: it is a list like any other, seeded on
first open, sorting first, and undeletable because the star has to have
somewhere to put things. One concept instead of a flag beside a table doing the
same job.

Lists carry a **palette index rather than a colour**, so a list keeps its
identity when the theme changes and the dark variant can differ from the light
one. Membership cascades on delete, with `PRAGMA foreign_keys = ON` set in
`beforeOpen` — SQLite ignores foreign keys by default, and without it a deleted
list would leave its entries behind for ever.

Like entered prices, and unlike everything else in the database, watchlists are
**the user's own data and cannot be downloaded again**, so they sit out a schema
rebuild rather than being dropped with the caches.

They are read with plain futures rather than drift's query streams. Nothing
outside the app writes these tables, so one view model reloading after each of
its own mutations keeps the report, the tiles and the filter in step — and the
streams brought a real cost: drift defers stream updates with `Timer.run`, which
left a pending timer at the end of every widget test.

### The worked example

Beside the verdict, the whole calculation is spelled out in the order it
happens: what buying every share costs, what the company kept last year, what
debt comes with it, how many years of cash that price is, how many years is
fair, and what that makes one share worth. Every step carries the company's own
figures, so it can be checked rather than trusted.

It also carries the caveats that would mislead a reader taking the steps at face
value: capital spending well above depreciation (so the year's cash understates
the business), an operating margin below its own ten-year normal (so sales
growth is being won at lower profit), and a valuation resting on accounting
profit because there is no free cash flow to use.

### What the price is asking: a DCF run backwards

A fair value depends entirely on an assumed growth rate and an assumed discount
rate, so quoting one number hides the assumptions inside it. Turning the
question round is more honest and more useful: **take the price as given and
solve for the growth it requires**. The guess then belongs to the market, and
the filings can be used to judge it.

The verdict is whether that required growth sits inside what the company has
actually produced:

| Reading | Meaning |
| --- | --- |
| Asking less than it has delivered | Even a buyer wanting an 11% return needs less growth than the record. Either the market doubts the record repeats, or it has not noticed it. |
| Asking about what it has delivered | The price is a reasonable reading of the record. |
| Asking more than it has ever delivered | Even a buyer content with 7% needs more than the company has managed. The case for the price is not in the filings. |

**The discount rate is the model's weakest point and is shown, not hidden.**
Required growth for Microsoft is 13% at a 7% required return and 30% at 11% —
a spread far too wide to report a single number for. So the whole band is on the
card. What survives the assumption is the *comparison*: the ordering across
companies is identical at every rate, and a company like Apple that needs more
growth than its record at **every** rate in the band is demanding on any
reading.

**The base is normalised.** One year of free cash flow is a poor anchor:
Microsoft spent 63% of operating cash flow on capital projects in FY2026 and
Coca-Cola paid a one-off tax deposit in 2025, each roughly halving reported free
cash flow without changing what the business ordinarily earns. The model
discounts the company's **median free cash flow margin over ten years applied to
its latest revenue**, and the card states both that figure and the reported one
it replaced.

The record is also checked rather than taken at face value. Revenue growth alone
cannot tell bought growth from earned growth, so the ingest carries
`OperatingIncomeLoss`, `Assets`, `StockholdersEquity` and depreciation, and the
report flags a margin more than three points below its own median.
`GrossProfit` would be the purer margin signal but is not dependable — Alphabet
and Ford do not tag it and Amazon tags a figure that is plainly not its gross
profit — so it is left out rather than shown wrong.

Growth is faded linearly to 2.5% across a ten-year horizon rather than held flat
and then dropped, and a record above 20% a year is credited only to 20% when
valuing forwards — a decade at 45% is a wish, not a forecast.

Measured against live prices, this separates the sample cleanly: NVIDIA's price
asked for less growth than it has delivered, Microsoft's and Alphabet's sat in
line with theirs, and Apple's, Amazon's and Coca-Cola's asked for more than
their records at every discount rate in the band.

### What "cash" and "debt" mean

**Cash is cash, equivalents *and* short-term investments.** Reading only the
cash line badly misjudges the cash-rich: Microsoft keeps $55.9B of its $76.8B in
treasuries and $20.9B as cash proper, so against $40.3B of debt it reported as a
net borrower when it holds $36.5B more than it owes. Alphabet flipped the same
way. Where a filer also reports the combined
`CashCashEquivalentsAndShortTermInvestments`, cash plus the short-term
investments tag PickStock picks reproduces it exactly — checked against
Microsoft, Alphabet and Coca-Cola.

The short-term investment tags are **alternate names for one line**, so the
first with data wins. The debt tags are **genuinely separate borrowings**, so
they are summed. Getting that backwards double-counts, which is why the two
groups are declared apart in `XbrlMetric` and each has a test.

Debt also covers `LongTermDebtAndCapitalLeaseObligations`, used by filers who
fold leases into borrowings. Without it Coca-Cola reported $1.5B of debt — its
commercial paper alone — instead of $45.4B.

Some filers tag debt only with company-specific concepts, which the bulk archive
does not carry. Ford is one: nothing under any us-gaap debt concept, so its net
debt reads **Unknown** rather than a wrong number.

### Sectors: how much of the directory is covered

Of the 5,017 companies you can actually open a report for, **96.7% carry a SIC
code and every one of those maps to a sector**. `test/sic_sector_test.dart`
pins the mapping and asserts no two sectors claim the same code — an overlap
would silently hand a whole block to whichever sector is declared first.

The remaining 3.3% have no SIC code at all, which is a gap in the source rather
than in the mapping: the quarterly DERA data sets only carry filers who filed in
the quarters fetched. Widening that means downloading more quarters.

### Why drift

It is the only mature typed-SQL layer covering macOS, Linux, Android and iOS
from one codebase. `sqflite` alone declares no Linux support; `hive` and `isar`
have not shipped since 2022 and 2023. `sqlite3` 3.x bundles the native library
(it replaced the now end-of-life `sqlite3_flutter_libs`).

`extractorVersion` in `app_database.dart` is stamped on every ingest. Bump it
when the XBRL extraction changes meaning, and rows written by the old code are
treated as absent rather than served as if correct — the app then asks for a
fresh ingest rather than serving figures it knows are wrong. A schema migration
adds a column; only a re-ingest fills it.

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
cp env.example.json env.json   # then paste a Finnhub key, or leave it empty
fvm flutter run -d macos --dart-define-from-file=env.json   # or -d linux
```

The define is optional — `fvm flutter run -d macos` works, with the share price
typed in rather than quoted. `.vscode/launch.json` passes it for you.

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
    quote/       Live share prices from Finnhub, behind a key
  ui/            Screens, view models and widgets
  l10n/          ARB bundle and the generated AppLocalizations
```

Every page-level row — the app bar, the filter, the sector chips, the grid and
the report — is inset by one gutter, `context.pageGutter`, on **all four
sides**. `test/header_alignment_test.dart` asserts that they share a left edge,
that a divider has equal air above and below it, and that the grid's horizontal
inset matches its vertical one. Four rows each choosing their own inset, or a
margin twice as wide as it is tall, is exactly the kind of drift nobody notices
in a diff.

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

## Starting over

Everything is derived from the download, so resetting is deleting one file:

```shell
rm ~/Library/Containers/<bundle-id>/Data/Documents/pickstock.sqlite
```

The next launch recreates it empty and the gate asks for a fresh ingest.
