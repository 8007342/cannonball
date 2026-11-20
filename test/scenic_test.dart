import 'dart:convert';
import 'dart:ui' as ui;

import 'package:cannonball/game/proof_course.dart';
import 'package:cannonball/game/scenic/road_surfaces.dart';
import 'package:cannonball/game/scenic/scenic_bands.dart';
import 'package:cannonball/game/scenic/scenic_fallback.dart';
import 'package:cannonball/game/scenic/scenic_library.dart';
import 'package:cannonball/game/scenic/scenic_manifest.dart';
import 'package:cannonball/game/scenic/scenic_scheduler.dart';
import 'package:cannonball/game/scenic/scenic_zones.dart';
import 'package:cannonball/game/terrain/level_profiles.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> sprite(
  String id,
  String band,
  String kind,
  double width, {
  List<String> tags = const [],
  List<String> biomes = const [],
  List<String> frames = const [],
  int cell = 0,
}) => {
  'id': id,
  'atlas': 'fixture',
  'rect': [(cell % 4) * 64, (cell ~/ 4) * 64, 64, 64],
  'anchor': [32, 63],
  'worldWidthM': width,
  'band': band,
  'kind': kind,
  'biomes': biomes,
  'tags': tags,
  'frames': frames,
};

final fixture = {
  'version': 'scenic-1',
  'atlases': [
    {'id': 'fixture', 'file': 'fixture.png', 'width': 256, 'height': 256},
  ],
  'sprites': [
    sprite('oak', 'mid', 'tree', 9, biomes: ['farm', 'forest'], cell: 0),
    sprite('pine', 'mid', 'tree', 7, biomes: ['forest'], cell: 1),
    sprite('birch', 'mid', 'tree', 6, biomes: ['forest', 'farm'], cell: 2),
    sprite('maple', 'mid', 'tree', 8, biomes: ['forest'], cell: 3),
    sprite('house', 'mid', 'structure', 12, tags: ['house'], cell: 4),
    sprite('shrub', 'near', 'shrub', 2, cell: 5),
    sprite('grass', 'near', 'grass', 1.5, cell: 6),
    sprite(
      'fence',
      'near',
      'furniture',
      3,
      tags: ['fence'],
      biomes: ['farm'],
      cell: 7,
    ),
    sprite(
      'mailbox',
      'near',
      'furniture',
      .6,
      tags: ['mailbox'],
      biomes: ['farm', 'town'],
      cell: 8,
    ),
    sprite('post', 'near', 'furniture', .4, tags: ['post'], cell: 9),
    sprite('barn', 'far', 'structure', 24, tags: ['barn'], cell: 10),
    sprite('silo', 'far', 'structure', 7, tags: ['silo'], cell: 11),
    sprite(
      'cow-a',
      'far',
      'animal',
      2.4,
      tags: ['cattle'],
      frames: ['cow-a', 'cow-b'],
      cell: 12,
    ),
    sprite('cow-b', 'far', 'animal', 2.4, tags: ['cattle'], cell: 13),
    sprite('tree-line', 'far', 'tree', 40, tags: ['tree-line'], cell: 14),
    sprite('ridge', 'vista', 'vista', 3000, tags: ['ridge'], cell: 15),
    sprite('deck-truss', 'near', 'structure', 8, tags: ['bridge'], cell: 3),
    sprite('bridge-covered', 'mid', 'structure', 26, cell: 7),
    sprite('curve-sign', 'near', 'sign', 1, tags: ['curve'], cell: 9),
    // Malformed entries are skipped, not fatal.
    {
      'id': 'bad-rect',
      'atlas': 'fixture',
      'rect': [0, 0],
      'band': 'near',
    },
    {
      'id': 'bad-atlas',
      'atlas': 'missing',
      'rect': [0, 0, 4, 4],
      'band': 'mid',
      'worldWidthM': 2,
    },
  ],
  'textures': [
    {
      'id': 'concrete',
      'file': 'road/concrete.png',
      'kind': 'road',
      'tileM': [6, 6],
    },
  ],
};

Future<ByteData> png(int size) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    ui.Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
    ui.Paint()..color = const ui.Color(0xff68a050),
  );
  final image = await recorder.endRecording().toImage(size, size);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!;
}

class FixtureBundle extends CachingAssetBundle {
  FixtureBundle(this.files);
  final Map<String, ByteData> files;
  @override
  Future<ByteData> load(String key) async =>
      files[key] ?? (throw StateError('missing $key'));
}

