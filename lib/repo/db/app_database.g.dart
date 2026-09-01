// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $CompaniesTable extends Companies
    with TableInfo<$CompaniesTable, CompanyRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CompaniesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _cikMeta = const VerificationMeta('cik');
  @override
  late final GeneratedColumn<String> cik = GeneratedColumn<String>(
    'cik',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sicMeta = const VerificationMeta('sic');
  @override
  late final GeneratedColumn<int> sic = GeneratedColumn<int>(
    'sic',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sharesOutstandingMeta = const VerificationMeta(
    'sharesOutstanding',
  );
  @override
  late final GeneratedColumn<double> sharesOutstanding =
      GeneratedColumn<double>(
        'shares_outstanding',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [cik, name, sic, sharesOutstanding];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'companies';
  @override
  VerificationContext validateIntegrity(
    Insertable<CompanyRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('cik')) {
      context.handle(
        _cikMeta,
        cik.isAcceptableOrUnknown(data['cik']!, _cikMeta),
      );
    } else if (isInserting) {
      context.missing(_cikMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('sic')) {
      context.handle(
        _sicMeta,
        sic.isAcceptableOrUnknown(data['sic']!, _sicMeta),
      );
    }
    if (data.containsKey('shares_outstanding')) {
      context.handle(
        _sharesOutstandingMeta,
        sharesOutstanding.isAcceptableOrUnknown(
          data['shares_outstanding']!,
          _sharesOutstandingMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {cik};
  @override
  CompanyRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CompanyRow(
      cik: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cik'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      sic: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sic'],
      ),
      sharesOutstanding: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}shares_outstanding'],
      ),
    );
  }

  @override
  $CompaniesTable createAlias(String alias) {
    return $CompaniesTable(attachedDatabase, alias);
  }
}

class CompanyRow extends DataClass implements Insertable<CompanyRow> {
  /// Ten-digit, zero-padded Central Index Key.
  final String cik;
  final String name;

  /// Standard Industrial Classification code, which is how SEC categorises a
  /// filer. Null where no dataset covering the company was found.
  final int? sic;

  /// Shares on the cover of the newest filing, for a market value.
  final double? sharesOutstanding;
  const CompanyRow({
    required this.cik,
    required this.name,
    this.sic,
    this.sharesOutstanding,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['cik'] = Variable<String>(cik);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || sic != null) {
      map['sic'] = Variable<int>(sic);
    }
    if (!nullToAbsent || sharesOutstanding != null) {
      map['shares_outstanding'] = Variable<double>(sharesOutstanding);
    }
    return map;
  }

  CompaniesCompanion toCompanion(bool nullToAbsent) {
    return CompaniesCompanion(
      cik: Value(cik),
      name: Value(name),
      sic: sic == null && nullToAbsent ? const Value.absent() : Value(sic),
      sharesOutstanding: sharesOutstanding == null && nullToAbsent
          ? const Value.absent()
          : Value(sharesOutstanding),
    );
  }

  factory CompanyRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CompanyRow(
      cik: serializer.fromJson<String>(json['cik']),
      name: serializer.fromJson<String>(json['name']),
      sic: serializer.fromJson<int?>(json['sic']),
      sharesOutstanding: serializer.fromJson<double?>(
        json['sharesOutstanding'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'cik': serializer.toJson<String>(cik),
      'name': serializer.toJson<String>(name),
      'sic': serializer.toJson<int?>(sic),
      'sharesOutstanding': serializer.toJson<double?>(sharesOutstanding),
    };
  }

  CompanyRow copyWith({
    String? cik,
    String? name,
    Value<int?> sic = const Value.absent(),
    Value<double?> sharesOutstanding = const Value.absent(),
  }) => CompanyRow(
    cik: cik ?? this.cik,
    name: name ?? this.name,
    sic: sic.present ? sic.value : this.sic,
    sharesOutstanding: sharesOutstanding.present
        ? sharesOutstanding.value
        : this.sharesOutstanding,
  );
  CompanyRow copyWithCompanion(CompaniesCompanion data) {
    return CompanyRow(
      cik: data.cik.present ? data.cik.value : this.cik,
      name: data.name.present ? data.name.value : this.name,
      sic: data.sic.present ? data.sic.value : this.sic,
      sharesOutstanding: data.sharesOutstanding.present
          ? data.sharesOutstanding.value
          : this.sharesOutstanding,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CompanyRow(')
          ..write('cik: $cik, ')
          ..write('name: $name, ')
          ..write('sic: $sic, ')
          ..write('sharesOutstanding: $sharesOutstanding')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(cik, name, sic, sharesOutstanding);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CompanyRow &&
          other.cik == this.cik &&
          other.name == this.name &&
          other.sic == this.sic &&
          other.sharesOutstanding == this.sharesOutstanding);
}

class CompaniesCompanion extends UpdateCompanion<CompanyRow> {
  final Value<String> cik;
  final Value<String> name;
  final Value<int?> sic;
  final Value<double?> sharesOutstanding;
  final Value<int> rowid;
  const CompaniesCompanion({
    this.cik = const Value.absent(),
    this.name = const Value.absent(),
    this.sic = const Value.absent(),
    this.sharesOutstanding = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CompaniesCompanion.insert({
    required String cik,
    required String name,
    this.sic = const Value.absent(),
    this.sharesOutstanding = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : cik = Value(cik),
       name = Value(name);
  static Insertable<CompanyRow> custom({
    Expression<String>? cik,
    Expression<String>? name,
    Expression<int>? sic,
    Expression<double>? sharesOutstanding,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (cik != null) 'cik': cik,
      if (name != null) 'name': name,
      if (sic != null) 'sic': sic,
      if (sharesOutstanding != null) 'shares_outstanding': sharesOutstanding,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CompaniesCompanion copyWith({
    Value<String>? cik,
    Value<String>? name,
    Value<int?>? sic,
    Value<double?>? sharesOutstanding,
    Value<int>? rowid,
  }) {
    return CompaniesCompanion(
      cik: cik ?? this.cik,
      name: name ?? this.name,
      sic: sic ?? this.sic,
      sharesOutstanding: sharesOutstanding ?? this.sharesOutstanding,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (cik.present) {
      map['cik'] = Variable<String>(cik.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (sic.present) {
      map['sic'] = Variable<int>(sic.value);
    }
    if (sharesOutstanding.present) {
      map['shares_outstanding'] = Variable<double>(sharesOutstanding.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CompaniesCompanion(')
          ..write('cik: $cik, ')
          ..write('name: $name, ')
          ..write('sic: $sic, ')
          ..write('sharesOutstanding: $sharesOutstanding, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TickersTable extends Tickers with TableInfo<$TickersTable, TickerRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TickersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _symbolMeta = const VerificationMeta('symbol');
  @override
  late final GeneratedColumn<String> symbol = GeneratedColumn<String>(
    'symbol',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cikMeta = const VerificationMeta('cik');
  @override
  late final GeneratedColumn<String> cik = GeneratedColumn<String>(
    'cik',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [symbol, cik, name];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tickers';
  @override
  VerificationContext validateIntegrity(
    Insertable<TickerRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('symbol')) {
      context.handle(
        _symbolMeta,
        symbol.isAcceptableOrUnknown(data['symbol']!, _symbolMeta),
      );
    } else if (isInserting) {
      context.missing(_symbolMeta);
    }
    if (data.containsKey('cik')) {
      context.handle(
        _cikMeta,
        cik.isAcceptableOrUnknown(data['cik']!, _cikMeta),
      );
    } else if (isInserting) {
      context.missing(_cikMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {symbol};
  @override
  TickerRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TickerRow(
      symbol: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}symbol'],
      )!,
      cik: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cik'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
    );
  }

  @override
  $TickersTable createAlias(String alias) {
    return $TickersTable(attachedDatabase, alias);
  }
}

class TickerRow extends DataClass implements Insertable<TickerRow> {
  final String symbol;
  final String cik;
  final String name;
  const TickerRow({
    required this.symbol,
    required this.cik,
    required this.name,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['symbol'] = Variable<String>(symbol);
    map['cik'] = Variable<String>(cik);
    map['name'] = Variable<String>(name);
    return map;
  }

  TickersCompanion toCompanion(bool nullToAbsent) {
    return TickersCompanion(
      symbol: Value(symbol),
      cik: Value(cik),
      name: Value(name),
    );
  }

  factory TickerRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TickerRow(
      symbol: serializer.fromJson<String>(json['symbol']),
      cik: serializer.fromJson<String>(json['cik']),
      name: serializer.fromJson<String>(json['name']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'symbol': serializer.toJson<String>(symbol),
      'cik': serializer.toJson<String>(cik),
      'name': serializer.toJson<String>(name),
    };
  }

  TickerRow copyWith({String? symbol, String? cik, String? name}) => TickerRow(
    symbol: symbol ?? this.symbol,
    cik: cik ?? this.cik,
    name: name ?? this.name,
  );
  TickerRow copyWithCompanion(TickersCompanion data) {
    return TickerRow(
      symbol: data.symbol.present ? data.symbol.value : this.symbol,
      cik: data.cik.present ? data.cik.value : this.cik,
      name: data.name.present ? data.name.value : this.name,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TickerRow(')
          ..write('symbol: $symbol, ')
          ..write('cik: $cik, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(symbol, cik, name);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TickerRow &&
          other.symbol == this.symbol &&
          other.cik == this.cik &&
          other.name == this.name);
}

class TickersCompanion extends UpdateCompanion<TickerRow> {
  final Value<String> symbol;
  final Value<String> cik;
  final Value<String> name;
  final Value<int> rowid;
  const TickersCompanion({
    this.symbol = const Value.absent(),
    this.cik = const Value.absent(),
    this.name = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TickersCompanion.insert({
    required String symbol,
    required String cik,
    required String name,
    this.rowid = const Value.absent(),
  }) : symbol = Value(symbol),
       cik = Value(cik),
       name = Value(name);
  static Insertable<TickerRow> custom({
    Expression<String>? symbol,
    Expression<String>? cik,
    Expression<String>? name,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (symbol != null) 'symbol': symbol,
      if (cik != null) 'cik': cik,
      if (name != null) 'name': name,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TickersCompanion copyWith({
    Value<String>? symbol,
    Value<String>? cik,
    Value<String>? name,
    Value<int>? rowid,
  }) {
    return TickersCompanion(
      symbol: symbol ?? this.symbol,
      cik: cik ?? this.cik,
      name: name ?? this.name,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (symbol.present) {
      map['symbol'] = Variable<String>(symbol.value);
    }
    if (cik.present) {
      map['cik'] = Variable<String>(cik.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TickersCompanion(')
          ..write('symbol: $symbol, ')
          ..write('cik: $cik, ')
          ..write('name: $name, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FiscalYearsTable extends FiscalYears
    with TableInfo<$FiscalYearsTable, FiscalYearRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FiscalYearsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _cikMeta = const VerificationMeta('cik');
  @override
  late final GeneratedColumn<String> cik = GeneratedColumn<String>(
    'cik',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES companies (cik)',
    ),
  );
  static const VerificationMeta _fiscalYearMeta = const VerificationMeta(
    'fiscalYear',
  );
  @override
  late final GeneratedColumn<int> fiscalYear = GeneratedColumn<int>(
    'fiscal_year',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _revenueMeta = const VerificationMeta(
    'revenue',
  );
  @override
  late final GeneratedColumn<double> revenue = GeneratedColumn<double>(
    'revenue',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _netIncomeMeta = const VerificationMeta(
    'netIncome',
  );
  @override
  late final GeneratedColumn<double> netIncome = GeneratedColumn<double>(
    'net_income',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _operatingCashFlowMeta = const VerificationMeta(
    'operatingCashFlow',
  );
  @override
  late final GeneratedColumn<double> operatingCashFlow =
      GeneratedColumn<double>(
        'operating_cash_flow',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _capitalExpenditureMeta =
      const VerificationMeta('capitalExpenditure');
  @override
  late final GeneratedColumn<double> capitalExpenditure =
      GeneratedColumn<double>(
        'capital_expenditure',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _totalDebtMeta = const VerificationMeta(
    'totalDebt',
  );
  @override
  late final GeneratedColumn<double> totalDebt = GeneratedColumn<double>(
    'total_debt',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cashMeta = const VerificationMeta('cash');
  @override
  late final GeneratedColumn<double> cash = GeneratedColumn<double>(
    'cash',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dilutedSharesMeta = const VerificationMeta(
    'dilutedShares',
  );
  @override
  late final GeneratedColumn<double> dilutedShares = GeneratedColumn<double>(
    'diluted_shares',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _operatingIncomeMeta = const VerificationMeta(
    'operatingIncome',
  );
  @override
  late final GeneratedColumn<double> operatingIncome = GeneratedColumn<double>(
    'operating_income',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _depreciationAmortisationMeta =
      const VerificationMeta('depreciationAmortisation');
  @override
  late final GeneratedColumn<double> depreciationAmortisation =
      GeneratedColumn<double>(
        'depreciation_amortisation',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _totalAssetsMeta = const VerificationMeta(
    'totalAssets',
  );
  @override
  late final GeneratedColumn<double> totalAssets = GeneratedColumn<double>(
    'total_assets',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _shareholdersEquityMeta =
      const VerificationMeta('shareholdersEquity');
  @override
  late final GeneratedColumn<double> shareholdersEquity =
      GeneratedColumn<double>(
        'shareholders_equity',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    cik,
    fiscalYear,
    revenue,
    netIncome,
    operatingCashFlow,
    capitalExpenditure,
    totalDebt,
    cash,
    dilutedShares,
    operatingIncome,
    depreciationAmortisation,
    totalAssets,
    shareholdersEquity,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'fiscal_years';
  @override
  VerificationContext validateIntegrity(
    Insertable<FiscalYearRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('cik')) {
      context.handle(
        _cikMeta,
        cik.isAcceptableOrUnknown(data['cik']!, _cikMeta),
      );
    } else if (isInserting) {
      context.missing(_cikMeta);
    }
    if (data.containsKey('fiscal_year')) {
      context.handle(
        _fiscalYearMeta,
        fiscalYear.isAcceptableOrUnknown(data['fiscal_year']!, _fiscalYearMeta),
      );
    } else if (isInserting) {
      context.missing(_fiscalYearMeta);
    }
    if (data.containsKey('revenue')) {
      context.handle(
        _revenueMeta,
        revenue.isAcceptableOrUnknown(data['revenue']!, _revenueMeta),
      );
    }
    if (data.containsKey('net_income')) {
      context.handle(
        _netIncomeMeta,
        netIncome.isAcceptableOrUnknown(data['net_income']!, _netIncomeMeta),
      );
    }
    if (data.containsKey('operating_cash_flow')) {
      context.handle(
        _operatingCashFlowMeta,
        operatingCashFlow.isAcceptableOrUnknown(
          data['operating_cash_flow']!,
          _operatingCashFlowMeta,
        ),
      );
    }
    if (data.containsKey('capital_expenditure')) {
      context.handle(
        _capitalExpenditureMeta,
        capitalExpenditure.isAcceptableOrUnknown(
          data['capital_expenditure']!,
          _capitalExpenditureMeta,
        ),
      );
    }
    if (data.containsKey('total_debt')) {
      context.handle(
        _totalDebtMeta,
        totalDebt.isAcceptableOrUnknown(data['total_debt']!, _totalDebtMeta),
      );
    }
    if (data.containsKey('cash')) {
      context.handle(
        _cashMeta,
        cash.isAcceptableOrUnknown(data['cash']!, _cashMeta),
      );
    }
    if (data.containsKey('diluted_shares')) {
      context.handle(
        _dilutedSharesMeta,
        dilutedShares.isAcceptableOrUnknown(
          data['diluted_shares']!,
          _dilutedSharesMeta,
        ),
      );
    }
    if (data.containsKey('operating_income')) {
      context.handle(
        _operatingIncomeMeta,
        operatingIncome.isAcceptableOrUnknown(
          data['operating_income']!,
          _operatingIncomeMeta,
        ),
      );
    }
    if (data.containsKey('depreciation_amortisation')) {
      context.handle(
        _depreciationAmortisationMeta,
        depreciationAmortisation.isAcceptableOrUnknown(
          data['depreciation_amortisation']!,
          _depreciationAmortisationMeta,
        ),
      );
    }
    if (data.containsKey('total_assets')) {
      context.handle(
        _totalAssetsMeta,
        totalAssets.isAcceptableOrUnknown(
          data['total_assets']!,
          _totalAssetsMeta,
        ),
      );
    }
    if (data.containsKey('shareholders_equity')) {
      context.handle(
        _shareholdersEquityMeta,
        shareholdersEquity.isAcceptableOrUnknown(
          data['shareholders_equity']!,
          _shareholdersEquityMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {cik, fiscalYear};
  @override
  FiscalYearRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FiscalYearRow(
      cik: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cik'],
      )!,
      fiscalYear: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}fiscal_year'],
      )!,
      revenue: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}revenue'],
      ),
      netIncome: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}net_income'],
      ),
      operatingCashFlow: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}operating_cash_flow'],
      ),
      capitalExpenditure: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}capital_expenditure'],
      ),
      totalDebt: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}total_debt'],
      ),
      cash: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}cash'],
      ),
      dilutedShares: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}diluted_shares'],
      ),
      operatingIncome: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}operating_income'],
      ),
      depreciationAmortisation: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}depreciation_amortisation'],
      ),
      totalAssets: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}total_assets'],
      ),
      shareholdersEquity: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}shareholders_equity'],
      ),
    );
  }

  @override
  $FiscalYearsTable createAlias(String alias) {
    return $FiscalYearsTable(attachedDatabase, alias);
  }
}

class FiscalYearRow extends DataClass implements Insertable<FiscalYearRow> {
  final String cik;
  final int fiscalYear;
  final double? revenue;
  final double? netIncome;
  final double? operatingCashFlow;
  final double? capitalExpenditure;
  final double? totalDebt;
  final double? cash;
  final double? dilutedShares;
  final double? operatingIncome;
  final double? depreciationAmortisation;
  final double? totalAssets;
  final double? shareholdersEquity;
  const FiscalYearRow({
    required this.cik,
    required this.fiscalYear,
    this.revenue,
    this.netIncome,
    this.operatingCashFlow,
    this.capitalExpenditure,
    this.totalDebt,
    this.cash,
    this.dilutedShares,
    this.operatingIncome,
    this.depreciationAmortisation,
    this.totalAssets,
    this.shareholdersEquity,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['cik'] = Variable<String>(cik);
    map['fiscal_year'] = Variable<int>(fiscalYear);
    if (!nullToAbsent || revenue != null) {
      map['revenue'] = Variable<double>(revenue);
    }
    if (!nullToAbsent || netIncome != null) {
      map['net_income'] = Variable<double>(netIncome);
    }
    if (!nullToAbsent || operatingCashFlow != null) {
      map['operating_cash_flow'] = Variable<double>(operatingCashFlow);
    }
    if (!nullToAbsent || capitalExpenditure != null) {
      map['capital_expenditure'] = Variable<double>(capitalExpenditure);
    }
    if (!nullToAbsent || totalDebt != null) {
      map['total_debt'] = Variable<double>(totalDebt);
    }
    if (!nullToAbsent || cash != null) {
      map['cash'] = Variable<double>(cash);
    }
    if (!nullToAbsent || dilutedShares != null) {
      map['diluted_shares'] = Variable<double>(dilutedShares);
    }
    if (!nullToAbsent || operatingIncome != null) {
      map['operating_income'] = Variable<double>(operatingIncome);
    }
    if (!nullToAbsent || depreciationAmortisation != null) {
      map['depreciation_amortisation'] = Variable<double>(
        depreciationAmortisation,
      );
    }
    if (!nullToAbsent || totalAssets != null) {
      map['total_assets'] = Variable<double>(totalAssets);
    }
    if (!nullToAbsent || shareholdersEquity != null) {
      map['shareholders_equity'] = Variable<double>(shareholdersEquity);
    }
    return map;
  }

  FiscalYearsCompanion toCompanion(bool nullToAbsent) {
    return FiscalYearsCompanion(
      cik: Value(cik),
      fiscalYear: Value(fiscalYear),
      revenue: revenue == null && nullToAbsent
          ? const Value.absent()
          : Value(revenue),
      netIncome: netIncome == null && nullToAbsent
          ? const Value.absent()
          : Value(netIncome),
      operatingCashFlow: operatingCashFlow == null && nullToAbsent
          ? const Value.absent()
          : Value(operatingCashFlow),
      capitalExpenditure: capitalExpenditure == null && nullToAbsent
          ? const Value.absent()
          : Value(capitalExpenditure),
      totalDebt: totalDebt == null && nullToAbsent
          ? const Value.absent()
          : Value(totalDebt),
      cash: cash == null && nullToAbsent ? const Value.absent() : Value(cash),
      dilutedShares: dilutedShares == null && nullToAbsent
          ? const Value.absent()
          : Value(dilutedShares),
      operatingIncome: operatingIncome == null && nullToAbsent
          ? const Value.absent()
          : Value(operatingIncome),
      depreciationAmortisation: depreciationAmortisation == null && nullToAbsent
          ? const Value.absent()
          : Value(depreciationAmortisation),
      totalAssets: totalAssets == null && nullToAbsent
          ? const Value.absent()
          : Value(totalAssets),
      shareholdersEquity: shareholdersEquity == null && nullToAbsent
          ? const Value.absent()
          : Value(shareholdersEquity),
    );
  }

  factory FiscalYearRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FiscalYearRow(
      cik: serializer.fromJson<String>(json['cik']),
      fiscalYear: serializer.fromJson<int>(json['fiscalYear']),
      revenue: serializer.fromJson<double?>(json['revenue']),
      netIncome: serializer.fromJson<double?>(json['netIncome']),
      operatingCashFlow: serializer.fromJson<double?>(
        json['operatingCashFlow'],
      ),
      capitalExpenditure: serializer.fromJson<double?>(
        json['capitalExpenditure'],
      ),
      totalDebt: serializer.fromJson<double?>(json['totalDebt']),
      cash: serializer.fromJson<double?>(json['cash']),
      dilutedShares: serializer.fromJson<double?>(json['dilutedShares']),
      operatingIncome: serializer.fromJson<double?>(json['operatingIncome']),
      depreciationAmortisation: serializer.fromJson<double?>(
        json['depreciationAmortisation'],
      ),
      totalAssets: serializer.fromJson<double?>(json['totalAssets']),
      shareholdersEquity: serializer.fromJson<double?>(
        json['shareholdersEquity'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'cik': serializer.toJson<String>(cik),
      'fiscalYear': serializer.toJson<int>(fiscalYear),
      'revenue': serializer.toJson<double?>(revenue),
      'netIncome': serializer.toJson<double?>(netIncome),
      'operatingCashFlow': serializer.toJson<double?>(operatingCashFlow),
      'capitalExpenditure': serializer.toJson<double?>(capitalExpenditure),
      'totalDebt': serializer.toJson<double?>(totalDebt),
      'cash': serializer.toJson<double?>(cash),
      'dilutedShares': serializer.toJson<double?>(dilutedShares),
      'operatingIncome': serializer.toJson<double?>(operatingIncome),
      'depreciationAmortisation': serializer.toJson<double?>(
        depreciationAmortisation,
      ),
      'totalAssets': serializer.toJson<double?>(totalAssets),
      'shareholdersEquity': serializer.toJson<double?>(shareholdersEquity),
    };
  }

  FiscalYearRow copyWith({
    String? cik,
    int? fiscalYear,
    Value<double?> revenue = const Value.absent(),
    Value<double?> netIncome = const Value.absent(),
    Value<double?> operatingCashFlow = const Value.absent(),
    Value<double?> capitalExpenditure = const Value.absent(),
    Value<double?> totalDebt = const Value.absent(),
    Value<double?> cash = const Value.absent(),
    Value<double?> dilutedShares = const Value.absent(),
    Value<double?> operatingIncome = const Value.absent(),
    Value<double?> depreciationAmortisation = const Value.absent(),
    Value<double?> totalAssets = const Value.absent(),
    Value<double?> shareholdersEquity = const Value.absent(),
  }) => FiscalYearRow(
    cik: cik ?? this.cik,
    fiscalYear: fiscalYear ?? this.fiscalYear,
    revenue: revenue.present ? revenue.value : this.revenue,
    netIncome: netIncome.present ? netIncome.value : this.netIncome,
    operatingCashFlow: operatingCashFlow.present
        ? operatingCashFlow.value
        : this.operatingCashFlow,
    capitalExpenditure: capitalExpenditure.present
        ? capitalExpenditure.value
        : this.capitalExpenditure,
    totalDebt: totalDebt.present ? totalDebt.value : this.totalDebt,
    cash: cash.present ? cash.value : this.cash,
    dilutedShares: dilutedShares.present
        ? dilutedShares.value
        : this.dilutedShares,
    operatingIncome: operatingIncome.present
        ? operatingIncome.value
        : this.operatingIncome,
    depreciationAmortisation: depreciationAmortisation.present
        ? depreciationAmortisation.value
        : this.depreciationAmortisation,
    totalAssets: totalAssets.present ? totalAssets.value : this.totalAssets,
    shareholdersEquity: shareholdersEquity.present
        ? shareholdersEquity.value
        : this.shareholdersEquity,
  );
  FiscalYearRow copyWithCompanion(FiscalYearsCompanion data) {
    return FiscalYearRow(
      cik: data.cik.present ? data.cik.value : this.cik,
      fiscalYear: data.fiscalYear.present
          ? data.fiscalYear.value
          : this.fiscalYear,
      revenue: data.revenue.present ? data.revenue.value : this.revenue,
      netIncome: data.netIncome.present ? data.netIncome.value : this.netIncome,
      operatingCashFlow: data.operatingCashFlow.present
          ? data.operatingCashFlow.value
          : this.operatingCashFlow,
      capitalExpenditure: data.capitalExpenditure.present
          ? data.capitalExpenditure.value
          : this.capitalExpenditure,
      totalDebt: data.totalDebt.present ? data.totalDebt.value : this.totalDebt,
      cash: data.cash.present ? data.cash.value : this.cash,
      dilutedShares: data.dilutedShares.present
          ? data.dilutedShares.value
          : this.dilutedShares,
      operatingIncome: data.operatingIncome.present
          ? data.operatingIncome.value
          : this.operatingIncome,
      depreciationAmortisation: data.depreciationAmortisation.present
          ? data.depreciationAmortisation.value
          : this.depreciationAmortisation,
      totalAssets: data.totalAssets.present
          ? data.totalAssets.value
          : this.totalAssets,
      shareholdersEquity: data.shareholdersEquity.present
          ? data.shareholdersEquity.value
          : this.shareholdersEquity,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FiscalYearRow(')
          ..write('cik: $cik, ')
          ..write('fiscalYear: $fiscalYear, ')
          ..write('revenue: $revenue, ')
          ..write('netIncome: $netIncome, ')
          ..write('operatingCashFlow: $operatingCashFlow, ')
          ..write('capitalExpenditure: $capitalExpenditure, ')
          ..write('totalDebt: $totalDebt, ')
          ..write('cash: $cash, ')
          ..write('dilutedShares: $dilutedShares, ')
          ..write('operatingIncome: $operatingIncome, ')
          ..write('depreciationAmortisation: $depreciationAmortisation, ')
          ..write('totalAssets: $totalAssets, ')
          ..write('shareholdersEquity: $shareholdersEquity')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    cik,
    fiscalYear,
    revenue,
    netIncome,
    operatingCashFlow,
    capitalExpenditure,
    totalDebt,
    cash,
    dilutedShares,
    operatingIncome,
    depreciationAmortisation,
    totalAssets,
    shareholdersEquity,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FiscalYearRow &&
          other.cik == this.cik &&
          other.fiscalYear == this.fiscalYear &&
          other.revenue == this.revenue &&
          other.netIncome == this.netIncome &&
          other.operatingCashFlow == this.operatingCashFlow &&
          other.capitalExpenditure == this.capitalExpenditure &&
          other.totalDebt == this.totalDebt &&
          other.cash == this.cash &&
          other.dilutedShares == this.dilutedShares &&
          other.operatingIncome == this.operatingIncome &&
          other.depreciationAmortisation == this.depreciationAmortisation &&
          other.totalAssets == this.totalAssets &&
          other.shareholdersEquity == this.shareholdersEquity);
}

class FiscalYearsCompanion extends UpdateCompanion<FiscalYearRow> {
  final Value<String> cik;
  final Value<int> fiscalYear;
  final Value<double?> revenue;
  final Value<double?> netIncome;
  final Value<double?> operatingCashFlow;
  final Value<double?> capitalExpenditure;
  final Value<double?> totalDebt;
  final Value<double?> cash;
  final Value<double?> dilutedShares;
  final Value<double?> operatingIncome;
  final Value<double?> depreciationAmortisation;
  final Value<double?> totalAssets;
  final Value<double?> shareholdersEquity;
  final Value<int> rowid;
  const FiscalYearsCompanion({
    this.cik = const Value.absent(),
    this.fiscalYear = const Value.absent(),
    this.revenue = const Value.absent(),
    this.netIncome = const Value.absent(),
    this.operatingCashFlow = const Value.absent(),
    this.capitalExpenditure = const Value.absent(),
    this.totalDebt = const Value.absent(),
    this.cash = const Value.absent(),
    this.dilutedShares = const Value.absent(),
    this.operatingIncome = const Value.absent(),
    this.depreciationAmortisation = const Value.absent(),
    this.totalAssets = const Value.absent(),
    this.shareholdersEquity = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FiscalYearsCompanion.insert({
    required String cik,
    required int fiscalYear,
    this.revenue = const Value.absent(),
    this.netIncome = const Value.absent(),
    this.operatingCashFlow = const Value.absent(),
    this.capitalExpenditure = const Value.absent(),
    this.totalDebt = const Value.absent(),
    this.cash = const Value.absent(),
    this.dilutedShares = const Value.absent(),
    this.operatingIncome = const Value.absent(),
    this.depreciationAmortisation = const Value.absent(),
    this.totalAssets = const Value.absent(),
    this.shareholdersEquity = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : cik = Value(cik),
       fiscalYear = Value(fiscalYear);
  static Insertable<FiscalYearRow> custom({
    Expression<String>? cik,
    Expression<int>? fiscalYear,
    Expression<double>? revenue,
    Expression<double>? netIncome,
    Expression<double>? operatingCashFlow,
    Expression<double>? capitalExpenditure,
    Expression<double>? totalDebt,
    Expression<double>? cash,
    Expression<double>? dilutedShares,
    Expression<double>? operatingIncome,
    Expression<double>? depreciationAmortisation,
    Expression<double>? totalAssets,
    Expression<double>? shareholdersEquity,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (cik != null) 'cik': cik,
      if (fiscalYear != null) 'fiscal_year': fiscalYear,
      if (revenue != null) 'revenue': revenue,
      if (netIncome != null) 'net_income': netIncome,
      if (operatingCashFlow != null) 'operating_cash_flow': operatingCashFlow,
      if (capitalExpenditure != null) 'capital_expenditure': capitalExpenditure,
      if (totalDebt != null) 'total_debt': totalDebt,
      if (cash != null) 'cash': cash,
      if (dilutedShares != null) 'diluted_shares': dilutedShares,
      if (operatingIncome != null) 'operating_income': operatingIncome,
      if (depreciationAmortisation != null)
        'depreciation_amortisation': depreciationAmortisation,
      if (totalAssets != null) 'total_assets': totalAssets,
      if (shareholdersEquity != null) 'shareholders_equity': shareholdersEquity,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FiscalYearsCompanion copyWith({
    Value<String>? cik,
    Value<int>? fiscalYear,
    Value<double?>? revenue,
    Value<double?>? netIncome,
    Value<double?>? operatingCashFlow,
    Value<double?>? capitalExpenditure,
    Value<double?>? totalDebt,
    Value<double?>? cash,
    Value<double?>? dilutedShares,
    Value<double?>? operatingIncome,
    Value<double?>? depreciationAmortisation,
    Value<double?>? totalAssets,
    Value<double?>? shareholdersEquity,
    Value<int>? rowid,
  }) {
    return FiscalYearsCompanion(
      cik: cik ?? this.cik,
      fiscalYear: fiscalYear ?? this.fiscalYear,
      revenue: revenue ?? this.revenue,
      netIncome: netIncome ?? this.netIncome,
      operatingCashFlow: operatingCashFlow ?? this.operatingCashFlow,
      capitalExpenditure: capitalExpenditure ?? this.capitalExpenditure,
      totalDebt: totalDebt ?? this.totalDebt,
      cash: cash ?? this.cash,
      dilutedShares: dilutedShares ?? this.dilutedShares,
      operatingIncome: operatingIncome ?? this.operatingIncome,
      depreciationAmortisation:
          depreciationAmortisation ?? this.depreciationAmortisation,
      totalAssets: totalAssets ?? this.totalAssets,
      shareholdersEquity: shareholdersEquity ?? this.shareholdersEquity,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (cik.present) {
      map['cik'] = Variable<String>(cik.value);
    }
    if (fiscalYear.present) {
      map['fiscal_year'] = Variable<int>(fiscalYear.value);
    }
    if (revenue.present) {
      map['revenue'] = Variable<double>(revenue.value);
    }
    if (netIncome.present) {
      map['net_income'] = Variable<double>(netIncome.value);
    }
    if (operatingCashFlow.present) {
      map['operating_cash_flow'] = Variable<double>(operatingCashFlow.value);
    }
    if (capitalExpenditure.present) {
      map['capital_expenditure'] = Variable<double>(capitalExpenditure.value);
    }
    if (totalDebt.present) {
      map['total_debt'] = Variable<double>(totalDebt.value);
    }
    if (cash.present) {
      map['cash'] = Variable<double>(cash.value);
    }
    if (dilutedShares.present) {
      map['diluted_shares'] = Variable<double>(dilutedShares.value);
    }
    if (operatingIncome.present) {
      map['operating_income'] = Variable<double>(operatingIncome.value);
    }
    if (depreciationAmortisation.present) {
      map['depreciation_amortisation'] = Variable<double>(
        depreciationAmortisation.value,
      );
    }
    if (totalAssets.present) {
      map['total_assets'] = Variable<double>(totalAssets.value);
    }
    if (shareholdersEquity.present) {
      map['shareholders_equity'] = Variable<double>(shareholdersEquity.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FiscalYearsCompanion(')
          ..write('cik: $cik, ')
          ..write('fiscalYear: $fiscalYear, ')
          ..write('revenue: $revenue, ')
          ..write('netIncome: $netIncome, ')
          ..write('operatingCashFlow: $operatingCashFlow, ')
          ..write('capitalExpenditure: $capitalExpenditure, ')
          ..write('totalDebt: $totalDebt, ')
          ..write('cash: $cash, ')
          ..write('dilutedShares: $dilutedShares, ')
          ..write('operatingIncome: $operatingIncome, ')
          ..write('depreciationAmortisation: $depreciationAmortisation, ')
          ..write('totalAssets: $totalAssets, ')
          ..write('shareholdersEquity: $shareholdersEquity, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FiscalQuartersTable extends FiscalQuarters
    with TableInfo<$FiscalQuartersTable, FiscalQuarterRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FiscalQuartersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _cikMeta = const VerificationMeta('cik');
  @override
  late final GeneratedColumn<String> cik = GeneratedColumn<String>(
    'cik',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES companies (cik)',
    ),
  );
  static const VerificationMeta _fiscalYearMeta = const VerificationMeta(
    'fiscalYear',
  );
  @override
  late final GeneratedColumn<int> fiscalYear = GeneratedColumn<int>(
    'fiscal_year',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quarterMeta = const VerificationMeta(
    'quarter',
  );
  @override
  late final GeneratedColumn<int> quarter = GeneratedColumn<int>(
    'quarter',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _revenueMeta = const VerificationMeta(
    'revenue',
  );
  @override
  late final GeneratedColumn<double> revenue = GeneratedColumn<double>(
    'revenue',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _netIncomeMeta = const VerificationMeta(
    'netIncome',
  );
  @override
  late final GeneratedColumn<double> netIncome = GeneratedColumn<double>(
    'net_income',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _operatingCashFlowMeta = const VerificationMeta(
    'operatingCashFlow',
  );
  @override
  late final GeneratedColumn<double> operatingCashFlow =
      GeneratedColumn<double>(
        'operating_cash_flow',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _capitalExpenditureMeta =
      const VerificationMeta('capitalExpenditure');
  @override
  late final GeneratedColumn<double> capitalExpenditure =
      GeneratedColumn<double>(
        'capital_expenditure',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _totalDebtMeta = const VerificationMeta(
    'totalDebt',
  );
  @override
  late final GeneratedColumn<double> totalDebt = GeneratedColumn<double>(
    'total_debt',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cashMeta = const VerificationMeta('cash');
  @override
  late final GeneratedColumn<double> cash = GeneratedColumn<double>(
    'cash',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    cik,
    fiscalYear,
    quarter,
    revenue,
    netIncome,
    operatingCashFlow,
    capitalExpenditure,
    totalDebt,
    cash,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'fiscal_quarters';
  @override
  VerificationContext validateIntegrity(
    Insertable<FiscalQuarterRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('cik')) {
      context.handle(
        _cikMeta,
        cik.isAcceptableOrUnknown(data['cik']!, _cikMeta),
      );
    } else if (isInserting) {
      context.missing(_cikMeta);
    }
    if (data.containsKey('fiscal_year')) {
      context.handle(
        _fiscalYearMeta,
        fiscalYear.isAcceptableOrUnknown(data['fiscal_year']!, _fiscalYearMeta),
      );
    } else if (isInserting) {
      context.missing(_fiscalYearMeta);
    }
    if (data.containsKey('quarter')) {
      context.handle(
        _quarterMeta,
        quarter.isAcceptableOrUnknown(data['quarter']!, _quarterMeta),
      );
    } else if (isInserting) {
      context.missing(_quarterMeta);
    }
    if (data.containsKey('revenue')) {
      context.handle(
        _revenueMeta,
        revenue.isAcceptableOrUnknown(data['revenue']!, _revenueMeta),
      );
    }
    if (data.containsKey('net_income')) {
      context.handle(
        _netIncomeMeta,
        netIncome.isAcceptableOrUnknown(data['net_income']!, _netIncomeMeta),
      );
    }
    if (data.containsKey('operating_cash_flow')) {
      context.handle(
        _operatingCashFlowMeta,
        operatingCashFlow.isAcceptableOrUnknown(
          data['operating_cash_flow']!,
          _operatingCashFlowMeta,
        ),
      );
    }
    if (data.containsKey('capital_expenditure')) {
      context.handle(
        _capitalExpenditureMeta,
        capitalExpenditure.isAcceptableOrUnknown(
          data['capital_expenditure']!,
          _capitalExpenditureMeta,
        ),
      );
    }
    if (data.containsKey('total_debt')) {
      context.handle(
        _totalDebtMeta,
        totalDebt.isAcceptableOrUnknown(data['total_debt']!, _totalDebtMeta),
      );
    }
    if (data.containsKey('cash')) {
      context.handle(
        _cashMeta,
        cash.isAcceptableOrUnknown(data['cash']!, _cashMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {cik, fiscalYear, quarter};
  @override
  FiscalQuarterRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FiscalQuarterRow(
      cik: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cik'],
      )!,
      fiscalYear: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}fiscal_year'],
      )!,
      quarter: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}quarter'],
      )!,
      revenue: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}revenue'],
      ),
      netIncome: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}net_income'],
      ),
      operatingCashFlow: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}operating_cash_flow'],
      ),
      capitalExpenditure: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}capital_expenditure'],
      ),
      totalDebt: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}total_debt'],
      ),
      cash: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}cash'],
      ),
    );
  }

  @override
  $FiscalQuartersTable createAlias(String alias) {
    return $FiscalQuartersTable(attachedDatabase, alias);
  }
}

class FiscalQuarterRow extends DataClass
    implements Insertable<FiscalQuarterRow> {
  final String cik;
  final int fiscalYear;
  final int quarter;
  final double? revenue;
  final double? netIncome;
  final double? operatingCashFlow;
  final double? capitalExpenditure;
  final double? totalDebt;
  final double? cash;
  const FiscalQuarterRow({
    required this.cik,
    required this.fiscalYear,
    required this.quarter,
    this.revenue,
    this.netIncome,
    this.operatingCashFlow,
    this.capitalExpenditure,
    this.totalDebt,
    this.cash,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['cik'] = Variable<String>(cik);
    map['fiscal_year'] = Variable<int>(fiscalYear);
    map['quarter'] = Variable<int>(quarter);
    if (!nullToAbsent || revenue != null) {
      map['revenue'] = Variable<double>(revenue);
    }
    if (!nullToAbsent || netIncome != null) {
      map['net_income'] = Variable<double>(netIncome);
    }
    if (!nullToAbsent || operatingCashFlow != null) {
      map['operating_cash_flow'] = Variable<double>(operatingCashFlow);
    }
    if (!nullToAbsent || capitalExpenditure != null) {
      map['capital_expenditure'] = Variable<double>(capitalExpenditure);
    }
    if (!nullToAbsent || totalDebt != null) {
      map['total_debt'] = Variable<double>(totalDebt);
    }
    if (!nullToAbsent || cash != null) {
      map['cash'] = Variable<double>(cash);
    }
    return map;
  }

  FiscalQuartersCompanion toCompanion(bool nullToAbsent) {
    return FiscalQuartersCompanion(
      cik: Value(cik),
      fiscalYear: Value(fiscalYear),
      quarter: Value(quarter),
      revenue: revenue == null && nullToAbsent
          ? const Value.absent()
          : Value(revenue),
      netIncome: netIncome == null && nullToAbsent
          ? const Value.absent()
          : Value(netIncome),
      operatingCashFlow: operatingCashFlow == null && nullToAbsent
          ? const Value.absent()
          : Value(operatingCashFlow),
      capitalExpenditure: capitalExpenditure == null && nullToAbsent
          ? const Value.absent()
          : Value(capitalExpenditure),
      totalDebt: totalDebt == null && nullToAbsent
          ? const Value.absent()
          : Value(totalDebt),
      cash: cash == null && nullToAbsent ? const Value.absent() : Value(cash),
    );
  }

  factory FiscalQuarterRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FiscalQuarterRow(
      cik: serializer.fromJson<String>(json['cik']),
      fiscalYear: serializer.fromJson<int>(json['fiscalYear']),
      quarter: serializer.fromJson<int>(json['quarter']),
      revenue: serializer.fromJson<double?>(json['revenue']),
      netIncome: serializer.fromJson<double?>(json['netIncome']),
      operatingCashFlow: serializer.fromJson<double?>(
        json['operatingCashFlow'],
      ),
      capitalExpenditure: serializer.fromJson<double?>(
        json['capitalExpenditure'],
      ),
      totalDebt: serializer.fromJson<double?>(json['totalDebt']),
      cash: serializer.fromJson<double?>(json['cash']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'cik': serializer.toJson<String>(cik),
      'fiscalYear': serializer.toJson<int>(fiscalYear),
      'quarter': serializer.toJson<int>(quarter),
      'revenue': serializer.toJson<double?>(revenue),
      'netIncome': serializer.toJson<double?>(netIncome),
      'operatingCashFlow': serializer.toJson<double?>(operatingCashFlow),
      'capitalExpenditure': serializer.toJson<double?>(capitalExpenditure),
      'totalDebt': serializer.toJson<double?>(totalDebt),
      'cash': serializer.toJson<double?>(cash),
    };
  }

  FiscalQuarterRow copyWith({
    String? cik,
    int? fiscalYear,
    int? quarter,
    Value<double?> revenue = const Value.absent(),
    Value<double?> netIncome = const Value.absent(),
    Value<double?> operatingCashFlow = const Value.absent(),
    Value<double?> capitalExpenditure = const Value.absent(),
    Value<double?> totalDebt = const Value.absent(),
    Value<double?> cash = const Value.absent(),
  }) => FiscalQuarterRow(
    cik: cik ?? this.cik,
    fiscalYear: fiscalYear ?? this.fiscalYear,
    quarter: quarter ?? this.quarter,
    revenue: revenue.present ? revenue.value : this.revenue,
    netIncome: netIncome.present ? netIncome.value : this.netIncome,
    operatingCashFlow: operatingCashFlow.present
        ? operatingCashFlow.value
        : this.operatingCashFlow,
    capitalExpenditure: capitalExpenditure.present
        ? capitalExpenditure.value
        : this.capitalExpenditure,
    totalDebt: totalDebt.present ? totalDebt.value : this.totalDebt,
    cash: cash.present ? cash.value : this.cash,
  );
  FiscalQuarterRow copyWithCompanion(FiscalQuartersCompanion data) {
    return FiscalQuarterRow(
      cik: data.cik.present ? data.cik.value : this.cik,
      fiscalYear: data.fiscalYear.present
          ? data.fiscalYear.value
          : this.fiscalYear,
      quarter: data.quarter.present ? data.quarter.value : this.quarter,
      revenue: data.revenue.present ? data.revenue.value : this.revenue,
      netIncome: data.netIncome.present ? data.netIncome.value : this.netIncome,
      operatingCashFlow: data.operatingCashFlow.present
          ? data.operatingCashFlow.value
          : this.operatingCashFlow,
      capitalExpenditure: data.capitalExpenditure.present
          ? data.capitalExpenditure.value
          : this.capitalExpenditure,
      totalDebt: data.totalDebt.present ? data.totalDebt.value : this.totalDebt,
      cash: data.cash.present ? data.cash.value : this.cash,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FiscalQuarterRow(')
          ..write('cik: $cik, ')
          ..write('fiscalYear: $fiscalYear, ')
          ..write('quarter: $quarter, ')
          ..write('revenue: $revenue, ')
          ..write('netIncome: $netIncome, ')
          ..write('operatingCashFlow: $operatingCashFlow, ')
          ..write('capitalExpenditure: $capitalExpenditure, ')
          ..write('totalDebt: $totalDebt, ')
          ..write('cash: $cash')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    cik,
    fiscalYear,
    quarter,
    revenue,
    netIncome,
    operatingCashFlow,
    capitalExpenditure,
    totalDebt,
    cash,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FiscalQuarterRow &&
          other.cik == this.cik &&
          other.fiscalYear == this.fiscalYear &&
          other.quarter == this.quarter &&
          other.revenue == this.revenue &&
          other.netIncome == this.netIncome &&
          other.operatingCashFlow == this.operatingCashFlow &&
          other.capitalExpenditure == this.capitalExpenditure &&
          other.totalDebt == this.totalDebt &&
          other.cash == this.cash);
}

class FiscalQuartersCompanion extends UpdateCompanion<FiscalQuarterRow> {
  final Value<String> cik;
  final Value<int> fiscalYear;
  final Value<int> quarter;
  final Value<double?> revenue;
  final Value<double?> netIncome;
  final Value<double?> operatingCashFlow;
  final Value<double?> capitalExpenditure;
  final Value<double?> totalDebt;
  final Value<double?> cash;
  final Value<int> rowid;
  const FiscalQuartersCompanion({
    this.cik = const Value.absent(),
    this.fiscalYear = const Value.absent(),
    this.quarter = const Value.absent(),
    this.revenue = const Value.absent(),
    this.netIncome = const Value.absent(),
    this.operatingCashFlow = const Value.absent(),
    this.capitalExpenditure = const Value.absent(),
    this.totalDebt = const Value.absent(),
    this.cash = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FiscalQuartersCompanion.insert({
    required String cik,
    required int fiscalYear,
    required int quarter,
    this.revenue = const Value.absent(),
    this.netIncome = const Value.absent(),
    this.operatingCashFlow = const Value.absent(),
    this.capitalExpenditure = const Value.absent(),
    this.totalDebt = const Value.absent(),
    this.cash = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : cik = Value(cik),
       fiscalYear = Value(fiscalYear),
       quarter = Value(quarter);
  static Insertable<FiscalQuarterRow> custom({
    Expression<String>? cik,
    Expression<int>? fiscalYear,
    Expression<int>? quarter,
    Expression<double>? revenue,
    Expression<double>? netIncome,
    Expression<double>? operatingCashFlow,
    Expression<double>? capitalExpenditure,
    Expression<double>? totalDebt,
    Expression<double>? cash,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (cik != null) 'cik': cik,
      if (fiscalYear != null) 'fiscal_year': fiscalYear,
      if (quarter != null) 'quarter': quarter,
      if (revenue != null) 'revenue': revenue,
      if (netIncome != null) 'net_income': netIncome,
      if (operatingCashFlow != null) 'operating_cash_flow': operatingCashFlow,
      if (capitalExpenditure != null) 'capital_expenditure': capitalExpenditure,
      if (totalDebt != null) 'total_debt': totalDebt,
      if (cash != null) 'cash': cash,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FiscalQuartersCompanion copyWith({
    Value<String>? cik,
    Value<int>? fiscalYear,
    Value<int>? quarter,
    Value<double?>? revenue,
    Value<double?>? netIncome,
    Value<double?>? operatingCashFlow,
    Value<double?>? capitalExpenditure,
    Value<double?>? totalDebt,
    Value<double?>? cash,
    Value<int>? rowid,
  }) {
    return FiscalQuartersCompanion(
      cik: cik ?? this.cik,
      fiscalYear: fiscalYear ?? this.fiscalYear,
      quarter: quarter ?? this.quarter,
      revenue: revenue ?? this.revenue,
      netIncome: netIncome ?? this.netIncome,
      operatingCashFlow: operatingCashFlow ?? this.operatingCashFlow,
      capitalExpenditure: capitalExpenditure ?? this.capitalExpenditure,
      totalDebt: totalDebt ?? this.totalDebt,
      cash: cash ?? this.cash,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (cik.present) {
      map['cik'] = Variable<String>(cik.value);
    }
    if (fiscalYear.present) {
      map['fiscal_year'] = Variable<int>(fiscalYear.value);
    }
    if (quarter.present) {
      map['quarter'] = Variable<int>(quarter.value);
    }
    if (revenue.present) {
      map['revenue'] = Variable<double>(revenue.value);
    }
    if (netIncome.present) {
      map['net_income'] = Variable<double>(netIncome.value);
    }
    if (operatingCashFlow.present) {
      map['operating_cash_flow'] = Variable<double>(operatingCashFlow.value);
    }
    if (capitalExpenditure.present) {
      map['capital_expenditure'] = Variable<double>(capitalExpenditure.value);
    }
    if (totalDebt.present) {
      map['total_debt'] = Variable<double>(totalDebt.value);
    }
    if (cash.present) {
      map['cash'] = Variable<double>(cash.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FiscalQuartersCompanion(')
          ..write('cik: $cik, ')
          ..write('fiscalYear: $fiscalYear, ')
          ..write('quarter: $quarter, ')
          ..write('revenue: $revenue, ')
          ..write('netIncome: $netIncome, ')
          ..write('operatingCashFlow: $operatingCashFlow, ')
          ..write('capitalExpenditure: $capitalExpenditure, ')
          ..write('totalDebt: $totalDebt, ')
          ..write('cash: $cash, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $IngestRunsTable extends IngestRuns
    with TableInfo<$IngestRunsTable, IngestRunRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $IngestRunsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _companyCountMeta = const VerificationMeta(
    'companyCount',
  );
  @override
  late final GeneratedColumn<int> companyCount = GeneratedColumn<int>(
    'company_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _extractorVersionMeta = const VerificationMeta(
    'extractorVersion',
  );
  @override
  late final GeneratedColumn<int> extractorVersion = GeneratedColumn<int>(
    'extractor_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _archiveLastModifiedMeta =
      const VerificationMeta('archiveLastModified');
  @override
  late final GeneratedColumn<DateTime> archiveLastModified =
      GeneratedColumn<DateTime>(
        'archive_last_modified',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    completedAt,
    companyCount,
    extractorVersion,
    archiveLastModified,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ingest_runs';
  @override
  VerificationContext validateIntegrity(
    Insertable<IngestRunRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_completedAtMeta);
    }
    if (data.containsKey('company_count')) {
      context.handle(
        _companyCountMeta,
        companyCount.isAcceptableOrUnknown(
          data['company_count']!,
          _companyCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_companyCountMeta);
    }
    if (data.containsKey('extractor_version')) {
      context.handle(
        _extractorVersionMeta,
        extractorVersion.isAcceptableOrUnknown(
          data['extractor_version']!,
          _extractorVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_extractorVersionMeta);
    }
    if (data.containsKey('archive_last_modified')) {
      context.handle(
        _archiveLastModifiedMeta,
        archiveLastModified.isAcceptableOrUnknown(
          data['archive_last_modified']!,
          _archiveLastModifiedMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  IngestRunRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return IngestRunRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      )!,
      companyCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}company_count'],
      )!,
      extractorVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}extractor_version'],
      )!,
      archiveLastModified: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}archive_last_modified'],
      ),
    );
  }

  @override
  $IngestRunsTable createAlias(String alias) {
    return $IngestRunsTable(attachedDatabase, alias);
  }
}

class IngestRunRow extends DataClass implements Insertable<IngestRunRow> {
  final int id;
  final DateTime completedAt;
  final int companyCount;
  final int extractorVersion;

  /// When SEC last rebuilt the archive this ingest loaded, from the download's
  /// `Last-Modified` header. Compared against a HEAD request to tell whether a
  /// newer archive is out.
  final DateTime? archiveLastModified;
  const IngestRunRow({
    required this.id,
    required this.completedAt,
    required this.companyCount,
    required this.extractorVersion,
    this.archiveLastModified,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['completed_at'] = Variable<DateTime>(completedAt);
    map['company_count'] = Variable<int>(companyCount);
    map['extractor_version'] = Variable<int>(extractorVersion);
    if (!nullToAbsent || archiveLastModified != null) {
      map['archive_last_modified'] = Variable<DateTime>(archiveLastModified);
    }
    return map;
  }

  IngestRunsCompanion toCompanion(bool nullToAbsent) {
    return IngestRunsCompanion(
      id: Value(id),
      completedAt: Value(completedAt),
      companyCount: Value(companyCount),
      extractorVersion: Value(extractorVersion),
      archiveLastModified: archiveLastModified == null && nullToAbsent
          ? const Value.absent()
          : Value(archiveLastModified),
    );
  }

  factory IngestRunRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return IngestRunRow(
      id: serializer.fromJson<int>(json['id']),
      completedAt: serializer.fromJson<DateTime>(json['completedAt']),
      companyCount: serializer.fromJson<int>(json['companyCount']),
      extractorVersion: serializer.fromJson<int>(json['extractorVersion']),
      archiveLastModified: serializer.fromJson<DateTime?>(
        json['archiveLastModified'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'completedAt': serializer.toJson<DateTime>(completedAt),
      'companyCount': serializer.toJson<int>(companyCount),
      'extractorVersion': serializer.toJson<int>(extractorVersion),
      'archiveLastModified': serializer.toJson<DateTime?>(archiveLastModified),
    };
  }

  IngestRunRow copyWith({
    int? id,
    DateTime? completedAt,
    int? companyCount,
    int? extractorVersion,
    Value<DateTime?> archiveLastModified = const Value.absent(),
  }) => IngestRunRow(
    id: id ?? this.id,
    completedAt: completedAt ?? this.completedAt,
    companyCount: companyCount ?? this.companyCount,
    extractorVersion: extractorVersion ?? this.extractorVersion,
    archiveLastModified: archiveLastModified.present
        ? archiveLastModified.value
        : this.archiveLastModified,
  );
  IngestRunRow copyWithCompanion(IngestRunsCompanion data) {
    return IngestRunRow(
      id: data.id.present ? data.id.value : this.id,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      companyCount: data.companyCount.present
          ? data.companyCount.value
          : this.companyCount,
      extractorVersion: data.extractorVersion.present
          ? data.extractorVersion.value
          : this.extractorVersion,
      archiveLastModified: data.archiveLastModified.present
          ? data.archiveLastModified.value
          : this.archiveLastModified,
    );
  }

  @override
  String toString() {
    return (StringBuffer('IngestRunRow(')
          ..write('id: $id, ')
          ..write('completedAt: $completedAt, ')
          ..write('companyCount: $companyCount, ')
          ..write('extractorVersion: $extractorVersion, ')
          ..write('archiveLastModified: $archiveLastModified')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    completedAt,
    companyCount,
    extractorVersion,
    archiveLastModified,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is IngestRunRow &&
          other.id == this.id &&
          other.completedAt == this.completedAt &&
          other.companyCount == this.companyCount &&
          other.extractorVersion == this.extractorVersion &&
          other.archiveLastModified == this.archiveLastModified);
}

class IngestRunsCompanion extends UpdateCompanion<IngestRunRow> {
  final Value<int> id;
  final Value<DateTime> completedAt;
  final Value<int> companyCount;
  final Value<int> extractorVersion;
  final Value<DateTime?> archiveLastModified;
  const IngestRunsCompanion({
    this.id = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.companyCount = const Value.absent(),
    this.extractorVersion = const Value.absent(),
    this.archiveLastModified = const Value.absent(),
  });
  IngestRunsCompanion.insert({
    this.id = const Value.absent(),
    required DateTime completedAt,
    required int companyCount,
    required int extractorVersion,
    this.archiveLastModified = const Value.absent(),
  }) : completedAt = Value(completedAt),
       companyCount = Value(companyCount),
       extractorVersion = Value(extractorVersion);
  static Insertable<IngestRunRow> custom({
    Expression<int>? id,
    Expression<DateTime>? completedAt,
    Expression<int>? companyCount,
    Expression<int>? extractorVersion,
    Expression<DateTime>? archiveLastModified,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (completedAt != null) 'completed_at': completedAt,
      if (companyCount != null) 'company_count': companyCount,
      if (extractorVersion != null) 'extractor_version': extractorVersion,
      if (archiveLastModified != null)
        'archive_last_modified': archiveLastModified,
    });
  }

  IngestRunsCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? completedAt,
    Value<int>? companyCount,
    Value<int>? extractorVersion,
    Value<DateTime?>? archiveLastModified,
  }) {
    return IngestRunsCompanion(
      id: id ?? this.id,
      completedAt: completedAt ?? this.completedAt,
      companyCount: companyCount ?? this.companyCount,
      extractorVersion: extractorVersion ?? this.extractorVersion,
      archiveLastModified: archiveLastModified ?? this.archiveLastModified,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (companyCount.present) {
      map['company_count'] = Variable<int>(companyCount.value);
    }
    if (extractorVersion.present) {
      map['extractor_version'] = Variable<int>(extractorVersion.value);
    }
    if (archiveLastModified.present) {
      map['archive_last_modified'] = Variable<DateTime>(
        archiveLastModified.value,
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('IngestRunsCompanion(')
          ..write('id: $id, ')
          ..write('completedAt: $completedAt, ')
          ..write('companyCount: $companyCount, ')
          ..write('extractorVersion: $extractorVersion, ')
          ..write('archiveLastModified: $archiveLastModified')
          ..write(')'))
        .toString();
  }
}

class $SharePricesTable extends SharePrices
    with TableInfo<$SharePricesTable, SharePriceRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SharePricesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _cikMeta = const VerificationMeta('cik');
  @override
  late final GeneratedColumn<String> cik = GeneratedColumn<String>(
    'cik',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pricePerShareMeta = const VerificationMeta(
    'pricePerShare',
  );
  @override
  late final GeneratedColumn<double> pricePerShare = GeneratedColumn<double>(
    'price_per_share',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _asOfMeta = const VerificationMeta('asOf');
  @override
  late final GeneratedColumn<DateTime> asOf = GeneratedColumn<DateTime>(
    'as_of',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isQuotedMeta = const VerificationMeta(
    'isQuoted',
  );
  @override
  late final GeneratedColumn<bool> isQuoted = GeneratedColumn<bool>(
    'is_quoted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_quoted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [cik, pricePerShare, asOf, isQuoted];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'share_prices';
  @override
  VerificationContext validateIntegrity(
    Insertable<SharePriceRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('cik')) {
      context.handle(
        _cikMeta,
        cik.isAcceptableOrUnknown(data['cik']!, _cikMeta),
      );
    } else if (isInserting) {
      context.missing(_cikMeta);
    }
    if (data.containsKey('price_per_share')) {
      context.handle(
        _pricePerShareMeta,
        pricePerShare.isAcceptableOrUnknown(
          data['price_per_share']!,
          _pricePerShareMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_pricePerShareMeta);
    }
    if (data.containsKey('as_of')) {
      context.handle(
        _asOfMeta,
        asOf.isAcceptableOrUnknown(data['as_of']!, _asOfMeta),
      );
    } else if (isInserting) {
      context.missing(_asOfMeta);
    }
    if (data.containsKey('is_quoted')) {
      context.handle(
        _isQuotedMeta,
        isQuoted.isAcceptableOrUnknown(data['is_quoted']!, _isQuotedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {cik};
  @override
  SharePriceRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SharePriceRow(
      cik: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cik'],
      )!,
      pricePerShare: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}price_per_share'],
      )!,
      asOf: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}as_of'],
      )!,
      isQuoted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_quoted'],
      )!,
    );
  }

  @override
  $SharePricesTable createAlias(String alias) {
    return $SharePricesTable(attachedDatabase, alias);
  }
}

class SharePriceRow extends DataClass implements Insertable<SharePriceRow> {
  final String cik;
  final double pricePerShare;

  /// When the price was true: the exchange timestamp for a quoted price, or
  /// when it was typed for an entered one.
  final DateTime asOf;

  /// Whether a provider quoted this price. A stale quote and a typed guess are
  /// both prices, and the report must not present them as the same thing.
  final bool isQuoted;
  const SharePriceRow({
    required this.cik,
    required this.pricePerShare,
    required this.asOf,
    required this.isQuoted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['cik'] = Variable<String>(cik);
    map['price_per_share'] = Variable<double>(pricePerShare);
    map['as_of'] = Variable<DateTime>(asOf);
    map['is_quoted'] = Variable<bool>(isQuoted);
    return map;
  }

  SharePricesCompanion toCompanion(bool nullToAbsent) {
    return SharePricesCompanion(
      cik: Value(cik),
      pricePerShare: Value(pricePerShare),
      asOf: Value(asOf),
      isQuoted: Value(isQuoted),
    );
  }

  factory SharePriceRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SharePriceRow(
      cik: serializer.fromJson<String>(json['cik']),
      pricePerShare: serializer.fromJson<double>(json['pricePerShare']),
      asOf: serializer.fromJson<DateTime>(json['asOf']),
      isQuoted: serializer.fromJson<bool>(json['isQuoted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'cik': serializer.toJson<String>(cik),
      'pricePerShare': serializer.toJson<double>(pricePerShare),
      'asOf': serializer.toJson<DateTime>(asOf),
      'isQuoted': serializer.toJson<bool>(isQuoted),
    };
  }

  SharePriceRow copyWith({
    String? cik,
    double? pricePerShare,
    DateTime? asOf,
    bool? isQuoted,
  }) => SharePriceRow(
    cik: cik ?? this.cik,
    pricePerShare: pricePerShare ?? this.pricePerShare,
    asOf: asOf ?? this.asOf,
    isQuoted: isQuoted ?? this.isQuoted,
  );
  SharePriceRow copyWithCompanion(SharePricesCompanion data) {
    return SharePriceRow(
      cik: data.cik.present ? data.cik.value : this.cik,
      pricePerShare: data.pricePerShare.present
          ? data.pricePerShare.value
          : this.pricePerShare,
      asOf: data.asOf.present ? data.asOf.value : this.asOf,
      isQuoted: data.isQuoted.present ? data.isQuoted.value : this.isQuoted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SharePriceRow(')
          ..write('cik: $cik, ')
          ..write('pricePerShare: $pricePerShare, ')
          ..write('asOf: $asOf, ')
          ..write('isQuoted: $isQuoted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(cik, pricePerShare, asOf, isQuoted);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SharePriceRow &&
          other.cik == this.cik &&
          other.pricePerShare == this.pricePerShare &&
          other.asOf == this.asOf &&
          other.isQuoted == this.isQuoted);
}

class SharePricesCompanion extends UpdateCompanion<SharePriceRow> {
  final Value<String> cik;
  final Value<double> pricePerShare;
  final Value<DateTime> asOf;
  final Value<bool> isQuoted;
  final Value<int> rowid;
  const SharePricesCompanion({
    this.cik = const Value.absent(),
    this.pricePerShare = const Value.absent(),
    this.asOf = const Value.absent(),
    this.isQuoted = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SharePricesCompanion.insert({
    required String cik,
    required double pricePerShare,
    required DateTime asOf,
    this.isQuoted = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : cik = Value(cik),
       pricePerShare = Value(pricePerShare),
       asOf = Value(asOf);
  static Insertable<SharePriceRow> custom({
    Expression<String>? cik,
    Expression<double>? pricePerShare,
    Expression<DateTime>? asOf,
    Expression<bool>? isQuoted,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (cik != null) 'cik': cik,
      if (pricePerShare != null) 'price_per_share': pricePerShare,
      if (asOf != null) 'as_of': asOf,
      if (isQuoted != null) 'is_quoted': isQuoted,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SharePricesCompanion copyWith({
    Value<String>? cik,
    Value<double>? pricePerShare,
    Value<DateTime>? asOf,
    Value<bool>? isQuoted,
    Value<int>? rowid,
  }) {
    return SharePricesCompanion(
      cik: cik ?? this.cik,
      pricePerShare: pricePerShare ?? this.pricePerShare,
      asOf: asOf ?? this.asOf,
      isQuoted: isQuoted ?? this.isQuoted,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (cik.present) {
      map['cik'] = Variable<String>(cik.value);
    }
    if (pricePerShare.present) {
      map['price_per_share'] = Variable<double>(pricePerShare.value);
    }
    if (asOf.present) {
      map['as_of'] = Variable<DateTime>(asOf.value);
    }
    if (isQuoted.present) {
      map['is_quoted'] = Variable<bool>(isQuoted.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SharePricesCompanion(')
          ..write('cik: $cik, ')
          ..write('pricePerShare: $pricePerShare, ')
          ..write('asOf: $asOf, ')
          ..write('isQuoted: $isQuoted, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WatchlistsTable extends Watchlists
    with TableInfo<$WatchlistsTable, WatchlistRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WatchlistsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(minTextLength: 1),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colourIndexMeta = const VerificationMeta(
    'colourIndex',
  );
  @override
  late final GeneratedColumn<int> colourIndex = GeneratedColumn<int>(
    'colour_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isDefaultMeta = const VerificationMeta(
    'isDefault',
  );
  @override
  late final GeneratedColumn<bool> isDefault = GeneratedColumn<bool>(
    'is_default',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_default" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    colourIndex,
    isDefault,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'watchlists';
  @override
  VerificationContext validateIntegrity(
    Insertable<WatchlistRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('colour_index')) {
      context.handle(
        _colourIndexMeta,
        colourIndex.isAcceptableOrUnknown(
          data['colour_index']!,
          _colourIndexMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_colourIndexMeta);
    }
    if (data.containsKey('is_default')) {
      context.handle(
        _isDefaultMeta,
        isDefault.isAcceptableOrUnknown(data['is_default']!, _isDefaultMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WatchlistRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WatchlistRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      colourIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}colour_index'],
      )!,
      isDefault: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_default'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $WatchlistsTable createAlias(String alias) {
    return $WatchlistsTable(attachedDatabase, alias);
  }
}

class WatchlistRow extends DataClass implements Insertable<WatchlistRow> {
  final int id;
  final String name;

  /// An index into the palette in `ThemeRepo`, not a colour value: the palette
  /// has to change with the theme, so storing an ARGB int would pin a list to
  /// one appearance for ever.
  final int colourIndex;

  /// The list every star goes into. Seeded once, cannot be deleted, and sorts
  /// first. Making favourites an ordinary list keeps one mechanism instead of
  /// a flag beside a table that does the same job.
  final bool isDefault;
  final DateTime createdAt;
  const WatchlistRow({
    required this.id,
    required this.name,
    required this.colourIndex,
    required this.isDefault,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['colour_index'] = Variable<int>(colourIndex);
    map['is_default'] = Variable<bool>(isDefault);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  WatchlistsCompanion toCompanion(bool nullToAbsent) {
    return WatchlistsCompanion(
      id: Value(id),
      name: Value(name),
      colourIndex: Value(colourIndex),
      isDefault: Value(isDefault),
      createdAt: Value(createdAt),
    );
  }

  factory WatchlistRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WatchlistRow(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      colourIndex: serializer.fromJson<int>(json['colourIndex']),
      isDefault: serializer.fromJson<bool>(json['isDefault']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'colourIndex': serializer.toJson<int>(colourIndex),
      'isDefault': serializer.toJson<bool>(isDefault),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  WatchlistRow copyWith({
    int? id,
    String? name,
    int? colourIndex,
    bool? isDefault,
    DateTime? createdAt,
  }) => WatchlistRow(
    id: id ?? this.id,
    name: name ?? this.name,
    colourIndex: colourIndex ?? this.colourIndex,
    isDefault: isDefault ?? this.isDefault,
    createdAt: createdAt ?? this.createdAt,
  );
  WatchlistRow copyWithCompanion(WatchlistsCompanion data) {
    return WatchlistRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      colourIndex: data.colourIndex.present
          ? data.colourIndex.value
          : this.colourIndex,
      isDefault: data.isDefault.present ? data.isDefault.value : this.isDefault,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WatchlistRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('colourIndex: $colourIndex, ')
          ..write('isDefault: $isDefault, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, colourIndex, isDefault, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WatchlistRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.colourIndex == this.colourIndex &&
          other.isDefault == this.isDefault &&
          other.createdAt == this.createdAt);
}

class WatchlistsCompanion extends UpdateCompanion<WatchlistRow> {
  final Value<int> id;
  final Value<String> name;
  final Value<int> colourIndex;
  final Value<bool> isDefault;
  final Value<DateTime> createdAt;
  const WatchlistsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.colourIndex = const Value.absent(),
    this.isDefault = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  WatchlistsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required int colourIndex,
    this.isDefault = const Value.absent(),
    required DateTime createdAt,
  }) : name = Value(name),
       colourIndex = Value(colourIndex),
       createdAt = Value(createdAt);
  static Insertable<WatchlistRow> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<int>? colourIndex,
    Expression<bool>? isDefault,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (colourIndex != null) 'colour_index': colourIndex,
      if (isDefault != null) 'is_default': isDefault,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  WatchlistsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<int>? colourIndex,
    Value<bool>? isDefault,
    Value<DateTime>? createdAt,
  }) {
    return WatchlistsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      colourIndex: colourIndex ?? this.colourIndex,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (colourIndex.present) {
      map['colour_index'] = Variable<int>(colourIndex.value);
    }
    if (isDefault.present) {
      map['is_default'] = Variable<bool>(isDefault.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WatchlistsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('colourIndex: $colourIndex, ')
          ..write('isDefault: $isDefault, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $WatchlistEntriesTable extends WatchlistEntries
    with TableInfo<$WatchlistEntriesTable, WatchlistEntryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WatchlistEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _watchlistIdMeta = const VerificationMeta(
    'watchlistId',
  );
  @override
  late final GeneratedColumn<int> watchlistId = GeneratedColumn<int>(
    'watchlist_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES watchlists (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _cikMeta = const VerificationMeta('cik');
  @override
  late final GeneratedColumn<String> cik = GeneratedColumn<String>(
    'cik',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [watchlistId, cik, addedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'watchlist_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<WatchlistEntryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('watchlist_id')) {
      context.handle(
        _watchlistIdMeta,
        watchlistId.isAcceptableOrUnknown(
          data['watchlist_id']!,
          _watchlistIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_watchlistIdMeta);
    }
    if (data.containsKey('cik')) {
      context.handle(
        _cikMeta,
        cik.isAcceptableOrUnknown(data['cik']!, _cikMeta),
      );
    } else if (isInserting) {
      context.missing(_cikMeta);
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {watchlistId, cik};
  @override
  WatchlistEntryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WatchlistEntryRow(
      watchlistId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}watchlist_id'],
      )!,
      cik: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cik'],
      )!,
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      )!,
    );
  }

  @override
  $WatchlistEntriesTable createAlias(String alias) {
    return $WatchlistEntriesTable(attachedDatabase, alias);
  }
}

class WatchlistEntryRow extends DataClass
    implements Insertable<WatchlistEntryRow> {
  final int watchlistId;
  final String cik;
  final DateTime addedAt;
  const WatchlistEntryRow({
    required this.watchlistId,
    required this.cik,
    required this.addedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['watchlist_id'] = Variable<int>(watchlistId);
    map['cik'] = Variable<String>(cik);
    map['added_at'] = Variable<DateTime>(addedAt);
    return map;
  }

  WatchlistEntriesCompanion toCompanion(bool nullToAbsent) {
    return WatchlistEntriesCompanion(
      watchlistId: Value(watchlistId),
      cik: Value(cik),
      addedAt: Value(addedAt),
    );
  }

  factory WatchlistEntryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WatchlistEntryRow(
      watchlistId: serializer.fromJson<int>(json['watchlistId']),
      cik: serializer.fromJson<String>(json['cik']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'watchlistId': serializer.toJson<int>(watchlistId),
      'cik': serializer.toJson<String>(cik),
      'addedAt': serializer.toJson<DateTime>(addedAt),
    };
  }

  WatchlistEntryRow copyWith({
    int? watchlistId,
    String? cik,
    DateTime? addedAt,
  }) => WatchlistEntryRow(
    watchlistId: watchlistId ?? this.watchlistId,
    cik: cik ?? this.cik,
    addedAt: addedAt ?? this.addedAt,
  );
  WatchlistEntryRow copyWithCompanion(WatchlistEntriesCompanion data) {
    return WatchlistEntryRow(
      watchlistId: data.watchlistId.present
          ? data.watchlistId.value
          : this.watchlistId,
      cik: data.cik.present ? data.cik.value : this.cik,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WatchlistEntryRow(')
          ..write('watchlistId: $watchlistId, ')
          ..write('cik: $cik, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(watchlistId, cik, addedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WatchlistEntryRow &&
          other.watchlistId == this.watchlistId &&
          other.cik == this.cik &&
          other.addedAt == this.addedAt);
}

class WatchlistEntriesCompanion extends UpdateCompanion<WatchlistEntryRow> {
  final Value<int> watchlistId;
  final Value<String> cik;
  final Value<DateTime> addedAt;
  final Value<int> rowid;
  const WatchlistEntriesCompanion({
    this.watchlistId = const Value.absent(),
    this.cik = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WatchlistEntriesCompanion.insert({
    required int watchlistId,
    required String cik,
    required DateTime addedAt,
    this.rowid = const Value.absent(),
  }) : watchlistId = Value(watchlistId),
       cik = Value(cik),
       addedAt = Value(addedAt);
  static Insertable<WatchlistEntryRow> custom({
    Expression<int>? watchlistId,
    Expression<String>? cik,
    Expression<DateTime>? addedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (watchlistId != null) 'watchlist_id': watchlistId,
      if (cik != null) 'cik': cik,
      if (addedAt != null) 'added_at': addedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WatchlistEntriesCompanion copyWith({
    Value<int>? watchlistId,
    Value<String>? cik,
    Value<DateTime>? addedAt,
    Value<int>? rowid,
  }) {
    return WatchlistEntriesCompanion(
      watchlistId: watchlistId ?? this.watchlistId,
      cik: cik ?? this.cik,
      addedAt: addedAt ?? this.addedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (watchlistId.present) {
      map['watchlist_id'] = Variable<int>(watchlistId.value);
    }
    if (cik.present) {
      map['cik'] = Variable<String>(cik.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WatchlistEntriesCompanion(')
          ..write('watchlistId: $watchlistId, ')
          ..write('cik: $cik, ')
          ..write('addedAt: $addedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings
    with TableInfo<$SettingsTable, SettingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<SettingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SettingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class SettingRow extends DataClass implements Insertable<SettingRow> {
  final String key;
  final String value;
  const SettingRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(key: Value(key), value: Value(value));
  }

  factory SettingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  SettingRow copyWith({String? key, String? value}) =>
      SettingRow(key: key ?? this.key, value: value ?? this.value);
  SettingRow copyWithCompanion(SettingsCompanion data) {
    return SettingRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SettingRow &&
          other.key == this.key &&
          other.value == this.value);
}

class SettingsCompanion extends UpdateCompanion<SettingRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<SettingRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CompaniesTable companies = $CompaniesTable(this);
  late final $TickersTable tickers = $TickersTable(this);
  late final $FiscalYearsTable fiscalYears = $FiscalYearsTable(this);
  late final $FiscalQuartersTable fiscalQuarters = $FiscalQuartersTable(this);
  late final $IngestRunsTable ingestRuns = $IngestRunsTable(this);
  late final $SharePricesTable sharePrices = $SharePricesTable(this);
  late final $WatchlistsTable watchlists = $WatchlistsTable(this);
  late final $WatchlistEntriesTable watchlistEntries = $WatchlistEntriesTable(
    this,
  );
  late final $SettingsTable settings = $SettingsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    companies,
    tickers,
    fiscalYears,
    fiscalQuarters,
    ingestRuns,
    sharePrices,
    watchlists,
    watchlistEntries,
    settings,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'watchlists',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('watchlist_entries', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$CompaniesTableCreateCompanionBuilder = CompaniesCompanion Function({
  required String cik,
  required String name,
  Value<int?> sic,
  Value<double?> sharesOutstanding,
  Value<int> rowid,
});
typedef $$CompaniesTableUpdateCompanionBuilder = CompaniesCompanion Function({
  Value<String> cik,
  Value<String> name,
  Value<int?> sic,
  Value<double?> sharesOutstanding,
  Value<int> rowid,
});

final class $$CompaniesTableReferences
    extends BaseReferences<_$AppDatabase, $CompaniesTable, CompanyRow> {
  $$CompaniesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$FiscalYearsTable, List<FiscalYearRow>>
  _fiscalYearsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.fiscalYears,
    aliasName: 'companies__cik__fiscal_years__cik',
  );

  $$FiscalYearsTableProcessedTableManager get fiscalYearsRefs {
    final manager = $$FiscalYearsTableTableManager(
      $_db,
      $_db.fiscalYears,
    ).filter((f) => f.cik.cik.sqlEquals($_itemColumn<String>('cik')!));

    final cache = $_typedResult.readTableOrNull(_fiscalYearsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$FiscalQuartersTable, List<FiscalQuarterRow>>
  _fiscalQuartersRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.fiscalQuarters,
    aliasName: 'companies__cik__fiscal_quarters__cik',
  );

  $$FiscalQuartersTableProcessedTableManager get fiscalQuartersRefs {
    final manager = $$FiscalQuartersTableTableManager(
      $_db,
      $_db.fiscalQuarters,
    ).filter((f) => f.cik.cik.sqlEquals($_itemColumn<String>('cik')!));

    final cache = $_typedResult.readTableOrNull(_fiscalQuartersRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CompaniesTableFilterComposer
    extends Composer<_$AppDatabase, $CompaniesTable> {
  $$CompaniesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get cik => $composableBuilder(
    column: $table.cik,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sic => $composableBuilder(
    column: $table.sic,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get sharesOutstanding => $composableBuilder(
    column: $table.sharesOutstanding,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> fiscalYearsRefs(
    Expression<bool> Function($$FiscalYearsTableFilterComposer f) f,
  ) {
    final $$FiscalYearsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cik,
      referencedTable: $db.fiscalYears,
      getReferencedColumn: (t) => t.cik,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FiscalYearsTableFilterComposer(
            $db: $db,
            $table: $db.fiscalYears,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> fiscalQuartersRefs(
    Expression<bool> Function($$FiscalQuartersTableFilterComposer f) f,
  ) {
    final $$FiscalQuartersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cik,
      referencedTable: $db.fiscalQuarters,
      getReferencedColumn: (t) => t.cik,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FiscalQuartersTableFilterComposer(
            $db: $db,
            $table: $db.fiscalQuarters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CompaniesTableOrderingComposer
    extends Composer<_$AppDatabase, $CompaniesTable> {
  $$CompaniesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get cik => $composableBuilder(
    column: $table.cik,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sic => $composableBuilder(
    column: $table.sic,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get sharesOutstanding => $composableBuilder(
    column: $table.sharesOutstanding,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CompaniesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CompaniesTable> {
  $$CompaniesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get cik =>
      $composableBuilder(column: $table.cik, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get sic =>
      $composableBuilder(column: $table.sic, builder: (column) => column);

  GeneratedColumn<double> get sharesOutstanding => $composableBuilder(
    column: $table.sharesOutstanding,
    builder: (column) => column,
  );

  Expression<T> fiscalYearsRefs<T extends Object>(
    Expression<T> Function($$FiscalYearsTableAnnotationComposer a) f,
  ) {
    final $$FiscalYearsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cik,
      referencedTable: $db.fiscalYears,
      getReferencedColumn: (t) => t.cik,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FiscalYearsTableAnnotationComposer(
            $db: $db,
            $table: $db.fiscalYears,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> fiscalQuartersRefs<T extends Object>(
    Expression<T> Function($$FiscalQuartersTableAnnotationComposer a) f,
  ) {
    final $$FiscalQuartersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cik,
      referencedTable: $db.fiscalQuarters,
      getReferencedColumn: (t) => t.cik,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FiscalQuartersTableAnnotationComposer(
            $db: $db,
            $table: $db.fiscalQuarters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CompaniesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CompaniesTable,
          CompanyRow,
          $$CompaniesTableFilterComposer,
          $$CompaniesTableOrderingComposer,
          $$CompaniesTableAnnotationComposer,
          $$CompaniesTableCreateCompanionBuilder,
          $$CompaniesTableUpdateCompanionBuilder,
          (CompanyRow, $$CompaniesTableReferences),
          CompanyRow,
          PrefetchHooks Function({
            bool fiscalYearsRefs,
            bool fiscalQuartersRefs,
          })
        > {
  $$CompaniesTableTableManager(_$AppDatabase db, $CompaniesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CompaniesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CompaniesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CompaniesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> cik = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int?> sic = const Value.absent(),
                Value<double?> sharesOutstanding = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CompaniesCompanion(
                cik: cik,
                name: name,
                sic: sic,
                sharesOutstanding: sharesOutstanding,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String cik,
                required String name,
                Value<int?> sic = const Value.absent(),
                Value<double?> sharesOutstanding = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CompaniesCompanion.insert(
                cik: cik,
                name: name,
                sic: sic,
                sharesOutstanding: sharesOutstanding,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CompaniesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({fiscalYearsRefs = false, fiscalQuartersRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (fiscalYearsRefs) db.fiscalYears,
                    if (fiscalQuartersRefs) db.fiscalQuarters,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (fiscalYearsRefs)
                        await $_getPrefetchedData<
                          CompanyRow,
                          $CompaniesTable,
                          FiscalYearRow
                        >(
                          currentTable: table,
                          referencedTable: $$CompaniesTableReferences
                              ._fiscalYearsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CompaniesTableReferences(
                                db,
                                table,
                                p0,
                              ).fiscalYearsRefs,
                          referencedItemsForCurrentItem: (
                            item,
                            referencedItems,
                          ) => referencedItems.where((e) => e.cik == item.cik),
                          typedResults: items,
                        ),
                      if (fiscalQuartersRefs)
                        await $_getPrefetchedData<
                          CompanyRow,
                          $CompaniesTable,
                          FiscalQuarterRow
                        >(
                          currentTable: table,
                          referencedTable: $$CompaniesTableReferences
                              ._fiscalQuartersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CompaniesTableReferences(
                                db,
                                table,
                                p0,
                              ).fiscalQuartersRefs,
                          referencedItemsForCurrentItem: (
                            item,
                            referencedItems,
                          ) => referencedItems.where((e) => e.cik == item.cik),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$CompaniesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CompaniesTable,
      CompanyRow,
      $$CompaniesTableFilterComposer,
      $$CompaniesTableOrderingComposer,
      $$CompaniesTableAnnotationComposer,
      $$CompaniesTableCreateCompanionBuilder,
      $$CompaniesTableUpdateCompanionBuilder,
      (CompanyRow, $$CompaniesTableReferences),
      CompanyRow,
      PrefetchHooks Function({bool fiscalYearsRefs, bool fiscalQuartersRefs})
    >;
typedef $$TickersTableCreateCompanionBuilder = TickersCompanion Function({
  required String symbol,
  required String cik,
  required String name,
  Value<int> rowid,
});
typedef $$TickersTableUpdateCompanionBuilder = TickersCompanion Function({
  Value<String> symbol,
  Value<String> cik,
  Value<String> name,
  Value<int> rowid,
});

class $$TickersTableFilterComposer
    extends Composer<_$AppDatabase, $TickersTable> {
  $$TickersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get symbol => $composableBuilder(
    column: $table.symbol,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cik => $composableBuilder(
    column: $table.cik,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TickersTableOrderingComposer
    extends Composer<_$AppDatabase, $TickersTable> {
  $$TickersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get symbol => $composableBuilder(
    column: $table.symbol,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cik => $composableBuilder(
    column: $table.cik,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TickersTableAnnotationComposer
    extends Composer<_$AppDatabase, $TickersTable> {
  $$TickersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get symbol =>
      $composableBuilder(column: $table.symbol, builder: (column) => column);

  GeneratedColumn<String> get cik =>
      $composableBuilder(column: $table.cik, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);
}

class $$TickersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TickersTable,
          TickerRow,
          $$TickersTableFilterComposer,
          $$TickersTableOrderingComposer,
          $$TickersTableAnnotationComposer,
          $$TickersTableCreateCompanionBuilder,
          $$TickersTableUpdateCompanionBuilder,
          (TickerRow, BaseReferences<_$AppDatabase, $TickersTable, TickerRow>),
          TickerRow,
          PrefetchHooks Function()
        > {
  $$TickersTableTableManager(_$AppDatabase db, $TickersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TickersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TickersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TickersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> symbol = const Value.absent(),
                Value<String> cik = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TickersCompanion(
                symbol: symbol,
                cik: cik,
                name: name,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String symbol,
                required String cik,
                required String name,
                Value<int> rowid = const Value.absent(),
              }) => TickersCompanion.insert(
                symbol: symbol,
                cik: cik,
                name: name,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TickersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TickersTable,
      TickerRow,
      $$TickersTableFilterComposer,
      $$TickersTableOrderingComposer,
      $$TickersTableAnnotationComposer,
      $$TickersTableCreateCompanionBuilder,
      $$TickersTableUpdateCompanionBuilder,
      (TickerRow, BaseReferences<_$AppDatabase, $TickersTable, TickerRow>),
      TickerRow,
      PrefetchHooks Function()
    >;
typedef $$FiscalYearsTableCreateCompanionBuilder =
    FiscalYearsCompanion Function({
      required String cik,
      required int fiscalYear,
      Value<double?> revenue,
      Value<double?> netIncome,
      Value<double?> operatingCashFlow,
      Value<double?> capitalExpenditure,
      Value<double?> totalDebt,
      Value<double?> cash,
      Value<double?> dilutedShares,
      Value<double?> operatingIncome,
      Value<double?> depreciationAmortisation,
      Value<double?> totalAssets,
      Value<double?> shareholdersEquity,
      Value<int> rowid,
    });
typedef $$FiscalYearsTableUpdateCompanionBuilder =
    FiscalYearsCompanion Function({
      Value<String> cik,
      Value<int> fiscalYear,
      Value<double?> revenue,
      Value<double?> netIncome,
      Value<double?> operatingCashFlow,
      Value<double?> capitalExpenditure,
      Value<double?> totalDebt,
      Value<double?> cash,
      Value<double?> dilutedShares,
      Value<double?> operatingIncome,
      Value<double?> depreciationAmortisation,
      Value<double?> totalAssets,
      Value<double?> shareholdersEquity,
      Value<int> rowid,
    });

final class $$FiscalYearsTableReferences
    extends BaseReferences<_$AppDatabase, $FiscalYearsTable, FiscalYearRow> {
  $$FiscalYearsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CompaniesTable _cikTable(_$AppDatabase db) =>
      db.companies.createAlias('fiscal_years__cik__companies__cik');

  $$CompaniesTableProcessedTableManager get cik {
    final $_column = $_itemColumn<String>('cik')!;

    final manager = $$CompaniesTableTableManager(
      $_db,
      $_db.companies,
    ).filter((f) => f.cik.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_cikTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$FiscalYearsTableFilterComposer
    extends Composer<_$AppDatabase, $FiscalYearsTable> {
  $$FiscalYearsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get fiscalYear => $composableBuilder(
    column: $table.fiscalYear,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get revenue => $composableBuilder(
    column: $table.revenue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get netIncome => $composableBuilder(
    column: $table.netIncome,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get operatingCashFlow => $composableBuilder(
    column: $table.operatingCashFlow,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get capitalExpenditure => $composableBuilder(
    column: $table.capitalExpenditure,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get totalDebt => $composableBuilder(
    column: $table.totalDebt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get cash => $composableBuilder(
    column: $table.cash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get dilutedShares => $composableBuilder(
    column: $table.dilutedShares,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get operatingIncome => $composableBuilder(
    column: $table.operatingIncome,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get depreciationAmortisation => $composableBuilder(
    column: $table.depreciationAmortisation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get totalAssets => $composableBuilder(
    column: $table.totalAssets,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get shareholdersEquity => $composableBuilder(
    column: $table.shareholdersEquity,
    builder: (column) => ColumnFilters(column),
  );

  $$CompaniesTableFilterComposer get cik {
    final $$CompaniesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cik,
      referencedTable: $db.companies,
      getReferencedColumn: (t) => t.cik,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CompaniesTableFilterComposer(
            $db: $db,
            $table: $db.companies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FiscalYearsTableOrderingComposer
    extends Composer<_$AppDatabase, $FiscalYearsTable> {
  $$FiscalYearsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get fiscalYear => $composableBuilder(
    column: $table.fiscalYear,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get revenue => $composableBuilder(
    column: $table.revenue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get netIncome => $composableBuilder(
    column: $table.netIncome,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get operatingCashFlow => $composableBuilder(
    column: $table.operatingCashFlow,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get capitalExpenditure => $composableBuilder(
    column: $table.capitalExpenditure,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get totalDebt => $composableBuilder(
    column: $table.totalDebt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get cash => $composableBuilder(
    column: $table.cash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get dilutedShares => $composableBuilder(
    column: $table.dilutedShares,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get operatingIncome => $composableBuilder(
    column: $table.operatingIncome,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get depreciationAmortisation => $composableBuilder(
    column: $table.depreciationAmortisation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get totalAssets => $composableBuilder(
    column: $table.totalAssets,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get shareholdersEquity => $composableBuilder(
    column: $table.shareholdersEquity,
    builder: (column) => ColumnOrderings(column),
  );

  $$CompaniesTableOrderingComposer get cik {
    final $$CompaniesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cik,
      referencedTable: $db.companies,
      getReferencedColumn: (t) => t.cik,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CompaniesTableOrderingComposer(
            $db: $db,
            $table: $db.companies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FiscalYearsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FiscalYearsTable> {
  $$FiscalYearsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get fiscalYear => $composableBuilder(
    column: $table.fiscalYear,
    builder: (column) => column,
  );

  GeneratedColumn<double> get revenue =>
      $composableBuilder(column: $table.revenue, builder: (column) => column);

  GeneratedColumn<double> get netIncome =>
      $composableBuilder(column: $table.netIncome, builder: (column) => column);

  GeneratedColumn<double> get operatingCashFlow => $composableBuilder(
    column: $table.operatingCashFlow,
    builder: (column) => column,
  );

  GeneratedColumn<double> get capitalExpenditure => $composableBuilder(
    column: $table.capitalExpenditure,
    builder: (column) => column,
  );

  GeneratedColumn<double> get totalDebt =>
      $composableBuilder(column: $table.totalDebt, builder: (column) => column);

  GeneratedColumn<double> get cash =>
      $composableBuilder(column: $table.cash, builder: (column) => column);

  GeneratedColumn<double> get dilutedShares => $composableBuilder(
    column: $table.dilutedShares,
    builder: (column) => column,
  );

  GeneratedColumn<double> get operatingIncome => $composableBuilder(
    column: $table.operatingIncome,
    builder: (column) => column,
  );

  GeneratedColumn<double> get depreciationAmortisation => $composableBuilder(
    column: $table.depreciationAmortisation,
    builder: (column) => column,
  );

  GeneratedColumn<double> get totalAssets => $composableBuilder(
    column: $table.totalAssets,
    builder: (column) => column,
  );

  GeneratedColumn<double> get shareholdersEquity => $composableBuilder(
    column: $table.shareholdersEquity,
    builder: (column) => column,
  );

  $$CompaniesTableAnnotationComposer get cik {
    final $$CompaniesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cik,
      referencedTable: $db.companies,
      getReferencedColumn: (t) => t.cik,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CompaniesTableAnnotationComposer(
            $db: $db,
            $table: $db.companies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FiscalYearsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FiscalYearsTable,
          FiscalYearRow,
          $$FiscalYearsTableFilterComposer,
          $$FiscalYearsTableOrderingComposer,
          $$FiscalYearsTableAnnotationComposer,
          $$FiscalYearsTableCreateCompanionBuilder,
          $$FiscalYearsTableUpdateCompanionBuilder,
          (FiscalYearRow, $$FiscalYearsTableReferences),
          FiscalYearRow,
          PrefetchHooks Function({bool cik})
        > {
  $$FiscalYearsTableTableManager(_$AppDatabase db, $FiscalYearsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FiscalYearsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FiscalYearsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FiscalYearsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> cik = const Value.absent(),
                Value<int> fiscalYear = const Value.absent(),
                Value<double?> revenue = const Value.absent(),
                Value<double?> netIncome = const Value.absent(),
                Value<double?> operatingCashFlow = const Value.absent(),
                Value<double?> capitalExpenditure = const Value.absent(),
                Value<double?> totalDebt = const Value.absent(),
                Value<double?> cash = const Value.absent(),
                Value<double?> dilutedShares = const Value.absent(),
                Value<double?> operatingIncome = const Value.absent(),
                Value<double?> depreciationAmortisation = const Value.absent(),
                Value<double?> totalAssets = const Value.absent(),
                Value<double?> shareholdersEquity = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FiscalYearsCompanion(
                cik: cik,
                fiscalYear: fiscalYear,
                revenue: revenue,
                netIncome: netIncome,
                operatingCashFlow: operatingCashFlow,
                capitalExpenditure: capitalExpenditure,
                totalDebt: totalDebt,
                cash: cash,
                dilutedShares: dilutedShares,
                operatingIncome: operatingIncome,
                depreciationAmortisation: depreciationAmortisation,
                totalAssets: totalAssets,
                shareholdersEquity: shareholdersEquity,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String cik,
                required int fiscalYear,
                Value<double?> revenue = const Value.absent(),
                Value<double?> netIncome = const Value.absent(),
                Value<double?> operatingCashFlow = const Value.absent(),
                Value<double?> capitalExpenditure = const Value.absent(),
                Value<double?> totalDebt = const Value.absent(),
                Value<double?> cash = const Value.absent(),
                Value<double?> dilutedShares = const Value.absent(),
                Value<double?> operatingIncome = const Value.absent(),
                Value<double?> depreciationAmortisation = const Value.absent(),
                Value<double?> totalAssets = const Value.absent(),
                Value<double?> shareholdersEquity = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FiscalYearsCompanion.insert(
                cik: cik,
                fiscalYear: fiscalYear,
                revenue: revenue,
                netIncome: netIncome,
                operatingCashFlow: operatingCashFlow,
                capitalExpenditure: capitalExpenditure,
                totalDebt: totalDebt,
                cash: cash,
                dilutedShares: dilutedShares,
                operatingIncome: operatingIncome,
                depreciationAmortisation: depreciationAmortisation,
                totalAssets: totalAssets,
                shareholdersEquity: shareholdersEquity,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$FiscalYearsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({cik = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (cik) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.cik,
                        referencedTable: $$FiscalYearsTableReferences._cikTable(
                          db,
                        ),
                        referencedColumn: $$FiscalYearsTableReferences
                            ._cikTable(db)
                            .cik,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$FiscalYearsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FiscalYearsTable,
      FiscalYearRow,
      $$FiscalYearsTableFilterComposer,
      $$FiscalYearsTableOrderingComposer,
      $$FiscalYearsTableAnnotationComposer,
      $$FiscalYearsTableCreateCompanionBuilder,
      $$FiscalYearsTableUpdateCompanionBuilder,
      (FiscalYearRow, $$FiscalYearsTableReferences),
      FiscalYearRow,
      PrefetchHooks Function({bool cik})
    >;
typedef $$FiscalQuartersTableCreateCompanionBuilder =
    FiscalQuartersCompanion Function({
      required String cik,
      required int fiscalYear,
      required int quarter,
      Value<double?> revenue,
      Value<double?> netIncome,
      Value<double?> operatingCashFlow,
      Value<double?> capitalExpenditure,
      Value<double?> totalDebt,
      Value<double?> cash,
      Value<int> rowid,
    });
typedef $$FiscalQuartersTableUpdateCompanionBuilder =
    FiscalQuartersCompanion Function({
      Value<String> cik,
      Value<int> fiscalYear,
      Value<int> quarter,
      Value<double?> revenue,
      Value<double?> netIncome,
      Value<double?> operatingCashFlow,
      Value<double?> capitalExpenditure,
      Value<double?> totalDebt,
      Value<double?> cash,
      Value<int> rowid,
    });

final class $$FiscalQuartersTableReferences
    extends
        BaseReferences<_$AppDatabase, $FiscalQuartersTable, FiscalQuarterRow> {
  $$FiscalQuartersTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $CompaniesTable _cikTable(_$AppDatabase db) =>
      db.companies.createAlias('fiscal_quarters__cik__companies__cik');

  $$CompaniesTableProcessedTableManager get cik {
    final $_column = $_itemColumn<String>('cik')!;

    final manager = $$CompaniesTableTableManager(
      $_db,
      $_db.companies,
    ).filter((f) => f.cik.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_cikTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$FiscalQuartersTableFilterComposer
    extends Composer<_$AppDatabase, $FiscalQuartersTable> {
  $$FiscalQuartersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get fiscalYear => $composableBuilder(
    column: $table.fiscalYear,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get quarter => $composableBuilder(
    column: $table.quarter,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get revenue => $composableBuilder(
    column: $table.revenue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get netIncome => $composableBuilder(
    column: $table.netIncome,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get operatingCashFlow => $composableBuilder(
    column: $table.operatingCashFlow,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get capitalExpenditure => $composableBuilder(
    column: $table.capitalExpenditure,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get totalDebt => $composableBuilder(
    column: $table.totalDebt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get cash => $composableBuilder(
    column: $table.cash,
    builder: (column) => ColumnFilters(column),
  );

  $$CompaniesTableFilterComposer get cik {
    final $$CompaniesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cik,
      referencedTable: $db.companies,
      getReferencedColumn: (t) => t.cik,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CompaniesTableFilterComposer(
            $db: $db,
            $table: $db.companies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FiscalQuartersTableOrderingComposer
    extends Composer<_$AppDatabase, $FiscalQuartersTable> {
  $$FiscalQuartersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get fiscalYear => $composableBuilder(
    column: $table.fiscalYear,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get quarter => $composableBuilder(
    column: $table.quarter,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get revenue => $composableBuilder(
    column: $table.revenue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get netIncome => $composableBuilder(
    column: $table.netIncome,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get operatingCashFlow => $composableBuilder(
    column: $table.operatingCashFlow,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get capitalExpenditure => $composableBuilder(
    column: $table.capitalExpenditure,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get totalDebt => $composableBuilder(
    column: $table.totalDebt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get cash => $composableBuilder(
    column: $table.cash,
    builder: (column) => ColumnOrderings(column),
  );

  $$CompaniesTableOrderingComposer get cik {
    final $$CompaniesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cik,
      referencedTable: $db.companies,
      getReferencedColumn: (t) => t.cik,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CompaniesTableOrderingComposer(
            $db: $db,
            $table: $db.companies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FiscalQuartersTableAnnotationComposer
    extends Composer<_$AppDatabase, $FiscalQuartersTable> {
  $$FiscalQuartersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get fiscalYear => $composableBuilder(
    column: $table.fiscalYear,
    builder: (column) => column,
  );

  GeneratedColumn<int> get quarter =>
      $composableBuilder(column: $table.quarter, builder: (column) => column);

  GeneratedColumn<double> get revenue =>
      $composableBuilder(column: $table.revenue, builder: (column) => column);

  GeneratedColumn<double> get netIncome =>
      $composableBuilder(column: $table.netIncome, builder: (column) => column);

  GeneratedColumn<double> get operatingCashFlow => $composableBuilder(
    column: $table.operatingCashFlow,
    builder: (column) => column,
  );

  GeneratedColumn<double> get capitalExpenditure => $composableBuilder(
    column: $table.capitalExpenditure,
    builder: (column) => column,
  );

  GeneratedColumn<double> get totalDebt =>
      $composableBuilder(column: $table.totalDebt, builder: (column) => column);

  GeneratedColumn<double> get cash =>
      $composableBuilder(column: $table.cash, builder: (column) => column);

  $$CompaniesTableAnnotationComposer get cik {
    final $$CompaniesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cik,
      referencedTable: $db.companies,
      getReferencedColumn: (t) => t.cik,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CompaniesTableAnnotationComposer(
            $db: $db,
            $table: $db.companies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FiscalQuartersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FiscalQuartersTable,
          FiscalQuarterRow,
          $$FiscalQuartersTableFilterComposer,
          $$FiscalQuartersTableOrderingComposer,
          $$FiscalQuartersTableAnnotationComposer,
          $$FiscalQuartersTableCreateCompanionBuilder,
          $$FiscalQuartersTableUpdateCompanionBuilder,
          (FiscalQuarterRow, $$FiscalQuartersTableReferences),
          FiscalQuarterRow,
          PrefetchHooks Function({bool cik})
        > {
  $$FiscalQuartersTableTableManager(
    _$AppDatabase db,
    $FiscalQuartersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FiscalQuartersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FiscalQuartersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FiscalQuartersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> cik = const Value.absent(),
                Value<int> fiscalYear = const Value.absent(),
                Value<int> quarter = const Value.absent(),
                Value<double?> revenue = const Value.absent(),
                Value<double?> netIncome = const Value.absent(),
                Value<double?> operatingCashFlow = const Value.absent(),
                Value<double?> capitalExpenditure = const Value.absent(),
                Value<double?> totalDebt = const Value.absent(),
                Value<double?> cash = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FiscalQuartersCompanion(
                cik: cik,
                fiscalYear: fiscalYear,
                quarter: quarter,
                revenue: revenue,
                netIncome: netIncome,
                operatingCashFlow: operatingCashFlow,
                capitalExpenditure: capitalExpenditure,
                totalDebt: totalDebt,
                cash: cash,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String cik,
                required int fiscalYear,
                required int quarter,
                Value<double?> revenue = const Value.absent(),
                Value<double?> netIncome = const Value.absent(),
                Value<double?> operatingCashFlow = const Value.absent(),
                Value<double?> capitalExpenditure = const Value.absent(),
                Value<double?> totalDebt = const Value.absent(),
                Value<double?> cash = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FiscalQuartersCompanion.insert(
                cik: cik,
                fiscalYear: fiscalYear,
                quarter: quarter,
                revenue: revenue,
                netIncome: netIncome,
                operatingCashFlow: operatingCashFlow,
                capitalExpenditure: capitalExpenditure,
                totalDebt: totalDebt,
                cash: cash,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$FiscalQuartersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({cik = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (cik) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.cik,
                        referencedTable: $$FiscalQuartersTableReferences
                            ._cikTable(db),
                        referencedColumn: $$FiscalQuartersTableReferences
                            ._cikTable(db)
                            .cik,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$FiscalQuartersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FiscalQuartersTable,
      FiscalQuarterRow,
      $$FiscalQuartersTableFilterComposer,
      $$FiscalQuartersTableOrderingComposer,
      $$FiscalQuartersTableAnnotationComposer,
      $$FiscalQuartersTableCreateCompanionBuilder,
      $$FiscalQuartersTableUpdateCompanionBuilder,
      (FiscalQuarterRow, $$FiscalQuartersTableReferences),
      FiscalQuarterRow,
      PrefetchHooks Function({bool cik})
    >;
typedef $$IngestRunsTableCreateCompanionBuilder = IngestRunsCompanion Function({
  Value<int> id,
  required DateTime completedAt,
  required int companyCount,
  required int extractorVersion,
  Value<DateTime?> archiveLastModified,
});
typedef $$IngestRunsTableUpdateCompanionBuilder = IngestRunsCompanion Function({
  Value<int> id,
  Value<DateTime> completedAt,
  Value<int> companyCount,
  Value<int> extractorVersion,
  Value<DateTime?> archiveLastModified,
});

class $$IngestRunsTableFilterComposer
    extends Composer<_$AppDatabase, $IngestRunsTable> {
  $$IngestRunsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get companyCount => $composableBuilder(
    column: $table.companyCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get extractorVersion => $composableBuilder(
    column: $table.extractorVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get archiveLastModified => $composableBuilder(
    column: $table.archiveLastModified,
    builder: (column) => ColumnFilters(column),
  );
}

class $$IngestRunsTableOrderingComposer
    extends Composer<_$AppDatabase, $IngestRunsTable> {
  $$IngestRunsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get companyCount => $composableBuilder(
    column: $table.companyCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get extractorVersion => $composableBuilder(
    column: $table.extractorVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get archiveLastModified => $composableBuilder(
    column: $table.archiveLastModified,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$IngestRunsTableAnnotationComposer
    extends Composer<_$AppDatabase, $IngestRunsTable> {
  $$IngestRunsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get companyCount => $composableBuilder(
    column: $table.companyCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get extractorVersion => $composableBuilder(
    column: $table.extractorVersion,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get archiveLastModified => $composableBuilder(
    column: $table.archiveLastModified,
    builder: (column) => column,
  );
}

class $$IngestRunsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $IngestRunsTable,
          IngestRunRow,
          $$IngestRunsTableFilterComposer,
          $$IngestRunsTableOrderingComposer,
          $$IngestRunsTableAnnotationComposer,
          $$IngestRunsTableCreateCompanionBuilder,
          $$IngestRunsTableUpdateCompanionBuilder,
          (
            IngestRunRow,
            BaseReferences<_$AppDatabase, $IngestRunsTable, IngestRunRow>,
          ),
          IngestRunRow,
          PrefetchHooks Function()
        > {
  $$IngestRunsTableTableManager(_$AppDatabase db, $IngestRunsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$IngestRunsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$IngestRunsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$IngestRunsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> completedAt = const Value.absent(),
                Value<int> companyCount = const Value.absent(),
                Value<int> extractorVersion = const Value.absent(),
                Value<DateTime?> archiveLastModified = const Value.absent(),
              }) => IngestRunsCompanion(
                id: id,
                completedAt: completedAt,
                companyCount: companyCount,
                extractorVersion: extractorVersion,
                archiveLastModified: archiveLastModified,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime completedAt,
                required int companyCount,
                required int extractorVersion,
                Value<DateTime?> archiveLastModified = const Value.absent(),
              }) => IngestRunsCompanion.insert(
                id: id,
                completedAt: completedAt,
                companyCount: companyCount,
                extractorVersion: extractorVersion,
                archiveLastModified: archiveLastModified,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$IngestRunsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $IngestRunsTable,
      IngestRunRow,
      $$IngestRunsTableFilterComposer,
      $$IngestRunsTableOrderingComposer,
      $$IngestRunsTableAnnotationComposer,
      $$IngestRunsTableCreateCompanionBuilder,
      $$IngestRunsTableUpdateCompanionBuilder,
      (
        IngestRunRow,
        BaseReferences<_$AppDatabase, $IngestRunsTable, IngestRunRow>,
      ),
      IngestRunRow,
      PrefetchHooks Function()
    >;
typedef $$SharePricesTableCreateCompanionBuilder =
    SharePricesCompanion Function({
      required String cik,
      required double pricePerShare,
      required DateTime asOf,
      Value<bool> isQuoted,
      Value<int> rowid,
    });
typedef $$SharePricesTableUpdateCompanionBuilder =
    SharePricesCompanion Function({
      Value<String> cik,
      Value<double> pricePerShare,
      Value<DateTime> asOf,
      Value<bool> isQuoted,
      Value<int> rowid,
    });

class $$SharePricesTableFilterComposer
    extends Composer<_$AppDatabase, $SharePricesTable> {
  $$SharePricesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get cik => $composableBuilder(
    column: $table.cik,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get pricePerShare => $composableBuilder(
    column: $table.pricePerShare,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get asOf => $composableBuilder(
    column: $table.asOf,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isQuoted => $composableBuilder(
    column: $table.isQuoted,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SharePricesTableOrderingComposer
    extends Composer<_$AppDatabase, $SharePricesTable> {
  $$SharePricesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get cik => $composableBuilder(
    column: $table.cik,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get pricePerShare => $composableBuilder(
    column: $table.pricePerShare,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get asOf => $composableBuilder(
    column: $table.asOf,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isQuoted => $composableBuilder(
    column: $table.isQuoted,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SharePricesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SharePricesTable> {
  $$SharePricesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get cik =>
      $composableBuilder(column: $table.cik, builder: (column) => column);

  GeneratedColumn<double> get pricePerShare => $composableBuilder(
    column: $table.pricePerShare,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get asOf =>
      $composableBuilder(column: $table.asOf, builder: (column) => column);

  GeneratedColumn<bool> get isQuoted =>
      $composableBuilder(column: $table.isQuoted, builder: (column) => column);
}

class $$SharePricesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SharePricesTable,
          SharePriceRow,
          $$SharePricesTableFilterComposer,
          $$SharePricesTableOrderingComposer,
          $$SharePricesTableAnnotationComposer,
          $$SharePricesTableCreateCompanionBuilder,
          $$SharePricesTableUpdateCompanionBuilder,
          (
            SharePriceRow,
            BaseReferences<_$AppDatabase, $SharePricesTable, SharePriceRow>,
          ),
          SharePriceRow,
          PrefetchHooks Function()
        > {
  $$SharePricesTableTableManager(_$AppDatabase db, $SharePricesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SharePricesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SharePricesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SharePricesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> cik = const Value.absent(),
                Value<double> pricePerShare = const Value.absent(),
                Value<DateTime> asOf = const Value.absent(),
                Value<bool> isQuoted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SharePricesCompanion(
                cik: cik,
                pricePerShare: pricePerShare,
                asOf: asOf,
                isQuoted: isQuoted,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String cik,
                required double pricePerShare,
                required DateTime asOf,
                Value<bool> isQuoted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SharePricesCompanion.insert(
                cik: cik,
                pricePerShare: pricePerShare,
                asOf: asOf,
                isQuoted: isQuoted,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SharePricesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SharePricesTable,
      SharePriceRow,
      $$SharePricesTableFilterComposer,
      $$SharePricesTableOrderingComposer,
      $$SharePricesTableAnnotationComposer,
      $$SharePricesTableCreateCompanionBuilder,
      $$SharePricesTableUpdateCompanionBuilder,
      (
        SharePriceRow,
        BaseReferences<_$AppDatabase, $SharePricesTable, SharePriceRow>,
      ),
      SharePriceRow,
      PrefetchHooks Function()
    >;
typedef $$WatchlistsTableCreateCompanionBuilder = WatchlistsCompanion Function({
  Value<int> id,
  required String name,
  required int colourIndex,
  Value<bool> isDefault,
  required DateTime createdAt,
});
typedef $$WatchlistsTableUpdateCompanionBuilder = WatchlistsCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<int> colourIndex,
  Value<bool> isDefault,
  Value<DateTime> createdAt,
});

final class $$WatchlistsTableReferences
    extends BaseReferences<_$AppDatabase, $WatchlistsTable, WatchlistRow> {
  $$WatchlistsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$WatchlistEntriesTable, List<WatchlistEntryRow>>
  _watchlistEntriesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.watchlistEntries,
    aliasName: 'watchlists__id__watchlist_entries__watchlist_id',
  );

  $$WatchlistEntriesTableProcessedTableManager get watchlistEntriesRefs {
    final manager = $$WatchlistEntriesTableTableManager(
      $_db,
      $_db.watchlistEntries,
    ).filter((f) => f.watchlistId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _watchlistEntriesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$WatchlistsTableFilterComposer
    extends Composer<_$AppDatabase, $WatchlistsTable> {
  $$WatchlistsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get colourIndex => $composableBuilder(
    column: $table.colourIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> watchlistEntriesRefs(
    Expression<bool> Function($$WatchlistEntriesTableFilterComposer f) f,
  ) {
    final $$WatchlistEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.watchlistEntries,
      getReferencedColumn: (t) => t.watchlistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WatchlistEntriesTableFilterComposer(
            $db: $db,
            $table: $db.watchlistEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$WatchlistsTableOrderingComposer
    extends Composer<_$AppDatabase, $WatchlistsTable> {
  $$WatchlistsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get colourIndex => $composableBuilder(
    column: $table.colourIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WatchlistsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WatchlistsTable> {
  $$WatchlistsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get colourIndex => $composableBuilder(
    column: $table.colourIndex,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDefault =>
      $composableBuilder(column: $table.isDefault, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> watchlistEntriesRefs<T extends Object>(
    Expression<T> Function($$WatchlistEntriesTableAnnotationComposer a) f,
  ) {
    final $$WatchlistEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.watchlistEntries,
      getReferencedColumn: (t) => t.watchlistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WatchlistEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.watchlistEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$WatchlistsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WatchlistsTable,
          WatchlistRow,
          $$WatchlistsTableFilterComposer,
          $$WatchlistsTableOrderingComposer,
          $$WatchlistsTableAnnotationComposer,
          $$WatchlistsTableCreateCompanionBuilder,
          $$WatchlistsTableUpdateCompanionBuilder,
          (WatchlistRow, $$WatchlistsTableReferences),
          WatchlistRow,
          PrefetchHooks Function({bool watchlistEntriesRefs})
        > {
  $$WatchlistsTableTableManager(_$AppDatabase db, $WatchlistsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WatchlistsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WatchlistsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WatchlistsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> colourIndex = const Value.absent(),
                Value<bool> isDefault = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => WatchlistsCompanion(
                id: id,
                name: name,
                colourIndex: colourIndex,
                isDefault: isDefault,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required int colourIndex,
                Value<bool> isDefault = const Value.absent(),
                required DateTime createdAt,
              }) => WatchlistsCompanion.insert(
                id: id,
                name: name,
                colourIndex: colourIndex,
                isDefault: isDefault,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$WatchlistsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({watchlistEntriesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (watchlistEntriesRefs) db.watchlistEntries,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (watchlistEntriesRefs)
                    await $_getPrefetchedData<
                      WatchlistRow,
                      $WatchlistsTable,
                      WatchlistEntryRow
                    >(
                      currentTable: table,
                      referencedTable: $$WatchlistsTableReferences
                          ._watchlistEntriesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$WatchlistsTableReferences(
                            db,
                            table,
                            p0,
                          ).watchlistEntriesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.watchlistId == item.id,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$WatchlistsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WatchlistsTable,
      WatchlistRow,
      $$WatchlistsTableFilterComposer,
      $$WatchlistsTableOrderingComposer,
      $$WatchlistsTableAnnotationComposer,
      $$WatchlistsTableCreateCompanionBuilder,
      $$WatchlistsTableUpdateCompanionBuilder,
      (WatchlistRow, $$WatchlistsTableReferences),
      WatchlistRow,
      PrefetchHooks Function({bool watchlistEntriesRefs})
    >;
typedef $$WatchlistEntriesTableCreateCompanionBuilder =
    WatchlistEntriesCompanion Function({
      required int watchlistId,
      required String cik,
      required DateTime addedAt,
      Value<int> rowid,
    });
typedef $$WatchlistEntriesTableUpdateCompanionBuilder =
    WatchlistEntriesCompanion Function({
      Value<int> watchlistId,
      Value<String> cik,
      Value<DateTime> addedAt,
      Value<int> rowid,
    });

final class $$WatchlistEntriesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $WatchlistEntriesTable,
          WatchlistEntryRow
        > {
  $$WatchlistEntriesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $WatchlistsTable _watchlistIdTable(_$AppDatabase db) => db.watchlists
      .createAlias('watchlist_entries__watchlist_id__watchlists__id');

  $$WatchlistsTableProcessedTableManager get watchlistId {
    final $_column = $_itemColumn<int>('watchlist_id')!;

    final manager = $$WatchlistsTableTableManager(
      $_db,
      $_db.watchlists,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_watchlistIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$WatchlistEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $WatchlistEntriesTable> {
  $$WatchlistEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get cik => $composableBuilder(
    column: $table.cik,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$WatchlistsTableFilterComposer get watchlistId {
    final $$WatchlistsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.watchlistId,
      referencedTable: $db.watchlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WatchlistsTableFilterComposer(
            $db: $db,
            $table: $db.watchlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WatchlistEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $WatchlistEntriesTable> {
  $$WatchlistEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get cik => $composableBuilder(
    column: $table.cik,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$WatchlistsTableOrderingComposer get watchlistId {
    final $$WatchlistsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.watchlistId,
      referencedTable: $db.watchlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WatchlistsTableOrderingComposer(
            $db: $db,
            $table: $db.watchlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WatchlistEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $WatchlistEntriesTable> {
  $$WatchlistEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get cik =>
      $composableBuilder(column: $table.cik, builder: (column) => column);

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  $$WatchlistsTableAnnotationComposer get watchlistId {
    final $$WatchlistsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.watchlistId,
      referencedTable: $db.watchlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WatchlistsTableAnnotationComposer(
            $db: $db,
            $table: $db.watchlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WatchlistEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WatchlistEntriesTable,
          WatchlistEntryRow,
          $$WatchlistEntriesTableFilterComposer,
          $$WatchlistEntriesTableOrderingComposer,
          $$WatchlistEntriesTableAnnotationComposer,
          $$WatchlistEntriesTableCreateCompanionBuilder,
          $$WatchlistEntriesTableUpdateCompanionBuilder,
          (WatchlistEntryRow, $$WatchlistEntriesTableReferences),
          WatchlistEntryRow,
          PrefetchHooks Function({bool watchlistId})
        > {
  $$WatchlistEntriesTableTableManager(
    _$AppDatabase db,
    $WatchlistEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WatchlistEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WatchlistEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WatchlistEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> watchlistId = const Value.absent(),
                Value<String> cik = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WatchlistEntriesCompanion(
                watchlistId: watchlistId,
                cik: cik,
                addedAt: addedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int watchlistId,
                required String cik,
                required DateTime addedAt,
                Value<int> rowid = const Value.absent(),
              }) => WatchlistEntriesCompanion.insert(
                watchlistId: watchlistId,
                cik: cik,
                addedAt: addedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$WatchlistEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({watchlistId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (watchlistId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.watchlistId,
                        referencedTable: $$WatchlistEntriesTableReferences
                            ._watchlistIdTable(db),
                        referencedColumn: $$WatchlistEntriesTableReferences
                            ._watchlistIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$WatchlistEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WatchlistEntriesTable,
      WatchlistEntryRow,
      $$WatchlistEntriesTableFilterComposer,
      $$WatchlistEntriesTableOrderingComposer,
      $$WatchlistEntriesTableAnnotationComposer,
      $$WatchlistEntriesTableCreateCompanionBuilder,
      $$WatchlistEntriesTableUpdateCompanionBuilder,
      (WatchlistEntryRow, $$WatchlistEntriesTableReferences),
      WatchlistEntryRow,
      PrefetchHooks Function({bool watchlistId})
    >;
typedef $$SettingsTableCreateCompanionBuilder = SettingsCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$SettingsTableUpdateCompanionBuilder = SettingsCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$SettingsTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SettingsTable,
          SettingRow,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (
            SettingRow,
            BaseReferences<_$AppDatabase, $SettingsTable, SettingRow>,
          ),
          SettingRow,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => SettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) => SettingsCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SettingsTable,
      SettingRow,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (SettingRow, BaseReferences<_$AppDatabase, $SettingsTable, SettingRow>),
      SettingRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CompaniesTableTableManager get companies =>
      $$CompaniesTableTableManager(_db, _db.companies);
  $$TickersTableTableManager get tickers =>
      $$TickersTableTableManager(_db, _db.tickers);
  $$FiscalYearsTableTableManager get fiscalYears =>
      $$FiscalYearsTableTableManager(_db, _db.fiscalYears);
  $$FiscalQuartersTableTableManager get fiscalQuarters =>
      $$FiscalQuartersTableTableManager(_db, _db.fiscalQuarters);
  $$IngestRunsTableTableManager get ingestRuns =>
      $$IngestRunsTableTableManager(_db, _db.ingestRuns);
  $$SharePricesTableTableManager get sharePrices =>
      $$SharePricesTableTableManager(_db, _db.sharePrices);
  $$WatchlistsTableTableManager get watchlists =>
      $$WatchlistsTableTableManager(_db, _db.watchlists);
  $$WatchlistEntriesTableTableManager get watchlistEntries =>
      $$WatchlistEntriesTableTableManager(_db, _db.watchlistEntries);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
}
