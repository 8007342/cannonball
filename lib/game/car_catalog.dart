import 'package:flutter/foundation.dart';

/// Brake-lamp centre in sprite-basis units: x from the centre line and y above
/// the ground anchor, both as a fraction of the drawn basis width. Measured by
/// tool/rigs/cars from the rig's projected lamp geometry (assets/cars/manifest.json).
@immutable
class LampOffset {
  const LampOffset(this.x, this.y);
  final double x, y;
  static const legacy = LampOffset(.29, .39);
}

/// One traffic body in assets/cars/traffic-atlas.png. Original inspired-by
/// shapes: no logos, badges, wordmarks or plate text, and generic names.
@immutable
class CarModel {
  const CarModel({
    required this.id,
    required this.name,
    required this.row,
    required this.paints,
    required this.lamp,
    this.sporty = false,
    this.large = false,
    this.fixedPaint,
  });
  final String id, name;

  /// First atlas cell is `row * paintsPerModel`; paints follow in order.
  final int row;
  final List<int> paints;
  final LampOffset lamp;

  /// Sporty bodies carry the aggressive (racer/pushy/brisk) drivers.
  final bool sporty;

  /// Large bodies stand in for the controller's wide (`truck`) vehicles.
  final bool large;

  /// Paint index always used for this model (the white electric roadster).
  final int? fixedPaint;
}

/// A playable car's chase-camera sheets (same layout/anchors as the S2000 proof).
@immutable
class PlayerCarArt {
  const PlayerCarArt({
    required this.carId,
    required this.body,
    required this.turn,
    required this.lamp,
    this.exterior,
    this.entry,
    this.cabin,
  });
  final String carId, body, turn;
  final LampOffset lamp;

  /// Garage departure views rendered from the rig (null: the painted S2000
  /// originals). [entry] follows proof-next/entry-atlas.png; cell 3 = door.
  final String? exterior, entry, cabin;
}

/// Shared car catalogue: art ids for the renderer, model ids for traffic AI.
abstract final class CarCatalog {
  static const trafficAtlas = 'assets/cars/traffic-atlas.png';
  static const keyCard = 'assets/cars/keycard.png';
  static const trafficColumns = 8, paintsPerModel = 4;

  static const hotHatch = 'civic_hot_hatch';
  static const sportSedan = 'sport_sedan_3';
  static const ponyCoupe = 'pony_coupe';
  static const electricRoadster = 'electric_roadster';
  static const familySedan = 'family_sedan';
  static const suv = 'suv';
  static const pickup = 'pickup';
  static const minivan = 'minivan';

  /// Order and lamp values mirror assets/cars/manifest.json (checked by test).
  static const traffic = <CarModel>[
    CarModel(
      id: electricRoadster,
      name: 'Electric Roadster',
      row: 0,
      paints: [0xfff3f2ee, 0xffeef0f2, 0xffb51f2a, 0xff1c1f24],
      lamp: LampOffset(.323, .286),
      sporty: true,
      fixedPaint: 0,
    ),
    CarModel(
      id: hotHatch,
      name: 'Hot Hatch',
      row: 1,
      paints: [0xfff2f1ec, 0xffc4202b, 0xff25459c, 0xff3a3d42],
      lamp: LampOffset(.301, .44),
      sporty: true,
    ),
    CarModel(
      id: sportSedan,
      name: 'Sport Sedan',
      row: 2,
      paints: [0xff1f4f9a, 0xffeceae4, 0xff18191c, 0xff80878e],
      lamp: LampOffset(.327, .432),
      sporty: true,
    ),
    CarModel(
      id: ponyCoupe,
      name: 'Pony Coupe',
      row: 3,
      paints: [0xfff2c230, 0xffb3231e, 0xff3b3f45, 0xff2a5aa6],
      lamp: LampOffset(.289, .321),
      sporty: true,
    ),
    CarModel(
      id: familySedan,
      name: 'Family Sedan',
      row: 4,
      paints: [0xffb9bec4, 0xffc9b893, 0xff7a2430, 0xff22324f],
      lamp: LampOffset(.297, .413),
    ),
    CarModel(
      id: suv,
      name: 'Crossover',
      row: 5,
      paints: [0xff3e5a46, 0xffefede7, 0xffaeb3b8, 0xff24324a],
      lamp: LampOffset(.353, .454),
      large: true,
    ),
    CarModel(
      id: pickup,
      name: 'Pickup',
      row: 6,
      paints: [0xffa8262a, 0xfff0eee8, 0xff1e2024, 0xff5b6f84],
      lamp: LampOffset(.404, .325),
      large: true,
    ),
    CarModel(
      id: minivan,
      name: 'Minivan',
      row: 7,
      paints: [0xffc3c7cc, 0xfff1efe9, 0xffb9a585, 0xff22335a],
      lamp: LampOffset(.378, .459),
      large: true,
    ),
  ];

  static const players = <String, PlayerCarArt>{
    's2000': PlayerCarArt(
      carId: 's2000',
      body: 'assets/cars/s2000_roadster-body.png',
      turn: 'assets/cars/s2000_roadster-turn.png',
      lamp: LampOffset(.263, .354),
    ),
    electricRoadster: PlayerCarArt(
      carId: electricRoadster,
      body: 'assets/cars/electric_roadster-body.png',
      turn: 'assets/cars/electric_roadster-turn.png',
      lamp: LampOffset(.323, .286),
      exterior: 'assets/cars/electric_roadster-exterior.png',
      entry: 'assets/cars/electric_roadster-entry.png',
      cabin: 'assets/cars/electric_roadster-cabin.png',
    ),
  };

  static CarModel? model(String? id) {
    for (final model in traffic) {
      if (model.id == id) return model;
    }
    return null;
  }

  static List<CarModel> get sportyModels => [
    for (final model in traffic)
      if (model.sporty) model,
  ];

  /// Ordinary drivers: mostly family sedans, with the occasional sport sedan
  /// or white electric roadster; wide vehicles come from the large bodies.
  static const _ordinary = [
    familySedan,
    familySedan,
    familySedan,
    sportSedan,
    familySedan,
    electricRoadster,
  ];
  static const _large = [suv, pickup, minivan];

  /// Deterministic body for a non-racer (no extra random draws).
  static String ordinaryModelFor(int id, {required bool large}) {
    final pool = large ? _large : _ordinary;
    return pool[(id * 7 + 3) % pool.length];
  }

  /// Atlas cell (row-major, [trafficColumns] wide) for a model and paint.
  static int trafficCell(String? id, int paintVariant) {
    final found = model(id) ?? model(familySedan)!;
    final paint = found.fixedPaint ?? paintVariant % paintsPerModel;
    return found.row * paintsPerModel + paint;
  }

  static CarModel modelForCell(int cell) =>
      traffic[(cell ~/ paintsPerModel).clamp(0, traffic.length - 1)];
}
