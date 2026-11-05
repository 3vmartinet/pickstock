import 'package:equatable/equatable.dart';
import 'package:pickstock/l10n/app_localizations.dart';

/// Style and classification of an institutional manager under SEC EDGAR rules.
enum InstitutionalManagerType {
  indexPassive,
  assetManager,
  hedgeFund,
  pensionSovereign,
  insider;

  String getLabel(AppLocalizations strings) => switch (this) {
    InstitutionalManagerType.indexPassive => strings.managerTypePassive,
    InstitutionalManagerType.assetManager => strings.managerTypeAssetManager,
    InstitutionalManagerType.hedgeFund => strings.managerTypeHedgeFund,
    InstitutionalManagerType.pensionSovereign => strings.managerTypeSovereign,
    InstitutionalManagerType.insider => strings.managerTypeInsider,
  };
}

/// An entity filing Schedule 13D indicating active or activist intent.
class ActivistFiler extends Equatable {
  const ActivistFiler({
    required this.name,
    required this.managerCik,
    required this.stakePercent,
    required this.filingDate,
    required this.formType,
    required this.intentSummary,
    this.accessionNumber,
  });

  final String name;
  final String managerCik;
  final double stakePercent;
  final DateTime filingDate;
  final String formType;
  final String intentSummary;
  final String? accessionNumber;

  @override
  List<Object?> get props => [
    name,
    managerCik,
    stakePercent,
    filingDate,
    formType,
    intentSummary,
    accessionNumber,
  ];
}

/// A snapshot of an institutional holder's position at a specific quarter.
class HolderQuarterHistory extends Equatable {
  const HolderQuarterHistory({
    required this.calendarQuarter,
    required this.asOfDate,
    required this.sharesHeld,
    required this.percentOfClass,
    this.changeSharesQoQ,
    this.changePercentQoQ,
  });

  final String calendarQuarter;
  final DateTime asOfDate;
  final double sharesHeld;
  final double percentOfClass;
  final double? changeSharesQoQ;
  final double? changePercentQoQ;

  bool get isIncreasing => (changeSharesQoQ ?? 0) > 0;
  bool get isDecreasing => (changeSharesQoQ ?? 0) < 0;

  @override
  List<Object?> get props => [
    calendarQuarter,
    asOfDate,
    sharesHeld,
    percentOfClass,
    changeSharesQoQ,
    changePercentQoQ,
  ];
}

/// Aggregate institutional ownership metrics for one calendar quarter.
class InstitutionalQuarterlyTrend extends Equatable {
  const InstitutionalQuarterlyTrend({
    required this.calendarQuarter,
    required this.asOfDate,
    required this.totalSharesHeld,
    required this.institutionalOwnershipPercent,
    required this.netSharesChange,
    this.netSharesPercentChange,
    required this.buyersCount,
    required this.sellersCount,
  });

  final String calendarQuarter;
  final DateTime asOfDate;
  final double totalSharesHeld;
  final double institutionalOwnershipPercent;
  final double netSharesChange;
  final double? netSharesPercentChange;
  final int buyersCount;
  final int sellersCount;

  bool get isNetAcquiring => netSharesChange > 0;
  bool get isNetReleasing => netSharesChange < 0;

  @override
  List<Object?> get props => [
    calendarQuarter,
    asOfDate,
    totalSharesHeld,
    institutionalOwnershipPercent,
    netSharesChange,
    netSharesPercentChange,
    buyersCount,
    sellersCount,
  ];
}

/// One institutional investment manager holding common stock under Form 13F or 13G.
class InstitutionalHolder extends Equatable {
  const InstitutionalHolder({
    required this.name,
    required this.managerCik,
    required this.managerType,
    required this.sharesHeld,
    required this.percentOfClass,
    required this.marketValue,
    this.changeSharesQoQ,
    this.changePercentQoQ,
    this.isNewPosition = false,
    this.portfolioPercent,
    required this.formType,
    required this.filingDate,
    this.accessionNumber,
    this.history = const [],
  });

  final String name;
  final String managerCik;
  final InstitutionalManagerType managerType;
  final double sharesHeld;
  final double percentOfClass;
  final double marketValue;
  final double? changeSharesQoQ;
  final double? changePercentQoQ;
  final bool isNewPosition;
  final double? portfolioPercent;
  final String formType;
  final DateTime filingDate;
  final String? accessionNumber;

