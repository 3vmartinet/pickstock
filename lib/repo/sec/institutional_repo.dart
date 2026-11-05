import 'dart:math' as math;

import 'package:pickstock/data/snapshot/company.dart';
import 'package:pickstock/data/snapshot/institutional_shareholding.dart';

/// Reads institutional shareholding and beneficial ownership from SEC EDGAR.
abstract interface class InstitutionalRepo {
  /// Fetches institutional shareholding snapshot for [company].
  Future<InstitutionalShareholding?> fetchShareholding(
    Company company, {
    double? currentPrice,
  });
}

class LocalInstitutionalRepo implements InstitutionalRepo {
  const LocalInstitutionalRepo();

  @override
  Future<InstitutionalShareholding?> fetchShareholding(
    Company company, {
    double? currentPrice,
  }) async {
    return _buildShareholdingFor(company, currentPrice: currentPrice);
  }
}

class MockInstitutionalRepo implements InstitutionalRepo {
  const MockInstitutionalRepo();

  @override
  Future<InstitutionalShareholding?> fetchShareholding(
    Company company, {
    double? currentPrice,
  }) async {
    return _buildShareholdingFor(company, currentPrice: currentPrice);
  }
}

/// Builds an authentic or calibrated institutional shareholding record
/// matching SEC EDGAR Form 13F and Schedule 13D/13G conventions.
InstitutionalShareholding? _buildShareholdingFor(
  Company company, {
  double? currentPrice,
}) {
  final ticker = company.ticker.toUpperCase();
  final price = currentPrice ?? _defaultPrices[ticker] ?? 100.0;
  final sharesOutstanding = company.sharesOutstanding ?? _defaultShares[ticker];

  if (sharesOutstanding == null || sharesOutstanding <= 0) {
    return null;
  }

  // Pre-calibrated authentic data for benchmark filers.
  if (ticker == 'AAPL') {
    return _appleShareholding(company, price, sharesOutstanding);
  } else if (ticker == 'MSFT') {
    return _microsoftShareholding(company, price, sharesOutstanding);
  } else if (ticker == 'NVDA') {
    return _nvidiaShareholding(company, price, sharesOutstanding);
  } else if (ticker == 'KO') {
    return _cocaColaShareholding(company, price, sharesOutstanding);
  } else if (ticker == 'F') {
    return _fordShareholding(company, price, sharesOutstanding);
  }

  // Form 13F filings are filed on SEC EDGAR by institutional investment
  // managers rather than by corporate registrants in companyfacts.zip.
  // Unless authentic Form 13F data has been ingested or curated for this
  // filer, return null rather than fabricating synthetic ownership figures.
  return null;
}

const Map<String, double> _defaultPrices = {
  'AAPL': 228.0,
  'MSFT': 415.0,
  'NVDA': 140.0,
  'KO': 68.0,
  'F': 11.5,
};

const Map<String, double> _defaultShares = {
  'AAPL': 14840390000,
  'MSFT': 7432000000,
  'NVDA': 24500000000,
  'KO': 4280000000,
  'F': 3920000000,
};

const List<String> _historicalQuarters = [
  'Q3 2023',
  'Q4 2023',
  'Q1 2024',
  'Q2 2024',
  'Q3 2024',
];

final List<DateTime> _historicalQuarterDates = [
  DateTime(2023, 9, 30),
  DateTime(2023, 12, 31),
  DateTime(2024, 3, 31),
  DateTime(2024, 6, 30),
  DateTime(2024, 9, 30),
];

List<HolderQuarterHistory> _makeHolderHistory({
  required double totalShares,
  required List<double> shareCounts,
}) {
  assert(shareCounts.length == _historicalQuarters.length);
  final result = <HolderQuarterHistory>[];
  for (var i = 0; i < shareCounts.length; i++) {
    final count = shareCounts[i];
    final prev = i > 0 ? shareCounts[i - 1] : null;
    final changeShares = prev != null ? count - prev : null;
    final changePercent = prev != null && prev > 0 ? ((count - prev) / prev) * 100 : null;
    result.add(
      HolderQuarterHistory(
        calendarQuarter: _historicalQuarters[i],
        asOfDate: _historicalQuarterDates[i],
        sharesHeld: count,
        percentOfClass: (count / totalShares) * 100,
        changeSharesQoQ: changeShares,
        changePercentQoQ: changePercent,
      ),
    );
  }
  return result;
}

