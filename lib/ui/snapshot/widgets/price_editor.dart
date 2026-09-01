import 'package:flutter/services.dart';
import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/snapshot/snapshot_view_model.dart';
import 'package:pickstock/ui/widgets/app_dialog.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Types a price by hand.
///
/// The report shows a quoted price rather than a field, so entering one is a
/// deliberate act rather than a box sitting on screen inviting nothing. It has
/// to stay possible: without an API key there is no quote, and even with one a
/// reader may want to ask what if.
class PriceEditor extends StatefulWidget {
  const PriceEditor({super.key, this.initial});

  /// The price already on screen, if any.
  final double? initial;

  @override
  State<PriceEditor> createState() => _PriceEditorState();
}

class _PriceEditorState extends State<PriceEditor> {
  late final TextEditingController _price = TextEditingController(
    text: widget.initial == null ? '' : _text(widget.initial!),
  );

  /// Trailing zeros are dropped: `182.4` reads better than `182.40` in a field
  /// about to be edited.
  static String _text(double price) {
    final written = price.toStringAsFixed(2);
    return written.endsWith('0')
        ? written.substring(0, written.length - 1)
        : written;
  }

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  void _save() {
    context.read<SnapshotViewModel>().enterPrice(_price.text);
    closeAppDialog(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.strings.priceEditorTitle),
      content: SizedBox(
        width: ThemeRepo.dialogWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          spacing: ThemeRepo.spaceSmall,
          children: [
            TextField(
              controller: _price,
              autofocus: true,
              placeholder: Text(context.strings.placeholderSharePrice),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              // A comma passes: it is the decimal point in half the world, and
              // the view model reads it as one.
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              features: const [
                InputFeature.leading(Icon(LucideIcons.dollarSign)),
                InputFeature.clear(),
              ],
              onSubmitted: (_) => _save(),
            ),
            Text(context.strings.priceEditorHint).muted().xSmall(),
          ],
        ),
      ),
      actions: [
        OutlineButton(
          onPressed: () => closeAppDialog(context),
          child: Text(context.strings.watchlistCancel),
        ),
        PrimaryButton(
          onPressed: _save,
          child: Text(context.strings.watchlistSave),
        ),
      ],
    );
  }
}

/// Opens the editor over whatever is on screen.
Future<void> showPriceEditor(BuildContext context) {
  final viewModel = context.read<SnapshotViewModel>();
  return showAppDialog<void>(
    context,
    builder: (_) => ChangeNotifierProvider<SnapshotViewModel>.value(
      value: viewModel,
      child: PriceEditor(initial: viewModel.pricePerShare),
    ),
  );
}
