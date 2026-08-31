import 'package:pickstock/data/snapshot/company.dart';
import 'package:pickstock/data/snapshot/financial_snapshot.dart';
import 'package:pickstock/data/snapshot/fiscal_quarter_figures.dart';
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

/// Apple's four most recent filed quarters, for the quarterly view.
const List<FiscalQuarterFigures> _appleQuarters = [
  FiscalQuarterFigures(
    fiscalYear: 2025,
    quarter: 1,
    revenue: 124300000000,
    priorRevenue: 119575000000,
    netIncome: 36330000000,
    cash: 30299000000,
    totalDebt: 96799000000,
  ),
  FiscalQuarterFigures(
    fiscalYear: 2025,
    quarter: 2,
    revenue: 95359000000,
    priorRevenue: 90753000000,
    netIncome: 24780000000,
    cash: 28162000000,
    totalDebt: 98186000000,
  ),
  FiscalQuarterFigures(
    fiscalYear: 2025,
    quarter: 3,
    revenue: 94036000000,
    priorRevenue: 85777000000,
    netIncome: 23434000000,
    cash: 31032000000,
    totalDebt: 101698000000,
  ),
  FiscalQuarterFigures(
    fiscalYear: 2025,
    quarter: 4,
    revenue: 102466000000,
    priorRevenue: 94930000000,
    netIncome: 27466000000,
    cash: 35934000000,
    totalDebt: 98657000000,
  ),
];

const Company _nvidia = Company(
  ticker: 'NVDA',
  cik: '0001045810',
  name: 'NVIDIA CORP',
);

/// NVIDIA's filed figures: a company holding more cash than debt, which is the
/// other side of the balance-sheet card from Apple.
const List<FiscalYearFigures> _nvidiaYears = [
  FiscalYearFigures(
    fiscalYear: 2025,
    revenue: 130497000000,
    priorRevenue: 60922000000,
    netIncome: 72880000000,
    operatingCashFlow: 64089000000,
    capitalExpenditure: 3236000000,
    totalDebt: 8463000000,
    cash: 8589000000,
  ),
  FiscalYearFigures(
    fiscalYear: 2026,
    revenue: 215938000000,
    priorRevenue: 130497000000,
    netIncome: 120067000000,
    operatingCashFlow: 101000000000,
    capitalExpenditure: 4324000000,
    totalDebt: 8468000000,
    cash: 10605000000,
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
    return switch (ticker.trim().toUpperCase()) {
      'AAPL' => const FinancialSnapshot(
        company: _apple,
        years: _appleYears,
        quarters: _appleQuarters,
      ),
      'NVDA' => const FinancialSnapshot(company: _nvidia, years: _nvidiaYears),
      _ => throw const SecException(SecFailure.unknownTicker),
    };
  }
}