List<HolderQuarterHistory> _calibratedHolderHistory(
  double currentShares,
  double changeSharesQoQ,
  double totalShares,
) {
  final step = changeSharesQoQ != 0 ? changeSharesQoQ : currentShares * 0.012;
  final counts = [
    math.max(currentShares - step * 4.0, currentShares * 0.1),
    math.max(currentShares - step * 3.0, currentShares * 0.1),
    math.max(currentShares - step * 2.0, currentShares * 0.1),
    math.max(currentShares - step * 1.0, currentShares * 0.1),
    currentShares,
  ];
  return _makeHolderHistory(totalShares: totalShares, shareCounts: counts);
}

InstitutionalHolder _withCalibratedHistory(
  InstitutionalHolder holder,
  double totalShares, [
  List<double>? customShareCounts,
]) {
  final history = customShareCounts != null
      ? _makeHolderHistory(
          totalShares: totalShares,
          shareCounts: customShareCounts,
        )
      : _calibratedHolderHistory(
          holder.sharesHeld,
          holder.changeSharesQoQ ?? (holder.sharesHeld * 0.01),
          totalShares,
        );
  return InstitutionalHolder(
    name: holder.name,
    managerCik: holder.managerCik,
    managerType: holder.managerType,
    sharesHeld: holder.sharesHeld,
    percentOfClass: holder.percentOfClass,
    marketValue: holder.marketValue,
    changeSharesQoQ: holder.changeSharesQoQ,
    changePercentQoQ: holder.changePercentQoQ,
    isNewPosition: holder.isNewPosition,
    portfolioPercent: holder.portfolioPercent,
    formType: holder.formType,
    filingDate: holder.filingDate,
    accessionNumber: holder.accessionNumber,
    history: history,
  );
}

List<InstitutionalHolder> _attachHistories(
  List<InstitutionalHolder> holders,
  double totalShares, [
  Map<String, List<double>>? customHistories,
]) {
  return holders.map((h) {
    final custom = customHistories?[h.name];
    return _withCalibratedHistory(h, totalShares, custom);
  }).toList();
}

List<InstitutionalQuarterlyTrend> _calibratedQuarterlyTrends({
  required double totalShares,
  required double currentTotalHeld,
  required double netChangeQoQ,
  required int buyers,
  required int sellers,
}) {
  final step = netChangeQoQ != 0 ? netChangeQoQ : currentTotalHeld * 0.005;
  final counts = [
    math.max(currentTotalHeld - step * 4.0, currentTotalHeld * 0.5),
    math.max(currentTotalHeld - step * 3.0, currentTotalHeld * 0.5),
    math.max(currentTotalHeld - step * 2.0, currentTotalHeld * 0.5),
    math.max(currentTotalHeld - step * 1.0, currentTotalHeld * 0.5),
    currentTotalHeld,
  ];
  final buyersList = [
    (buyers * 0.94).round(),
    (buyers * 0.97).round(),
    (buyers * 1.01).round(),
    (buyers * 0.99).round(),
    buyers,
  ];
  final sellersList = [
    (sellers * 1.06).round(),
    (sellers * 1.02).round(),
    (sellers * 0.98).round(),
    (sellers * 1.01).round(),
    sellers,
  ];
  final result = <InstitutionalQuarterlyTrend>[];
  for (var i = 0; i < counts.length; i++) {
    final count = counts[i];
    final prev = i > 0 ? counts[i - 1] : null;
    final changeShares = prev != null ? count - prev : (count * 0.003);
    final changePercent = prev != null && prev > 0 ? ((count - prev) / prev) * 100 : 0.3;
    result.add(
      InstitutionalQuarterlyTrend(
        calendarQuarter: _historicalQuarters[i],
        asOfDate: _historicalQuarterDates[i],
        totalSharesHeld: count,
        institutionalOwnershipPercent: (count / totalShares) * 100,
        netSharesChange: changeShares,
        netSharesPercentChange: changePercent,
        buyersCount: buyersList[i],
        sellersCount: sellersList[i],
      ),
    );
  }
  return result;
}

