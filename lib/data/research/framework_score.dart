import 'package:equatable/equatable.dart';
import 'package:pickstock/data/research/framework_question.dart';

/// Where one company stands on the seven questions, as the tiles and
/// the report's tab show it.
class FrameworkScore extends Equatable {
  const FrameworkScore({required this.verdicts});

  /// The answers on file, by question. Only the ones answered.
  final Map<FrameworkQuestion, FrameworkVerdict> verdicts;

  /// How many questions came back yes, which is what the gauge reads.
  int get satisfied => verdicts.values
      .where((verdict) => verdict == FrameworkVerdict.yes)
      .length;

  int get answered => verdicts.length;

  FrameworkOutcome get outcome => FrameworkOutcome.from(verdicts.values);

  @override
  List<Object?> get props => [verdicts];
}
