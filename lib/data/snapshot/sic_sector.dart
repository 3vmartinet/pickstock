import 'package:pickstock/l10n/app_localizations.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// A coarse industry grouping, derived from a filer's SIC code.
///
/// SEC classifies filers with Standard Industrial Classification codes — some
/// 440 of them, at a granularity ("Semiconductors & Related Devices") far
/// finer than a filter row can use. Each case here collects the SIC ranges
/// that belong to one recognisable sector.
enum SicSector {
  technology(
    icon: LucideIcons.cpu,
    ranges: [(3570, 3579), (3600, 3699), (7300, 7399)],
  ),
  healthcare(
    icon: LucideIcons.pill,
    ranges: [(2830, 2836), (3826, 3829), (3840, 3851), (8000, 8099)],
  ),
  financials(
    icon: LucideIcons.landmark,
    ranges: [(6000, 6199), (6200, 6299), (6300, 6499)],
  ),
  realEstate(icon: LucideIcons.building2, ranges: [(6500, 6599), (6700, 6799)]),
  energy(
    icon: LucideIcons.fuel,
    ranges: [(1200, 1399), (2900, 2999), (4600, 4699)],
  ),
  utilities(icon: LucideIcons.zap, ranges: [(4900, 4999)]),
  industrials(
    icon: LucideIcons.factory,
    ranges: [
      (1500, 1799),
      (3400, 3569),
      (3580, 3599),
      (3700, 3710),
      (3712, 3799),
      (8700, 8799),
    ],
  ),
  automotive(icon: LucideIcons.car, ranges: [(3711, 3711), (5500, 5599)]),
  materials(
    icon: LucideIcons.pickaxe,
    ranges: [
      (1000, 1199),
      (1400, 1499),
      (2600, 2699),
      (2800, 2829),
      (2837, 2899),
      (3200, 3399),
    ],
  ),
  consumer(
    icon: LucideIcons.shoppingBag,
    ranges: [
      (2000, 2199),
      (2200, 2599),
      (3000, 3199),
      (3900, 3999),
      (5000, 5499),
      (5600, 5999),
      (7000, 7099),
      (7900, 7999),
    ],
  ),
  communications(
    icon: LucideIcons.radioTower,
    ranges: [(2700, 2799), (4800, 4899)],
  ),
  transport(icon: LucideIcons.truck, ranges: [(4000, 4599), (4700, 4799)]);

  const SicSector({required this.icon, required this.ranges});

  final IconData icon;

  /// Inclusive SIC ranges belonging to this sector.
  final List<(int from, int to)> ranges;

  String getLabel(AppLocalizations strings) => switch (this) {
    SicSector.technology => strings.sectorTechnology,
    SicSector.healthcare => strings.sectorHealthcare,
    SicSector.financials => strings.sectorFinancials,
    SicSector.realEstate => strings.sectorRealEstate,
    SicSector.energy => strings.sectorEnergy,
    SicSector.utilities => strings.sectorUtilities,
    SicSector.industrials => strings.sectorIndustrials,
    SicSector.automotive => strings.sectorAutomotive,
    SicSector.materials => strings.sectorMaterials,
    SicSector.consumer => strings.sectorConsumer,
    SicSector.communications => strings.sectorCommunications,
    SicSector.transport => strings.sectorTransport,
  };

  /// The sector [sic] belongs to, or `null` for a code outside every range —
  /// agriculture and public administration among them, which are too rare
  /// among filers to earn a filter of their own.
  static SicSector? of(int? sic) {
    if (sic == null) return null;
    for (final sector in values) {
      for (final (from, to) in sector.ranges) {
        if (sic >= from && sic <= to) return sector;
      }
    }
    return null;
  }
}