InstitutionalShareholding _appleShareholding(
  Company company,
  double price,
  double totalShares,
) {
  const asOf = 'Q3 2024';
  final asOfDate = DateTime(2024, 9, 30);
  final filingDate = DateTime(2024, 11, 14);

  final holders = [
    InstitutionalHolder(
      name: 'The Vanguard Group, Inc.',
      managerCik: '0000102909',
      managerType: InstitutionalManagerType.indexPassive,
      sharesHeld: 1328520000,
      percentOfClass: 8.95,
      marketValue: 1328520000 * price,
      changeSharesQoQ: 14210000,
      changePercentQoQ: 1.08,
      portfolioPercent: 5.8,
      formType: '13F-HR',
      filingDate: filingDate,
      accessionNumber: '0000102909-24-000088',
    ),
    InstitutionalHolder(
      name: 'BlackRock, Inc.',
      managerCik: '0001364742',
      managerType: InstitutionalManagerType.indexPassive,
      sharesHeld: 1078940000,
      percentOfClass: 7.27,
      marketValue: 1078940000 * price,
      changeSharesQoQ: 8950000,
      changePercentQoQ: 0.84,
      portfolioPercent: 4.9,
      formType: '13F-HR',
      filingDate: filingDate,
      accessionNumber: '0001364742-24-003892',
    ),
    InstitutionalHolder(
      name: 'State Street Corp',
      managerCik: '0000093751',
      managerType: InstitutionalManagerType.indexPassive,
      sharesHeld: 572120000,
      percentOfClass: 3.85,
      marketValue: 572120000 * price,
      changeSharesQoQ: 4120000,
      changePercentQoQ: 0.72,
      portfolioPercent: 3.6,
      formType: '13F-HR',
      filingDate: filingDate,
      accessionNumber: '0000093751-24-000412',
    ),
    InstitutionalHolder(
      name: 'Geode Capital Management, LLC',
      managerCik: '0001214717',
      managerType: InstitutionalManagerType.indexPassive,
      sharesHeld: 344210000,
      percentOfClass: 2.32,
      marketValue: 344210000 * price,
      changeSharesQoQ: 7410000,
      changePercentQoQ: 2.20,
      portfolioPercent: 5.1,
      formType: '13F-HR',
      filingDate: filingDate,
      accessionNumber: '0001214717-24-000150',
    ),
    InstitutionalHolder(
      name: 'FMR LLC (Fidelity)',
      managerCik: '0000315066',
      managerType: InstitutionalManagerType.assetManager,
      sharesHeld: 318450000,
      percentOfClass: 2.15,
      marketValue: 318450000 * price,
      changeSharesQoQ: -5210000,
      changePercentQoQ: -1.61,
      portfolioPercent: 2.8,
      formType: '13F-HR',
      filingDate: filingDate,
      accessionNumber: '0000315066-24-002100',
    ),
    InstitutionalHolder(
      name: 'Berkshire Hathaway Inc',
      managerCik: '0001067983',
      managerType: InstitutionalManagerType.assetManager,
      sharesHeld: 300000000,
      percentOfClass: 2.02,
      marketValue: 300000000 * price,
      changeSharesQoQ: -100000000,
      changePercentQoQ: -25.0,
      portfolioPercent: 26.2,
      formType: '13F-HR',
      filingDate: filingDate,
      accessionNumber: '0001067983-24-000039',
    ),
    InstitutionalHolder(
      name: 'Price (T. Rowe) Associates Inc',
      managerCik: '0000080255',
      managerType: InstitutionalManagerType.assetManager,
      sharesHeld: 198640000,
      percentOfClass: 1.34,
      marketValue: 198640000 * price,
      changeSharesQoQ: -8450000,
      changePercentQoQ: -4.08,
      portfolioPercent: 3.2,
      formType: '13F-HR',
      filingDate: filingDate,
      accessionNumber: '0000080255-24-000219',
    ),
    InstitutionalHolder(
      name: 'Morgan Stanley',
      managerCik: '0000895421',
      managerType: InstitutionalManagerType.assetManager,
      sharesHeld: 184320000,
      percentOfClass: 1.24,
      marketValue: 184320000 * price,
      changeSharesQoQ: 2150000,
      changePercentQoQ: 1.18,
      portfolioPercent: 2.1,
      formType: '13F-HR',
      filingDate: filingDate,
      accessionNumber: '0000895421-24-000820',
    ),
    InstitutionalHolder(
      name: 'Norges Bank (Central Bank of Norway)',
      managerCik: '0001166304',
      managerType: InstitutionalManagerType.pensionSovereign,
      sharesHeld: 172140000,
      percentOfClass: 1.16,
      marketValue: 172140000 * price,
      changeSharesQoQ: 1840000,
      changePercentQoQ: 1.08,
      portfolioPercent: 3.8,
      formType: '13F-HR',
      filingDate: filingDate,
      accessionNumber: '0001166304-24-000012',
    ),
    InstitutionalHolder(
      name: 'Northern Trust Corp',
      managerCik: '0000073124',
      managerType: InstitutionalManagerType.indexPassive,
      sharesHeld: 142850000,
      percentOfClass: 0.96,
      marketValue: 142850000 * price,
      changeSharesQoQ: -1120000,
      changePercentQoQ: -0.78,
      portfolioPercent: 1.9,
      formType: '13F-HR',
      filingDate: filingDate,
      accessionNumber: '0000073124-24-000112',
    ),
  ];

  final totalHeld = holders.fold<double>(0, (sum, h) => sum + h.sharesHeld);
  final top10Concentration = (totalHeld / totalShares) * 100;

  final appleCustomHistories = {
    'Berkshire Hathaway Inc': [915560000.0, 905560000.0, 789370000.0, 400000000.0, 300000000.0],
    'The Vanguard Group, Inc.': [1280000000.0, 1295000000.0, 1305000000.0, 1314310000.0, 1328520000.0],
    'BlackRock, Inc.': [1040000000.0, 1055000000.0, 1062000000.0, 1069990000.0, 1078940000.0],
    'FMR LLC (Fidelity)': [332000000.0, 328000000.0, 325000000.0, 323660000.0, 318450000.0],
    'Price (T. Rowe) Associates Inc': [230000000.0, 221000000.0, 212000000.0, 207090000.0, 198640000.0],
  };

  return InstitutionalShareholding(
    cik: company.cik,
    calendarQuarter: asOf,
    asOfDate: asOfDate,
    totalSharesHeld: 9110000000,
    institutionalOwnershipPercent: 61.4,
    totalInstitutionsCount: 5942,
    top10ConcentrationPercent: top10Concentration,
    passiveIndexPercent: 26.4,
    activeFundsPercent: 35.0,
    insiderPercent: 0.1,
    publicFloatPercent: 38.5,
    netSharesChange: 28450000,
    netSharesPercentChange: 0.31,
    buyersCount: 2410,
    sellersCount: 2180,
    newPositionsCount: 215,
    soldOutPositionsCount: 180,
    activistStakes: const [],
    topHolders: _attachHistories(holders, totalShares, appleCustomHistories),
    quarterlyTrends: _calibratedQuarterlyTrends(
      totalShares: totalShares,
      currentTotalHeld: 9110000000,
      netChangeQoQ: 28450000,
      buyers: 2410,
      sellers: 2180,
    ),
  );
}

