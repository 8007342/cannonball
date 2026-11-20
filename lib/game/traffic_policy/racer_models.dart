/// Placeholder sporty-model mapping for racer traffic until
/// lib/game/car_catalog.dart (owned separately) lands. Ids are plain strings
/// so switching to the catalog is a one-line lookup change.
enum RacerModel {
  civicTypeR('civic_type_r', null),
  bmw3Series('bmw_3_series', null),
  mustang('mustang', null),
  // The white Tesla Roadster is always white.
  teslaRoadster('tesla_roadster', 0xfff2f1ec);

  const RacerModel(this.id, this.fixedColor);
  final String id;
  final int? fixedColor;

  static RacerModel forTrafficId(int id) => values[id % values.length];
}
