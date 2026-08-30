import 'package:pickstock/repo/theme_repo.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The small heading that introduces each block of the report.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: ThemeRepo.spaceSmall,
      children: [
        Icon(icon).iconSmall().iconMutedForeground(),
        Text(title).semiBold().small(),
      ],
    );
  }
}