ByteData text(String value) =>
    ByteData.sublistView(Uint8List.fromList(utf8.encode(value)));

ScenicManifest fixtureManifest() => ScenicManifest.parse(jsonEncode(fixture));

ScenicPlan plan(String level, {ScenicManifest? manifest}) => ScenicPlan.build(
  manifest: manifest ?? fixtureManifest(),
  scenery: LevelScenery.forId(level),
  seed: 923,
  profile: LevelProfile.forId(level),
  enclosed: (s) => ProofCourse.tunnelAt(s) > 0,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('manifest', () {
    test('parses the design.md contract and skips malformed entries', () {
      final m = fixtureManifest();
      expect(m.version, 'scenic-1');
      expect(m.sprite('bad-rect'), isNull);
      expect(m.sprite('bad-atlas'), isNull);
      expect(m.sprite('oak')!.band, ScenicBand.mid);
      expect(m.sprite('oak')!.anchor, [32, 63]);
      expect(m.texture('concrete')!.tileM, [6, 6]);
      expect(m.framesOf(m.sprite('cow-a')!).map((s) => s.id), [
        'cow-a',
        'cow-b',
      ]);
      expect(() => ScenicManifest.parse('[]'), throwsFormatException);
    });

    test('lookup by kind, tag, band and biome relaxes biome last', () {
      final m = fixtureManifest();
      expect(
        m
            .query(band: ScenicBand.mid, group: 'tree', biomes: ['forest'])
            .map((s) => s.id),
        containsAll(['oak', 'pine', 'birch', 'maple']),
      );
      expect(
        m
            .query(band: ScenicBand.mid, group: 'tree', biomes: ['farm'])
            .map((s) => s.id)
            .toSet(),
        {'oak', 'birch'},
      );
      // No desert trees: the next biome in preference order is used.
      expect(
        m
            .query(
              band: ScenicBand.mid,
              group: 'tree',
              biomes: ['desert', 'farm'],
            )
            .map((s) => s.id)
            .toSet(),
        {'oak', 'birch'},
      );
      expect(m.query(band: ScenicBand.far, group: 'animal/cattle').length, 2);
      expect(
        m.query(band: ScenicBand.far, group: 'structure/barn').single.id,
        'barn',
      );
    });
  });

  group('loader', () {
    test('loads atlases and textures from a bundle', () async {
      final bundle = FixtureBundle({
        'assets/scenic/manifest.json': text(jsonEncode(fixture)),
        'assets/scenic/fixture.png': await png(256),
        'assets/scenic/road/concrete.png': await png(64),
      });
      final library = await ScenicLibrary.load(bundle: bundle);
      expect(library.usingFallback, isFalse);
      expect(library.atlasCount, 1);
      expect(library.atlas('fixture'), isNotNull);
      expect(library.manifest.sprite('oak'), isNotNull);
      expect(library.surface('concrete')!.image.width, 64);
      // Procedural tiles fill surfaces the pack lacks.
      expect(library.hasSurface('bridge-deck'), isTrue);
      library.dispose();
    });

    test('a partial pack is supplemented only where it has no sprite', () {
      final pack = fixtureManifest().sprites;
      final fill = ScenicLibrary.supplement(
        pack,
        ScenicFallback.manifest().sprites,
      );
      final ids = fill.map((s) => s.id).toSet();
      // The fixture has mid/far trees for farm+forest, but no desert palm.
      expect(ids, contains('palm'));
      expect(ids, isNot(contains('oak-line')));
      expect(ids, isNot(contains('shrub')));
      // Tags may also come from id tokens.
      expect(
        ScenicManifest.parse(
          jsonEncode({
            ...fixture,
            'sprites': [sprite('barn-red-gambrel', 'mid', 'structure', 16)],
          }),
        ).sprites.single.matchesGroup('structure/barn'),
        isTrue,
      );
    });

    test('missing manifest falls back to proof art', () async {
      final library = await ScenicLibrary.load(bundle: FixtureBundle({}));
      expect(library.usingFallback, isTrue);
      expect(library.warning, isNull);
      expect(library.manifest.sprites, isNotEmpty);
      expect(
        library.manifest.sprites.every((s) => s.atlas == ScenicFallback.atlas),
        isTrue,
      );
      for (final id in ScenicLibrary.proceduralSurfaces) {
        expect(library.hasSurface(id), isTrue, reason: id);
      }
      library.dispose();
    });

    test('invalid manifest or missing atlas also falls back', () async {
      final broken = await ScenicLibrary.load(
        bundle: FixtureBundle({'assets/scenic/manifest.json': text('{')}),
      );
      expect(broken.usingFallback, isTrue);
      expect(broken.warning, contains('invalid'));
      broken.dispose();
      final noAtlas = await ScenicLibrary.load(
        bundle: FixtureBundle({
          'assets/scenic/manifest.json': text(jsonEncode(fixture)),
        }),
      );
      expect(noAtlas.manifest.version, 'proof-fallback');
      noAtlas.dispose();
    });

    test(
      'the shipped asset path works with or without generated art',
      () async {
        final library = await ScenicLibrary.load();
        expect(library.manifest.sprites, isNotEmpty);
        for (final level in LevelScenery.all) {
          final p = plan(level.id, manifest: library.manifest);
          expect(p.placements(ScenicBand.mid), isNotEmpty, reason: level.id);
        }
        library.dispose();
      },
    );
  });

  group('depth bands', () {
    test(
      'far objects drift far slower than near ones at the same screen x',
      () {
        const projection = .64, half = 500.0, speed = 13540.0; // top speed
        final nearLateral = ScenicScale.widthUnits(5.5 + 3);
        final farLateral = ScenicScale.widthUnits(5.5 + 300);
        // Depth at which each object sits 250 px from the vanishing point.
        final nearDepth = projection * nearLateral * half / 250;
        final farDepth = projection * farLateral * half / 250;
        expect(
          ScenicParallax.screenOffset(nearLateral, nearDepth, projection, half),
          closeTo(250, 1e-9),
        );
        final vNear = ScenicParallax.screenVelocity(
          nearLateral,
          nearDepth,
          speed,
          projection,
          half,
        );
        final vFar = ScenicParallax.screenVelocity(
          farLateral,
          farDepth,
          speed,
          projection,
          half,
        );
        expect(vFar, lessThan(vNear / 30));
        // A farm 300 m out stays on screen for several seconds at top speed.
        var depth = ScenicScale.farAheadCourse * 168, seconds = 0.0;
        while (ScenicParallax.screenOffset(
              farLateral,
              depth,
              projection,
              half,
            ) <
            half) {
          depth -= speed / 60;
          seconds += 1 / 60;
        }
        expect(seconds, greaterThan(8));
      },
    );

    test('vista offset follows heading only, never speed', () {
      expect(ScenicParallax.vistaOffset(0, .64, 500), 0);
      expect(ScenicParallax.vistaOffset(.5, .64, 500), closeTo(-160, 1e-9));
      expect(ScenicScale.lateral(0, 1), 1);
      expect(ScenicScale.lateral(5.5, -1), -2);
    });
  });

  group('scheduler', () {
    test('is deterministic and independent of the query window', () {
      final a = plan('iowa'), b = plan('iowa');
      for (final band in ScenicBand.values) {
        expect(
          a.placements(band).map((p) => (p.s, p.side, p.offsetM, p.sprite.id)),
          b.placements(band).map((p) => (p.s, p.side, p.offsetM, p.sprite.id)),
        );
      }
      final whole = a.between(ScenicBand.mid, 1000, 1400).toList();
      final pieces = [
        ...a.between(ScenicBand.mid, 1000, 1170),
        ...a.between(ScenicBand.mid, 1170, 1400),
      ];
      expect(pieces, whole);
    });

    test('recency excludes back-to-back repeats per side and band', () {
      final p = plan('ohio');
      // The Ohio forest zone offers several tree sprites.
      for (final band in [ScenicBand.mid]) {
        for (final side in [-1, 1]) {
          final ids = [
            for (final x in p.between(band, 950, 3050))
              if (x.side == side && !x.setPiece) x.sprite.id,
          ];
          for (var i = 1; i < ids.length; i++) {
            expect(ids[i], isNot(ids[i - 1]), reason: '$band $side $i');
          }
        }
      }
    });

    test('quiet zones keep only furniture near and nothing mid', () {
      final p = plan('iowa');
      final quiet = LevelScenery.iowa.zones.first;
      expect(quiet.quiet, isTrue);
      final mid = p
          .between(ScenicBand.mid, quiet.start, quiet.end)
          .where((x) => !x.setPiece);
      expect(mid, isEmpty);
      for (final x in p.between(ScenicBand.near, quiet.start, quiet.end)) {
        if (x.setPiece) continue;
        expect(x.sprite.kind, anyOf('furniture', 'sign'));
      }
      // Far layers survive in quiet zones: Iowa opens with a farmstead.
      final far = p.between(ScenicBand.far, 500, 700).map((x) => x.sprite.kind);
      expect(far, containsAll(['structure', 'animal']));
    });

    test('variety and bounded density across all levels', () {
      final m = fixtureManifest();
      for (final level in LevelScenery.all) {
        final p = plan(level.id, manifest: m);
        final ids = {
          for (final band in ScenicBand.values)
            for (final x in p.placements(band)) x.sprite.id,
        };
        expect(ids.length, greaterThan(5), reason: level.id);
        // A mesh-length window (about 335 course units) stays well inside
        // the renderer's sprite budget.
        for (var s = 0.0; s < 7600; s += 100) {
          final count =
              p.between(ScenicBand.near, s, s + 335).length +
              p.between(ScenicBand.mid, s, s + 335).length;
          expect(count, lessThan(72), reason: '${level.id} $s');
          expect(
            p.between(ScenicBand.far, s, s + 1500).length,
            lessThan(100),
            reason: '${level.id} $s',
          );
        }
        // Nothing is scheduled inside the tunnel.
        expect(
          [for (final band in ScenicBand.values) ...p.between(band, 6060, 6810)]
              .where((x) => ProofCourse.tunnelAt(x.s) > 0),
          isEmpty,
        );
        expect(p.zoneVistas.length, level.zones.length);
        expect(p.zoneVistas.every((v) => v.isNotEmpty), isTrue);
      }
    });

    test('hairpins get warning signs and bridges get structures', () {
      final p = plan('ohio');
      final signs = p
          .placements(ScenicBand.near)
          .where((x) => x.sprite.id == 'curve-sign');
      expect(signs.length, greaterThanOrEqualTo(6));
      // Bridge structures are side-on billboards: they stand clear of the
      // deck as neighbouring crossings, never over the carriageway.
      final bridges = [
        for (final band in ScenicBand.values)
          ...p.placements(band).where((x) => x.sprite.hasTag('bridge')),
      ];
      expect(bridges, isNotEmpty);
      expect(bridges.every((x) => p.onBridge(x.s)), isTrue);
      for (final x in bridges) {
        expect(x.offsetM, greaterThan(x.sprite.worldWidthM / 2));
      }
    });

    test('fallback manifest still schedules every level', () {
      final m = ScenicFallback.manifest();
      for (final level in LevelScenery.all) {
        final p = plan(level.id, manifest: m);
        expect(p.placements(ScenicBand.mid), isNotEmpty, reason: level.id);
        expect(p.placements(ScenicBand.far), isNotEmpty, reason: level.id);
      }
    });
  });

  group('road surfaces', () {
    test('zones blend continuously and bridges switch to a deck', () {
      for (final level in LevelScenery.all) {
        final surfaces = RoadSurfaces(level, null);
        for (final track in [
          surfaces.road,
          surfaces.shoulder,
          surfaces.ground,
        ]) {
          final ids = <String>{};
          for (var s = 0.0; s < 9000; s += 1) {
            final a = track.at(s);
            ids.add(a.base);
            if (a.overlay != null) ids.add(a.overlay!);
          }
          for (final id in ids) {
            for (var s = 0.0; s < 9000; s += 1) {
              expect(
                (track.weight(id, s + 1) - track.weight(id, s)).abs(),
                lessThan(.2),
                reason: '${level.id} $id at $s',
              );
            }
          }
        }
        for (final piece in level.setPieces.where(
          (p) => p.kind == SetPiece.bridge,
        )) {
          final mid = (piece.s + piece.end!) / 2;
          expect(surfaces.road.at(mid).base, 'bridge-deck');
          expect(surfaces.ground.at(mid).base, 'water');
          expect(surfaces.shoulderWidthAt(mid), 1.0);
        }
      }
    });

    test('a rural road entering town gains a curbed sidewalk smoothly', () {
      final surfaces = RoadSurfaces(LevelScenery.iowa, null);
      expect(surfaces.curbAt(3800), 0);
      expect(surfaces.curbAt(4500), 1);
      final mid = surfaces.curbAt(4100);
      expect(mid, inExclusiveRange(0, 1));
      expect(
        surfaces.shoulderWidthAt(4100),
        inExclusiveRange(
          RoadSurfaces.shoulderWidth('gravel'),
          RoadSurfaces.shoulderWidth('sidewalk'),
        ),
      );
    });
  });
}
