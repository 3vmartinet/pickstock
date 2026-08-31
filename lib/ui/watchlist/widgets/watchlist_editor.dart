import 'package:pickstock/data/watchlist/watchlist.dart';
import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:pickstock/repo/db/app_database.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/watchlist/watchlist_view_model.dart';
import 'package:pickstock/ui/widgets/app_dialog.dart';
import 'package:pickstock/ui/watchlist/widgets/watchlist_dot.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// How many swatches the picker offers, matching the palette in `ThemeRepo`.
const int _paletteSize = 8;

/// Creates a list, or edits the name and colour of one.
///
/// One dialog for both: the fields are identical, and a separate "rename"
/// sheet would be the same form with a different title.
class WatchlistEditor extends StatefulWidget {
  const WatchlistEditor({
    super.key,
    this.existing,
    required this.initialColour,
  });

  /// The list being edited, or `null` when creating one.
  final Watchlist? existing;

  /// The colour a new list starts on.
  final int initialColour;

  @override
  State<WatchlistEditor> createState() => _WatchlistEditorState();
}

class _WatchlistEditorState extends State<WatchlistEditor> {
  late final TextEditingController _name = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late int _colour = widget.existing?.colourIndex ?? widget.initialColour;

  bool get _isNew => widget.existing == null;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final viewModel = context.read<WatchlistViewModel>();
    final existing = widget.existing;
    if (existing != null) {
      await viewModel.rename(existing.id, name, _colour);
      if (mounted) closeAppDialog(context);
      return;
    }
    // The id goes back to the caller, which may want to put a company in the
    // list it just made.
    final id = await viewModel.create(name, _colour);
    if (mounted) closeAppDialog<int>(context, id);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        _isNew ? context.strings.watchlistNew : context.strings.watchlistEdit,
      ),
      content: SizedBox(
        width: ThemeRepo.dialogWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          spacing: ThemeRepo.spaceMedium,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: ThemeRepo.spaceSmall,
              children: [
                Text(context.strings.watchlistNameLabel).small().semiBold(),
                TextField(
                  controller: _name,
                  autofocus: true,
                  maxLength: watchlistNameMaxLength,
                  placeholder: Text(context.strings.watchlistNamePlaceholder),
                  onSubmitted: (_) => _save(),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: ThemeRepo.spaceSmall,
              children: [
                Text(context.strings.watchlistColourLabel).small().semiBold(),
                Wrap(
                  spacing: ThemeRepo.spaceSmall,
                  runSpacing: ThemeRepo.spaceSmall,
                  children: [
                    for (var index = 0; index < _paletteSize; index++)
                      _Swatch(
                        colourIndex: index,
                        isSelected: index == _colour,
                        onPressed: () => setState(() => _colour = index),
                      ),
                  ],
                ),
              ],
            ),
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
          child: Text(
            _isNew
                ? context.strings.watchlistCreate
                : context.strings.watchlistSave,
          ),
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.colourIndex,
    required this.isSelected,
    required this.onPressed,
  });

  final int colourIndex;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GhostButton(
      density: ButtonDensity.compact,
      onPressed: onPressed,
      // The chosen swatch is ringed rather than merely larger, so the choice
      // survives being looked at in a hurry.
      child: Container(
        width: ThemeRepo.watchlistSwatchSize,
        height: ThemeRepo.watchlistSwatchSize,
        alignment: Alignment.center,
        decoration: isSelected
            ? BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.foreground,
                  width: ThemeRepo.watchlistSwatchRing,
                ),
              )
            : null,
        child: WatchlistDot(
          colourIndex: colourIndex,
          size: ThemeRepo.watchlistSwatchSize / 2,
        ),
      ),
    );
  }
}
