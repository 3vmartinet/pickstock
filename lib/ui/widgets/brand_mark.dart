import 'package:pickstock/repo/theme_repo.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';

/// The app's mark, shown at the head of the main screen.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ThemeRepo.spaceSmall),
      decoration: BoxDecoration(
        color: context.theme.colorScheme.primary,
        borderRadius: context.theme.borderRadiusMd,
      ),
      child: const Icon(LucideIcons.chartNoAxesColumn)
          .iconSmall()
          .iconPrimaryForeground(),
    );
  }
}
