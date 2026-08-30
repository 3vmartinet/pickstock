import 'package:pickstock/data/snapshot/financial_snapshot.dart';
import 'package:pickstock/repo/sec/sec_repo.dart';

/// Everything the snapshot screen can be showing at a given moment.
sealed class SnapshotState {
  const SnapshotState();
}

/// Nothing searched yet.
final class SnapshotIdle extends SnapshotState {
  const SnapshotIdle();
}

/// A lookup is in flight for [ticker].
final class SnapshotLoading extends SnapshotState {
  const SnapshotLoading(this.ticker);

  final String ticker;
}

/// Figures are on screen.
final class SnapshotLoaded extends SnapshotState {
  const SnapshotLoaded(this.snapshot);

  final FinancialSnapshot snapshot;
}

/// The lookup for [ticker] failed in a way the user can be told about.
final class SnapshotFailed extends SnapshotState {
  const SnapshotFailed({required this.ticker, required this.failure});

  final String ticker;
  final SecFailure failure;
}
