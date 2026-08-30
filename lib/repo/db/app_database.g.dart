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
  @override
  List<GeneratedColumn> get $columns => [cik, name];
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
  const CompanyRow({required this.cik, required this.name});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['cik'] = Variable<String>(cik);
    map['name'] = Variable<String>(name);
    return map;
  }

  CompaniesCompanion toCompanion(bool nullToAbsent) {
    return CompaniesCompanion(cik: Value(cik), name: Value(name));
  }

  factory CompanyRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CompanyRow(
      cik: serializer.fromJson<String>(json['cik']),
      name: serializer.fromJson<String>(json['name']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'cik': serializer.toJson<String>(cik),
      'name': serializer.toJson<String>(name),
    };
  }

  CompanyRow copyWith({String? cik, String? name}) =>
      CompanyRow(cik: cik ?? this.cik, name: name ?? this.name);
  CompanyRow copyWithCompanion(CompaniesCompanion data) {
    return CompanyRow(
      cik: data.cik.present ? data.cik.value : this.cik,
      name: data.name.present ? data.name.value : this.name,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CompanyRow(')
          ..write('cik: $cik, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(cik, name);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CompanyRow && other.cik == this.cik && other.name == this.name);
}

class CompaniesCompanion extends UpdateCompanion<CompanyRow> {
  final Value<String> cik;
  final Value<String> name;
  final Value<int> rowid;
  const CompaniesCompanion({
    this.cik = const Value.absent(),
    this.name = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CompaniesCompanion.insert({
    required String cik,
    required String name,
    this.rowid = const Value.absent(),
  }) : cik = Value(cik),
       name = Value(name);
  static Insertable<CompanyRow> custom({
    Expression<String>? cik,
    Expression<String>? name,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (cik != null) 'cik': cik,
      if (name != null) 'name': name,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CompaniesCompanion copyWith({
    Value<String>? cik,
    Value<String>? name,
    Value<int>? rowid,
  }) {
    return CompaniesCompanion(
      cik: cik ?? this.cik,
      name: name ?? this.name,
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
  const FiscalYearRow({
    required this.cik,
    required this.fiscalYear,
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
          ..write('cash: $cash')
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
          other.cash == this.cash);
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    completedAt,
    companyCount,
    extractorVersion,
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
  const IngestRunRow({
    required this.id,
    required this.completedAt,
    required this.companyCount,
    required this.extractorVersion,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['completed_at'] = Variable<DateTime>(completedAt);
    map['company_count'] = Variable<int>(companyCount);
    map['extractor_version'] = Variable<int>(extractorVersion);
    return map;
  }

  IngestRunsCompanion toCompanion(bool nullToAbsent) {
    return IngestRunsCompanion(
      id: Value(id),
      completedAt: Value(completedAt),
      companyCount: Value(companyCount),
      extractorVersion: Value(extractorVersion),
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
    };
  }

  IngestRunRow copyWith({
    int? id,
    DateTime? completedAt,
    int? companyCount,
    int? extractorVersion,
  }) => IngestRunRow(
    id: id ?? this.id,
    completedAt: completedAt ?? this.completedAt,
    companyCount: companyCount ?? this.companyCount,
    extractorVersion: extractorVersion ?? this.extractorVersion,
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
    );
  }

  @override
  String toString() {
    return (StringBuffer('IngestRunRow(')
          ..write('id: $id, ')
          ..write('completedAt: $completedAt, ')
          ..write('companyCount: $companyCount, ')
          ..write('extractorVersion: $extractorVersion')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, completedAt, companyCount, extractorVersion);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is IngestRunRow &&
          other.id == this.id &&
          other.completedAt == this.completedAt &&
          other.companyCount == this.companyCount &&
          other.extractorVersion == this.extractorVersion);
}

class IngestRunsCompanion extends UpdateCompanion<IngestRunRow> {
  final Value<int> id;
  final Value<DateTime> completedAt;
  final Value<int> companyCount;
  final Value<int> extractorVersion;
  const IngestRunsCompanion({
    this.id = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.companyCount = const Value.absent(),
    this.extractorVersion = const Value.absent(),
  });
  IngestRunsCompanion.insert({
    this.id = const Value.absent(),
    required DateTime completedAt,
    required int companyCount,
    required int extractorVersion,
  }) : completedAt = Value(completedAt),
       companyCount = Value(companyCount),
       extractorVersion = Value(extractorVersion);
  static Insertable<IngestRunRow> custom({
    Expression<int>? id,
    Expression<DateTime>? completedAt,
    Expression<int>? companyCount,
    Expression<int>? extractorVersion,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (completedAt != null) 'completed_at': completedAt,
      if (companyCount != null) 'company_count': companyCount,
      if (extractorVersion != null) 'extractor_version': extractorVersion,
    });
  }

  IngestRunsCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? completedAt,
    Value<int>? companyCount,
    Value<int>? extractorVersion,
  }) {
    return IngestRunsCompanion(
      id: id ?? this.id,
      completedAt: completedAt ?? this.completedAt,
      companyCount: companyCount ?? this.companyCount,
      extractorVersion: extractorVersion ?? this.extractorVersion,
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
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('IngestRunsCompanion(')
          ..write('id: $id, ')
          ..write('completedAt: $completedAt, ')
          ..write('companyCount: $companyCount, ')
          ..write('extractorVersion: $extractorVersion')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CompaniesTable companies = $CompaniesTable(this);
  late final $FiscalYearsTable fiscalYears = $FiscalYearsTable(this);
  late final $IngestRunsTable ingestRuns = $IngestRunsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    companies,
    fiscalYears,
    ingestRuns,
  ];
}

typedef $$CompaniesTableCreateCompanionBuilder = CompaniesCompanion Function({
  required String cik,
  required String name,
  Value<int> rowid,
});
typedef $$CompaniesTableUpdateCompanionBuilder = CompaniesCompanion Function({
  Value<String> cik,
  Value<String> name,
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
          PrefetchHooks Function({bool fiscalYearsRefs})
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
          updateCompanionCallback: ({
            Value<String> cik = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => CompaniesCompanion(cik: cik, name: name, rowid: rowid),
          createCompanionCallback: ({
            required String cik,
            required String name,
            Value<int> rowid = const Value.absent(),
          }) => CompaniesCompanion.insert(cik: cik, name: name, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CompaniesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({fiscalYearsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (fiscalYearsRefs) db.fiscalYears],
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
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.cik == item.cik),
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
      PrefetchHooks Function({bool fiscalYearsRefs})
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
typedef $$IngestRunsTableCreateCompanionBuilder = IngestRunsCompanion Function({
  Value<int> id,
  required DateTime completedAt,
  required int companyCount,
  required int extractorVersion,
});
typedef $$IngestRunsTableUpdateCompanionBuilder = IngestRunsCompanion Function({
  Value<int> id,
  Value<DateTime> completedAt,
  Value<int> companyCount,
  Value<int> extractorVersion,
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
              }) => IngestRunsCompanion(
                id: id,
                completedAt: completedAt,
                companyCount: companyCount,
                extractorVersion: extractorVersion,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime completedAt,
                required int companyCount,
                required int extractorVersion,
              }) => IngestRunsCompanion.insert(
                id: id,
                completedAt: completedAt,
                companyCount: companyCount,
                extractorVersion: extractorVersion,
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

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CompaniesTableTableManager get companies =>
      $$CompaniesTableTableManager(_db, _db.companies);
  $$FiscalYearsTableTableManager get fiscalYears =>
      $$FiscalYearsTableTableManager(_db, _db.fiscalYears);
  $$IngestRunsTableTableManager get ingestRuns =>
      $$IngestRunsTableTableManager(_db, _db.ingestRuns);
}
