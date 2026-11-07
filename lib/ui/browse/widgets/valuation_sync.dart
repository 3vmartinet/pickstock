import 'package:pickstock/data/snapshot/company.dart';
import 'package:pickstock/ui/browse/browse_view_model.dart';
import 'package:pickstock/ui/browse/list_valuation_view_model.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Keeps the verdict filter and the list valuation in step.
///
/// Two ways: the verdicts go into the browse model, which filters by them,
/// and the companies the filter is choosing among go into the list
/// valuation, which prices the ones not yet judged. The two view models are
/// siblings, so this sits where both are visible, as the watchlist's sync
/// does.
class ValuationSync extends StatelessWidget {
  const ValuationSync({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final listValuation = context.read<ListValuationViewModel>();
    final browse = context.read<BrowseViewModel>();

    final revision = context.select<ListValuationViewModel, int>(
      (viewModel) => viewModel.revision,
    );
    browse.applyVerdicts(listValuation.verdicts, revision);

    final candidates = context.select<BrowseViewModel, List<Company>>(
      (viewModel) => viewModel.verdictCandidates,
    );
    listValuation.sweep(candidates);
    return child;
  }
}
