import 'package:equatable/equatable.dart';

/// Where a run has got to.
enum JobState { running, done, failed, cancelled }

/// A bulk valuation in flight.
///
/// Held in memory only: a run that was interrupted has nothing worth resuming,
/// since the prices it collected are already stored and the rest have moved on.
class ValuationJob extends Equatable {
  const ValuationJob({
    required this.id,
    required this.name,
    required this.total,
    this.processed = 0,
    this.found = 0,
    this.state = JobState.running,
    this.reportId,
    this.startedAt,
  });

  final int id;
  final String name;

  /// How many companies the run will look at.
  final int total;

  /// How many it has got through, whether or not they could be valued.
  final int processed;

  /// How many came out undervalued.
  final int found;

  final JobState state;

  /// The saved report, once there is one.
  final int? reportId;

  final DateTime? startedAt;

  double get progress => total == 0 ? 1 : processed / total;

  bool get isRunning => state == JobState.running;

  /// How long the rest should take, from the rate actually achieved so far.
  ///
  /// Measured rather than assumed: the provider's own pace varies, and a run
  /// that started slowly should say so rather than promising the theoretical
  /// sixty a minute.
  Duration? get remaining {
    final started = startedAt;
    if (started == null || processed == 0 || !isRunning) return null;
    final elapsed = DateTime.now().difference(started);
    final perCompany = elapsed.inMilliseconds / processed;
    return Duration(milliseconds: ((total - processed) * perCompany).round());
  }

  ValuationJob copyWith({
    int? processed,
    int? found,
    JobState? state,
    int? reportId,
    DateTime? startedAt,
  }) => ValuationJob(
    id: id,
    name: name,
    total: total,
    processed: processed ?? this.processed,
    found: found ?? this.found,
    state: state ?? this.state,
    reportId: reportId ?? this.reportId,
    startedAt: startedAt ?? this.startedAt,
  );

  @override
  List<Object?> get props => [
    id,
    name,
    total,
    processed,
    found,
    state,
    reportId,
  ];
}