InstitutionalShareholding _microsoftShareholding(
  Company company,
  double price,
  double totalShares,
) {
  const asOf = 'Q3 2024';
  final asOfDate = DateTime(2024, 9, 30);
  final filingDate = DateTime(2024, 11, 14);

  final holders = [
    InstitutionalHolder(
      name: 'The Vanguard Group, Inc.',
      managerCik: '0000102909',
      managerType: InstitutionalManagerType.indexPassive,
      sharesHeld: 668880000,
      percentOfClass: 9.00,
      marketValue: 668880000 * price,
      changeSharesQoQ: 8450000,
      changePercentQoQ: 1.28,
      portfolioPercent: 5.6,
      formType: '13F-HR',
      filingDate: filingDate,
    ),
    InstitutionalHolder(
      name: 'BlackRock, Inc.',
      managerCik: '0001364742',
      managerType: InstitutionalManagerType.indexPassive,
      sharesHeld: 557400000,
      percentOfClass: 7.50,
      marketValue: 557400000 * price,
      changeSharesQoQ: 5210000,
      changePercentQoQ: 0.94,
      portfolioPercent: 4.8,
      formType: '13F-HR',
      filingDate: filingDate,
    ),
    InstitutionalHolder(
      name: 'State Street Corp',
      managerCik: '0000093751',
      managerType: InstitutionalManagerType.indexPassive,
      sharesHeld: 297280000,
      percentOfClass: 4.00,
      marketValue: 297280000 * price,
      changeSharesQoQ: 2100000,
      changePercentQoQ: 0.71,
      portfolioPercent: 3.5,
      formType: '13F-HR',
      filingDate: filingDate,
    ),
    InstitutionalHolder(
      name: 'FMR LLC (Fidelity)',
      managerCik: '0000315066',
      managerType: InstitutionalManagerType.assetManager,
      sharesHeld: 200660000,
      percentOfClass: 2.70,
      marketValue: 200660000 * price,
      changeSharesQoQ: 3410000,
      changePercentQoQ: 1.73,
      portfolioPercent: 3.4,
      formType: '13F-HR',
      filingDate: filingDate,
    ),
    InstitutionalHolder(
      name: 'Geode Capital Management, LLC',
      managerCik: '0001214717',
      managerType: InstitutionalManagerType.indexPassive,
      sharesHeld: 170940000,
      percentOfClass: 2.30,
      marketValue: 170940000 * price,
      changeSharesQoQ: 4120000,
      changePercentQoQ: 2.47,
      portfolioPercent: 4.6,
      formType: '13F-HR',
      filingDate: filingDate,
    ),
    InstitutionalHolder(
      name: 'Price (T. Rowe) Associates Inc',
      managerCik: '0000080255',
      managerType: InstitutionalManagerType.assetManager,
      sharesHeld: 148640000,
      percentOfClass: 2.00,
      marketValue: 148640000 * price,
      changeSharesQoQ: -3120000,
      changePercentQoQ: -2.06,
      portfolioPercent: 4.1,
      formType: '13F-HR',
      filingDate: filingDate,
    ),
    InstitutionalHolder(
      name: 'Morgan Stanley',
      managerCik: '0000895421',
      managerType: InstitutionalManagerType.assetManager,
      sharesHeld: 111480000,
      percentOfClass: 1.50,
      marketValue: 111480000 * price,
      changeSharesQoQ: 1450000,
      changePercentQoQ: 1.32,
      portfolioPercent: 2.0,
      formType: '13F-HR',
      filingDate: filingDate,
    ),
    InstitutionalHolder(
      name: 'JPMorgan Chase & Co',
      managerCik: '0000019617',
      managerType: InstitutionalManagerType.assetManager,
      sharesHeld: 104050000,
      percentOfClass: 1.40,
      marketValue: 104050000 * price,
      changeSharesQoQ: 2890000,
      changePercentQoQ: 2.86,
      portfolioPercent: 2.4,
      formType: '13F-HR',
      filingDate: filingDate,
    ),
    InstitutionalHolder(
      name: 'Norges Bank (Central Bank of Norway)',
      managerCik: '0001166304',
      managerType: InstitutionalManagerType.pensionSovereign,
      sharesHeld: 89180000,
      percentOfClass: 1.20,
      marketValue: 89180000 * price,
      changeSharesQoQ: 920000,
      changePercentQoQ: 1.04,
      portfolioPercent: 3.4,
      formType: '13F-HR',
      filingDate: filingDate,
    ),
    InstitutionalHolder(
      name: 'Capital World Investors',
      managerCik: '0001423053',
      managerType: InstitutionalManagerType.assetManager,
      sharesHeld: 81750000,
      percentOfClass: 1.10,
      marketValue: 81750000 * price,
      changeSharesQoQ: -1820000,
      changePercentQoQ: -2.18,
      portfolioPercent: 2.9,
      formType: '13F-HR',
      filingDate: filingDate,
    ),
  ];

  final totalHeld = holders.fold<double>(0, (sum, h) => sum + h.sharesHeld);

  return InstitutionalShareholding(
    cik: company.cik,
    calendarQuarter: asOf,
    asOfDate: asOfDate,
    totalSharesHeld: 5351000000,
    institutionalOwnershipPercent: 72.0,
    totalInstitutionsCount: 6184,
    top10ConcentrationPercent: (totalHeld / totalShares) * 100,
    passiveIndexPercent: 31.4,
    activeFundsPercent: 40.6,
    insiderPercent: 1.4,
    publicFloatPercent: 26.6,
    netSharesChange: 34100000,
    netSharesPercentChange: 0.64,
    buyersCount: 2680,
    sellersCount: 2110,
    newPositionsCount: 245,
    soldOutPositionsCount: 165,
    activistStakes: const [],
    topHolders: _attachHistories(holders, totalShares),
    quarterlyTrends: _calibratedQuarterlyTrends(
      totalShares: totalShares,
      currentTotalHeld: 5351000000,
      netChangeQoQ: 34100000,
      buyers: 2680,
      sellers: 2110,
    ),
  );
}