  /// Historical snapshots across prior calendar quarters.
  final List<HolderQuarterHistory> history;

  bool get isIncreasing => (changeSharesQoQ ?? 0) > 0 || isNewPosition;
  bool get isDecreasing => (changeSharesQoQ ?? 0) < 0;

  /// Net change in shares across the historical series (latest vs earliest).
  double get netChangeOverHistory {
    if (history.length < 2) return changeSharesQoQ ?? 0;
    return history.last.sharesHeld - history.first.sharesHeld;
  }

  /// Net percentage change across the historical series.
  double? get netPercentChangeOverHistory {
    if (history.length < 2) return changePercentQoQ;
    final first = history.first.sharesHeld;
    if (first == 0) return null;
    return ((history.last.sharesHeld - first) / first) * 100;
  }

  bool get isNetAcquiring => netChangeOverHistory > 0 || isNewPosition;
  bool get isNetReleasing => netChangeOverHistory < 0;

  @override
  List<Object?> get props => [
    name,
    managerCik,
    managerType,
    sharesHeld,
    percentOfClass,
    marketValue,
    changeSharesQoQ,
    changePercentQoQ,
    isNewPosition,
    portfolioPercent,
    formType,
    filingDate,
    accessionNumber,
    history,
  ];
}

/// Complete institutional shareholding snapshot for a company from SEC EDGAR.
class InstitutionalShareholding extends Equatable {
  const InstitutionalShareholding({
    required this.cik,
    required this.calendarQuarter,
    required this.asOfDate,
    required this.totalSharesHeld,
    required this.institutionalOwnershipPercent,
    required this.totalInstitutionsCount,
    required this.top10ConcentrationPercent,
    required this.passiveIndexPercent,
    required this.activeFundsPercent,
    required this.insiderPercent,
    required this.publicFloatPercent,
    required this.netSharesChange,
    required this.netSharesPercentChange,
    required this.buyersCount,
    required this.sellersCount,
    required this.newPositionsCount,
    required this.soldOutPositionsCount,
    this.activistStakes = const [],
    required this.topHolders,
    this.quarterlyTrends = const [],
  });

  final String cik;
  final String calendarQuarter;
  final DateTime asOfDate;
  final double totalSharesHeld;
  final double institutionalOwnershipPercent;
  final int totalInstitutionsCount;
  final double top10ConcentrationPercent;

  /// Float breakdown percentages (summing to 100%).
  final double passiveIndexPercent;
  final double activeFundsPercent;
  final double insiderPercent;
  final double publicFloatPercent;

  /// Quarter-over-quarter institutional net flows.
  final double netSharesChange;
  final double netSharesPercentChange;
  final int buyersCount;
  final int sellersCount;
  final int newPositionsCount;
  final int soldOutPositionsCount;

  /// Active Schedule 13D filings on file.
  final List<ActivistFiler> activistStakes;

  /// Top institutional holders reported on Form 13F / 13G.
  final List<InstitutionalHolder> topHolders;

  /// Historical quarterly trend snapshots over time.
  final List<InstitutionalQuarterlyTrend> quarterlyTrends;

  bool get hasActivistStakes => activistStakes.isNotEmpty;

  /// Holders who are net acquirers (increasing position) over time.
  List<InstitutionalHolder> get netAcquirers {
    final list = topHolders.where((h) => h.isNetAcquiring).toList();
    list.sort((a, b) => b.netChangeOverHistory.compareTo(a.netChangeOverHistory));
    return list;
  }

  /// Holders who are net releasers (trimming or liquidating position) over time.
  List<InstitutionalHolder> get netReleasers {
    final list = topHolders.where((h) => h.isNetReleasing).toList();
    list.sort((a, b) => a.netChangeOverHistory.compareTo(b.netChangeOverHistory));
    return list;
  }

  @override
  List<Object?> get props => [
    cik,
    calendarQuarter,
    asOfDate,
    totalSharesHeld,
    institutionalOwnershipPercent,
    totalInstitutionsCount,
    top10ConcentrationPercent,
    passiveIndexPercent,
    activeFundsPercent,
    insiderPercent,
    publicFloatPercent,
    netSharesChange,
    netSharesPercentChange,
    buyersCount,
    sellersCount,
    newPositionsCount,
    soldOutPositionsCount,
    activistStakes,
    topHolders,
    quarterlyTrends,
  ];
}

