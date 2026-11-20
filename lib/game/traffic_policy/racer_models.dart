import '../car_catalog.dart';

/// Sporty bodies for racer traffic, backed by lib/game/car_catalog.dart.
/// Ids are catalog model ids; the renderer draws each racer with that body.
enum RacerModel {
  hotHatch(CarCatalog.hotHatch, null),
  sportSedan(CarCatalog.sportSedan, null),
  ponyCoupe(CarCatalog.ponyCoupe, null),
  // The electric roadster racer is always white.
  electricRoadster(CarCatalog.electricRoadster, 0xfff3f2ee);

  const RacerModel(this.id, this.fixedColor);
  final String id;
  final int? fixedColor;

  static RacerModel forTrafficId(int id) => values[id % values.length];
}