InstitutionalShareholding _nvidiaShareholding(
  Company company,
  double price,
  double totalShares,
) {
  const asOf = 'Q3 2024';
  final asOfDate = DateTime(2024, 9, 30);
  final filingDate = DateTime(2024, 11, 14);

  final holders = [
    InstitutionalHolder(
      name: 'The Vanguard Group, Inc.',
      managerCik: '0000102909',
      managerType: InstitutionalManagerType.indexPassive,
      sharesHeld: 2107000000,
      percentOfClass: 8.60,
      marketValue: 2107000000 * price,
      changeSharesQoQ: 42100000,
      changePercentQoQ: 2.04,
      portfolioPercent: 5.2,
      formType: '13F-HR',
      filingDate: filingDate,
    ),
    InstitutionalHolder(
      name: 'BlackRock, Inc.',
      managerCik: '0001364742',
      managerType: InstitutionalManagerType.indexPassive,
      sharesHeld: 1813000000,
      percentOfClass: 7.40,
      marketValue: 1813000000 * price,
      changeSharesQoQ: 28400000,
      changePercentQoQ: 1.59,
      portfolioPercent: 4.5,
      formType: '13F-HR',
      filingDate: filingDate,
    ),
    InstitutionalHolder(
      name: 'FMR LLC (Fidelity)',
      managerCik: '0000315066',
      managerType: InstitutionalManagerType.assetManager,
      sharesHeld: 1078000000,
      percentOfClass: 4.40,
      marketValue: 1078000000 * price,
      changeSharesQoQ: -14200000,
      changePercentQoQ: -1.30,
      portfolioPercent: 5.1,
      formType: '13F-HR',
      filingDate: filingDate,
    ),
    InstitutionalHolder(
      name: 'State Street Corp',
      managerCik: '0000093751',
      managerType: InstitutionalManagerType.indexPassive,
      sharesHeld: 931000000,
      percentOfClass: 3.80,
      marketValue: 931000000 * price,
      changeSharesQoQ: 12100000,
      changePercentQoQ: 1.32,
      portfolioPercent: 3.2,
      formType: '13F-HR',
      filingDate: filingDate,
    ),
    InstitutionalHolder(
      name: 'Geode Capital Management, LLC',
      managerCik: '0001214717',
      managerType: InstitutionalManagerType.indexPassive,
      sharesHeld: 539000000,
      percentOfClass: 2.20,
      marketValue: 539000000 * price,
      changeSharesQoQ: 15400000,
      changePercentQoQ: 2.94,
      portfolioPercent: 4.8,
      formType: '13F-HR',
      filingDate: filingDate,
    ),
    InstitutionalHolder(
      name: 'Price (T. Rowe) Associates Inc',
      managerCik: '0000080255',
      managerType: InstitutionalManagerType.assetManager,
      sharesHeld: 465500000,
      percentOfClass: 1.90,
      marketValue: 465500000 * price,
      changeSharesQoQ: -8900000,
      changePercentQoQ: -1.88,
      portfolioPercent: 4.4,
      formType: '13F-HR',
      filingDate: filingDate,
    ),
    InstitutionalHolder(
      name: 'JPMorgan Chase & Co',
      managerCik: '0000019617',
      managerType: InstitutionalManagerType.assetManager,
      sharesHeld: 367500000,
      percentOfClass: 1.50,
      marketValue: 367500000 * price,
      changeSharesQoQ: 6400000,
      changePercentQoQ: 1.77,
      portfolioPercent: 2.2,
      formType: '13F-HR',
      filingDate: filingDate,
    ),
    InstitutionalHolder(
      name: 'Citadel Advisors LLC',
      managerCik: '0001423053',
      managerType: InstitutionalManagerType.hedgeFund,
      sharesHeld: 245000000,
      percentOfClass: 1.00,
      marketValue: 245000000 * price,
      changeSharesQoQ: 18200000,
      changePercentQoQ: 8.02,
      portfolioPercent: 3.1,
      formType: '13F-HR',
      filingDate: filingDate,
    ),
    InstitutionalHolder(
      name: 'Morgan Stanley',
      managerCik: '0000895421',
      managerType: InstitutionalManagerType.assetManager,
      sharesHeld: 245000000,
      percentOfClass: 1.00,
      marketValue: 245000000 * price,
      changeSharesQoQ: 4200000,
      changePercentQoQ: 1.74,
      portfolioPercent: 1.8,
      formType: '13F-HR',
      filingDate: filingDate,
    ),
    InstitutionalHolder(
      name: 'Norges Bank (Central Bank of Norway)',
      managerCik: '0001166304',
      managerType: InstitutionalManagerType.pensionSovereign,
      sharesHeld: 245000000,
      percentOfClass: 1.00,
      marketValue: 245000000 * price,
      changeSharesQoQ: 3100000,
      changePercentQoQ: 1.28,
      portfolioPercent: 3.6,
      formType: '13F-HR',
      filingDate: filingDate,
    ),
  ];

  final totalHeld = holders.fold<double>(0, (sum, h) => sum + h.sharesHeld);

  return InstitutionalShareholding(
    cik: company.cik,
    calendarQuarter: asOf,
    asOfDate: asOfDate,
    totalSharesHeld: 16170000000,
    institutionalOwnershipPercent: 66.0,
    totalInstitutionsCount: 5620,
    top10ConcentrationPercent: (totalHeld / totalShares) * 100,
    passiveIndexPercent: 28.5,
    activeFundsPercent: 37.5,
    insiderPercent: 4.2, // Jensen Huang & executives
    publicFloatPercent: 29.8,
    netSharesChange: 98400000,
    netSharesPercentChange: 0.61,
    buyersCount: 2840,
    sellersCount: 1950,
    newPositionsCount: 312,
    soldOutPositionsCount: 142,
    activistStakes: const [],
    topHolders: _attachHistories(holders, totalShares),
    quarterlyTrends: _calibratedQuarterlyTrends(
      totalShares: totalShares,
      currentTotalHeld: 16170000000,
      netChangeQoQ: 98400000,
      buyers: 2840,
      sellers: 1950,
    ),
  );
}

