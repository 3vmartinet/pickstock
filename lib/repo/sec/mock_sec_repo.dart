import 'package:pickstock/data/snapshot/company.dart';
import 'package:pickstock/data/snapshot/financial_snapshot.dart';
import 'package:pickstock/data/snapshot/fiscal_year_figures.dart';
import 'package:pickstock/repo/sec/sec_repo.dart';

const Duration _simulatedLatency = Duration(milliseconds: 900);

const Company _apple = Company(
  ticker: 'AAPL',
  cik: '0000320193',
  name: 'Apple Inc.',
);

/// Apple's figures exactly as filed, in whole dollars, so the fixture stays
/// honest about what EDGAR actually returns.
const List<FiscalYearFigures> _appleYears = [
  FiscalYearFigures(
    fiscalYear: 2023,
    revenue: 383285000000,
    priorRevenue: 394328000000,
    netIncome: 96995000000,
    operatingCashFlow: 110543000000,
    capitalExpenditure: 10959000000,
    totalDebt: 111088000000,
    cash: 29965000000,
  ),
  FiscalYearFigures(
    fiscalYear: 2024,
    revenue: 391035000000,
    priorRevenue: 383285000000,
    netIncome: 93736000000,
    operatingCashFlow: 118254000000,
    capitalExpenditure: 9447000000,
    totalDebt: 106629000000,
    cash: 29943000000,
  ),
  FiscalYearFigures(
    fiscalYear: 2025,
    revenue: 416161000000,
    priorRevenue: 391035000000,
    netIncome: 112010000000,
    operatingCashFlow: 111482000000,
    capitalExpenditure: 12715000000,
    totalDebt: 98657000000,
    cash: 35934000000,
  ),
];

/// Serves one canned snapshot so the UI can be driven without a network, and
/// so widget tests stay deterministic. Any ticker other than the fixture's is
/// reported as unknown, exactly as EDGAR would.
class MockSecRepo implements SecRepo {
  const MockSecRepo();

  @override
  Future<FinancialSnapshot> fetchSnapshot(String ticker) async {
    await Future<void>.delayed(_simulatedLatency);
    if (ticker.trim().toUpperCase() != _apple.ticker) {
      throw const SecException(SecFailure.unknownTicker);
    }
    return const FinancialSnapshot(company: _apple, years: _appleYears);
  }
}
