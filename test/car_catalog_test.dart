import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cannonball/game/car_catalog.dart';
import 'package:cannonball/game/proof_car.dart';
import 'package:cannonball/game/traffic.dart';
import 'package:cannonball/game/traffic_policy/racer_models.dart';
import 'package:cannonball/services/local_store.dart';
import 'package:cannonball/ui/proof_garage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

TrafficCar _car(int id, {bool truck = false, String? model}) => TrafficCar(
  id: id,
  position: 0,
  x: 0,
  cruiseSpeed: 80,
  color: 0xffffffff,
  truck: truck,
  changeAt: 0,
  paintVariant: id % 8,
  modelId: model,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final manifest = jsonDecode(
    File('assets/cars/manifest.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  test('catalog cells, paints and lamps match the generated manifest', () {
    final cells = manifest['traffic'] as List;
    expect(cells.length, CarCatalog.traffic.length * CarCatalog.paintsPerModel);
    for (final cell in cells.cast<Map>()) {
      final model = CarCatalog.model(cell['model'] as String)!;
      final paint = cell['paintIndex'] as int;
      expect(cell['cell'], model.row * CarCatalog.paintsPerModel + paint);
      final hex = (cell['paint'] as String).substring(1);
      expect(model.paints[paint], int.parse('ff$hex', radix: 16));
      expect(model.sporty, cell['sporty']);
      expect(model.large, cell['large']);
      expect(model.lamp.x, closeTo((cell['lamps'] as Map)['x'] as num, .002));
      expect(model.lamp.y, closeTo((cell['lamps'] as Map)['y'] as num, .002));
    }
    final players = manifest['players'] as Map;
    for (final art in CarCatalog.players.values) {
      final id = art.carId == 's2000' ? 's2000_roadster' : art.carId;
      final entry = players[id] as Map;
      expect((entry['body'] as Map)['file'], art.body);
      expect((entry['turn'] as Map)['file'], art.turn);
      expect(art.lamp.x, closeTo((entry['lamps'] as Map)['x'] as num, .002));
    }
  });

  test('generic names only and no pose rescaling in the player contract', () {
    for (final model in CarCatalog.traffic) {
      expect(
        model.name.toLowerCase(),
        isNot(matches(RegExp('honda|civic|bmw|mustang|ford|tesla'))),
      );
    }
    for (final entry in (manifest['players'] as Map).values.cast<Map>()) {
      final ground = ((entry['body'] as Map)['measuredGroundY'] as List)
          .cast<num>();
      // Flat pose keeps the S2000 proof contract: tyres near y 448 of 512.
      expect(ground.first, inInclusiveRange(440, 452));
    }
  });

  test('racers drive sporty bodies; ordinary and wide traffic do not', () {
    for (final racer in RacerModel.values) {
      expect(CarCatalog.model(racer.id)!.sporty, isTrue, reason: racer.id);
    }
    expect(
      _car(3, model: RacerModel.electricRoadster.id).model,
      CarCatalog.electricRoadster,
    );
    for (var id = 0; id < 40; id++) {
      expect(CarCatalog.model(_car(id, truck: true).model)!.large, isTrue);
      final ordinary = CarCatalog.model(_car(id).model)!;
      expect(ordinary.large, isFalse);
    }
    final families = [for (var id = 0; id < 60; id++) _car(id).model]
        .where((m) => m == CarCatalog.familySedan)
        .length;
    expect(families, greaterThan(30), reason: 'ordinary roads stay ordinary');
  });

  test(
    'traffic cells stay inside the 8 x 4 atlas; white roadster stays white',
    () {
      for (final model in CarCatalog.traffic) {
        for (var paint = 0; paint < 12; paint++) {
          final cell = CarCatalog.trafficCell(model.id, paint);
          expect(cell, inInclusiveRange(0, 31));
          expect(CarCatalog.modelForCell(cell), same(model));
        }
      }
      expect(CarCatalog.trafficCell(CarCatalog.electricRoadster, 3), 0);
      expect(
        CarCatalog.trafficCell('unknown', 1),
        CarCatalog.trafficCell(CarCatalog.familySedan, 1),
      );
    },
  );

  test('car atlases are bundled with real transparency', () async {
    for (final (path, w, h) in [
      ('assets/cars/s2000_roadster-body.png', 1536, 1024),
      ('assets/cars/s2000_roadster-turn.png', 1536, 1024),
      ('assets/cars/electric_roadster-body.png', 1536, 1024),
      ('assets/cars/electric_roadster-turn.png', 1536, 1024),
      ('assets/cars/traffic-atlas.png', 2048, 1024),
      (CarCatalog.keyCard, 105, 256),
    ]) {
      final data = await rootBundle.load(path);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      expect((frame.image.width, frame.image.height), (w, h), reason: path);
      final rgba = (await frame.image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!.buffer.asUint8List();
      expect(rgba[3], lessThan(4), reason: '$path corner is transparent');
      frame.image.dispose();
      codec.dispose();
    }
  });

  test('electric roadster is a modest step over the starter', () {
    expect(electricRoadster.topSpeed, greaterThan(proofCar.topSpeed));
    expect(electricRoadster.topSpeed, lessThan(proofCar.topSpeed * 1.08));
    expect(electricRoadster.acceleration, greaterThan(proofCar.acceleration));
    expect(proofCarById('electric_roadster'), same(electricRoadster));
    expect(proofCarById(null), same(proofCar));
    expect(proofCarById('nope'), same(proofCar));
    expect(CarCatalog.players.keys, containsAll(proofCars.map((c) => c.id)));
  });

  testWidgets('garage key card selects the roadster; keys select the S2000', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final taken = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: ProofGarage(
          departing: false,
          ready: true,
          reducedMotion: false,
          muted: true,
          artwork: false,
          onTakeKeys: taken.add,
          onComplete: () {},
          onShot: (_) {},
          onSound: () {},
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('take-card')));
    await tester.tap(find.byKey(const ValueKey('take-keys')));
    expect(taken, [GarageKeys.card, GarageKeys.starter]);
    expect(GarageKeys.card, electricRoadster.id);
    expect(GarageKeys.starter, proofCar.id);
    final card = GarageHandPlacement.hook(
      const Size(1280, 720),
      GarageKeys.cardHook,
    );
    final keys = GarageHandPlacement.hook(const Size(1280, 720));
    expect(card.dx, greaterThan(keys.dx + 40), reason: 'separate hooks');
    expect(card.dy, closeTo(keys.dy, 1));
  });

  test('key choice persists under the proof car key', () {
    LocalStore().write(proofCarStoreKey, 'electric_roadster');
    expect(
      proofCarById(LocalStore().read(proofCarStoreKey)),
      same(electricRoadster),
    );
  });
}