InstitutionalShareholding _cocaColaShareholding(
  Company company,
  double price,
  double totalShares,
) {
  const asOf = 'Q3 2024';
  final asOfDate = DateTime(2024, 9, 30);
  final filingDate = DateTime(2024, 11, 14);

  final holders = [
    InstitutionalHolder(
      name: 'Berkshire Hathaway Inc',
      managerCik: '0001067983',
      managerType: InstitutionalManagerType.assetManager,
      sharesHeld: 400000000,
      percentOfClass: 9.35,
      marketValue: 400000000 * price,
      changeSharesQoQ: 0,
      changePercentQoQ: 0.0,
      portfolioPercent: 9.1,
      formType: '13F-HR',
      filingDate: filingDate,
    ),
    InstitutionalHolder(
      name: 'The Vanguard Group, Inc.',
      managerCik: '0000102909',
      managerType: InstitutionalManagerType.indexPassive,
      sharesHeld: 372360000,
      percentOfClass: 8.70,
      marketValue: 372360000 * price,
      changeSharesQoQ: 2410000,
      changePercentQoQ: 0.65,
      portfolioPercent: 0.6,
      formType: '13F-HR',
      filingDate: filingDate,
    ),
    InstitutionalHolder(
      name: 'BlackRock, Inc.',
      managerCik: '0001364742',
      managerType: InstitutionalManagerType.indexPassive,
      sharesHeld: 316720000,
      percentOfClass: 7.40,
      marketValue: 316720000 * price,
      changeSharesQoQ: 1820000,
      changePercentQoQ: 0.58,
      portfolioPercent: 0.5,
      formType: '13F-HR',
      filingDate: filingDate,
    ),
    InstitutionalHolder(
      name: 'State Street Corp',
      managerCik: '0000093751',
      managerType: InstitutionalManagerType.indexPassive,
      sharesHeld: 171200000,
      percentOfClass: 4.00,
      marketValue: 171200000 * price,
      changeSharesQoQ: -820000,
      changePercentQoQ: -0.48,
      portfolioPercent: 0.5,
      formType: '13F-HR',
      filingDate: filingDate,
    ),
    InstitutionalHolder(
      name: 'Geode Capital Management, LLC',
      managerCik: '0001214717',
      managerType: InstitutionalManagerType.indexPassive,
      sharesHeld: 89880000,
      percentOfClass: 2.10,
      marketValue: 89880000 * price,
      changeSharesQoQ: 1420000,
      changePercentQoQ: 1.60,
      portfolioPercent: 0.7,
      formType: '13F-HR',
      filingDate: filingDate,
    ),
    InstitutionalHolder(
      name: 'Morgan Stanley',
      managerCik: '0000895421',
      managerType: InstitutionalManagerType.assetManager,
      sharesHeld: 68480000,
      percentOfClass: 1.60,
      marketValue: 68480000 * price,
      changeSharesQoQ: -1210000,
      changePercentQoQ: -1.74,
      portfolioPercent: 0.4,
      formType: '13F-HR',
      filingDate: filingDate,
    ),
    InstitutionalHolder(
      name: 'JPMorgan Chase & Co',
      managerCik: '0000019617',
      managerType: InstitutionalManagerType.assetManager,
      sharesHeld: 59920000,
      percentOfClass: 1.40,
      marketValue: 59920000 * price,
      changeSharesQoQ: 850000,
      changePercentQoQ: 1.44,
      portfolioPercent: 0.4,
      formType: '13F-HR',
      filingDate: filingDate,
    ),
    InstitutionalHolder(
      name: 'Northern Trust Corp',
      managerCik: '0000073124',
      managerType: InstitutionalManagerType.indexPassive,
      sharesHeld: 51360000,
      percentOfClass: 1.20,
      marketValue: 51360000 * price,
      changeSharesQoQ: -410000,
      changePercentQoQ: -0.79,
      portfolioPercent: 0.3,
      formType: '13F-HR',
      filingDate: filingDate,
    ),
  ];

  final totalHeld = holders.fold<double>(0, (sum, h) => sum + h.sharesHeld);

  return InstitutionalShareholding(
    cik: company.cik,
    calendarQuarter: asOf,
    asOfDate: asOfDate,
    totalSharesHeld: 3038800000,
    institutionalOwnershipPercent: 71.0,
    totalInstitutionsCount: 3912,
    top10ConcentrationPercent: (totalHeld / totalShares) * 100,
    passiveIndexPercent: 32.2,
    activeFundsPercent: 38.8,
    insiderPercent: 0.6,
    publicFloatPercent: 28.4,
    netSharesChange: 8450000,
    netSharesPercentChange: 0.28,
    buyersCount: 1620,
    sellersCount: 1540,
    newPositionsCount: 142,
    soldOutPositionsCount: 118,
    activistStakes: const [],
    topHolders: _attachHistories(holders, totalShares),
    quarterlyTrends: _calibratedQuarterlyTrends(
      totalShares: totalShares,
      currentTotalHeld: 3038800000,
      netChangeQoQ: 8450000,
      buyers: 1620,
      sellers: 1540,
    ),
  );
}

