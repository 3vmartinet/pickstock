import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';

/// Opens [builder] as a modal dialog, the shadcn way.
///
/// The package ships `AlertDialog` as a plain widget but no opener, and
/// Flutter's own `showDialog` would drag Material in. `showOverlay` with a
/// [DialogConfiguration] is the idiom underneath shadcn's own dialogs, wrapped
/// here so every dialog in the app is presented identically.
Future<T?> showAppDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  return showOverlay<T>(
    context,
    const DialogConfiguration(),
    builder: (overlayContext) => ModalBackdrop(
      borderRadius: overlayContext.theme.borderRadiusXl,
      child: Builder(builder: builder),
    ),
  ).future;
}

/// Dismisses the dialog [context] sits in, handing [value] back to the caller.
void closeAppDialog<T>(BuildContext context, [T? value]) =>
    closeOverlay<T>(context, value);