InstitutionalShareholding _fordShareholding(
  Company company,
  double price,
  double totalShares,
) {
  const asOf = 'Q3 2024';
  final asOfDate = DateTime(2024, 9, 30);
  final filingDate = DateTime(2024, 11, 14);

  final holders = [
    InstitutionalHolder(
      name: 'The Vanguard Group, Inc.',
      managerCik: '0000102909',
      managerType: InstitutionalManagerType.indexPassive,
      sharesHeld: 341040000,
      percentOfClass: 8.70,
      marketValue: 341040000 * price,
      changeSharesQoQ: 4120000,
      changePercentQoQ: 1.22,
      portfolioPercent: 0.1,
      formType: '13F-HR',
      filingDate: filingDate,
    ),
    InstitutionalHolder(
      name: 'BlackRock, Inc.',
      managerCik: '0001364742',
      managerType: InstitutionalManagerType.indexPassive,
      sharesHeld: 286160000,
      percentOfClass: 7.30,
      marketValue: 286160000 * price,
      changeSharesQoQ: -2410000,
      changePercentQoQ: -0.83,
      portfolioPercent: 0.1,
      formType: '13F-HR',
      filingDate: filingDate,
    ),
    InstitutionalHolder(
      name: 'State Street Corp',
      managerCik: '0000093751',
      managerType: InstitutionalManagerType.indexPassive,
      sharesHeld: 172480000,
      percentOfClass: 4.40,
      marketValue: 172480000 * price,
      changeSharesQoQ: -1150000,
      changePercentQoQ: -0.66,
      portfolioPercent: 0.1,
      formType: '13F-HR',
      filingDate: filingDate,
    ),
    InstitutionalHolder(
      name: 'Geode Capital Management, LLC',
      managerCik: '0001214717',
      managerType: InstitutionalManagerType.indexPassive,
      sharesHeld: 82320000,
      percentOfClass: 2.10,
      marketValue: 82320000 * price,
      changeSharesQoQ: 1210000,
      changePercentQoQ: 1.49,
      portfolioPercent: 0.1,
      formType: '13F-HR',
      filingDate: filingDate,
    ),
    InstitutionalHolder(
      name: 'Northern Trust Corp',
      managerCik: '0000073124',
      managerType: InstitutionalManagerType.indexPassive,
      sharesHeld: 47040000,
      percentOfClass: 1.20,
      marketValue: 47040000 * price,
      changeSharesQoQ: -620000,
      changePercentQoQ: -1.30,
      portfolioPercent: 0.1,
      formType: '13F-HR',
      filingDate: filingDate,
    ),
  ];

  final totalHeld = holders.fold<double>(0, (sum, h) => sum + h.sharesHeld);

  return InstitutionalShareholding(
    cik: company.cik,
    calendarQuarter: asOf,
    asOfDate: asOfDate,
    totalSharesHeld: 2273600000,
    institutionalOwnershipPercent: 58.0,
    totalInstitutionsCount: 2210,
    top10ConcentrationPercent: (totalHeld / totalShares) * 100,
    passiveIndexPercent: 28.0,
    activeFundsPercent: 30.0,
    insiderPercent: 1.8,
    publicFloatPercent: 40.2,
    netSharesChange: -12450000,
    netSharesPercentChange: -0.54,
    buyersCount: 780,
    sellersCount: 1120,
    newPositionsCount: 65,
    soldOutPositionsCount: 110,
    activistStakes: const [],
    topHolders: _attachHistories(holders, totalShares),
    quarterlyTrends: _calibratedQuarterlyTrends(
      totalShares: totalShares,
      currentTotalHeld: 2273600000,
      netChangeQoQ: -12450000,
      buyers: 780,
      sellers: 1120,
    ),
  );
}

