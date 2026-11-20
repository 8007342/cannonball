/// Authored scenery along a level's course distance. Zones are review
/// hypotheses for the agent-picked scenic pack, not surveyed geography.
class SetPiece {
  const SetPiece(this.kind, this.s, {this.end, this.side = 1, this.offsetM});
  static const farmstead = 'farmstead',
      grazing = 'grazing',
      waterTower = 'water-tower',
      village = 'village',
      bridge = 'bridge';
  final String kind;
  final double s;
  final double? end, offsetM;
  final int side;
}

class ScenicZone {
  const ScenicZone(
    this.start,
    this.end,
    this.biomes, {
    this.near = 3,
    this.mid = 3,
    this.far = 1,
    this.quiet = false,
    this.road = 'asphalt-worn',
    this.shoulder = 'gravel',
    this.ground,
    this.groups,
    this.setPieces = const [],
  });
  final double start, end;

  /// Preferred biomes, most specific first.
  final List<String> biomes;

  /// Peak placements per 100 course units per side.
  final double near, mid, far;

  /// Road-only stretch: near furniture and far/vista layers remain.
  final bool quiet;
  final String road, shoulder;
  final String? ground;
  final Map<String, double>? groups;
  final List<SetPiece> setPieces;

  String get biome => biomes.first;

  /// Group weights ("kind" or "kind/tag") used when a zone does not override.
  Map<String, double> get weights => groups ?? biomeGroups[biome] ?? _any;

  List<String> get vistaGroups =>
      biomeVista[biome] ?? const ['vista/ridge', 'vista/hills'];

  static const _any = {'tree': 2.0, 'shrub': 1.0, 'structure': .5};

  static const biomeGroups = <String, Map<String, double>>{
    'farm': {
      'crop': 3,
      'tree': 2,
      'shrub': 1,
      'structure/barn': 1,
      'structure/silo': .6,
      'structure/house': 1,
      'animal': 1.5,
      'furniture/fence': 2.5,
      'furniture/mailbox': 1,
    },
    'forest': {'tree': 6, 'shrub': 2, 'grass': 1, 'furniture/post': .6},
    'town': {
      'structure/house': 3,
      'structure/business': 2,
      'tree': 2,
      'furniture/hydrant': 1,
      'furniture/mailbox': 1,
      'furniture/bench': .6,
      'sign': .8,
    },
    'city': {
      'structure/business': 3,
      'structure/building': 3,
      'furniture': 2,
      'tree': 1,
      'sign': 1,
    },
    'river': {'tree': 3, 'shrub': 2, 'grass': 2, 'structure/boathouse': .5},
    'plains': {
      'grass': 3,
      'crop': 2,
      'shrub': 1,
      'furniture/fence': 1.2,
      'structure/windmill': .5,
      'animal': 1,
      'tree': .6,
    },
    'desert': {
      'shrub': 3,
      'grass': 1,
      'tree': 1,
      'structure': .4,
      'sign': .5,
      'furniture/post': .6,
    },
  };

  static const biomeVista = <String, List<String>>{
    'city': ['vista/skyline', 'vista/city'],
    'town': ['vista/hills', 'vista/ridge'],
    'forest': ['vista/ridge', 'vista/hills'],
    'river': ['vista/ridge', 'vista/hills'],
    'farm': ['vista/plains', 'vista/hills'],
    'plains': ['vista/plains', 'vista/hills'],
    'desert': ['vista/mesa', 'vista/mountain', 'vista/ridge'],
  };
}

/// One level's zone list. Zones are contiguous and ordered by start.
class LevelScenery {
  const LevelScenery(this.id, this.zones);
  final String id;
  final List<ScenicZone> zones;

  ScenicZone zoneAt(double s) {
    for (final zone in zones) {
      if (s < zone.end) return zone;
    }
    return zones.last;
  }

  int indexAt(double s) {
    for (var i = 0; i < zones.length; i++) {
      if (s < zones[i].end) return i;
    }
    return zones.length - 1;
  }

  Iterable<SetPiece> get setPieces => zones.expand((z) => z.setPieces);

  static LevelScenery forId(String id) =>
      all.firstWhere((l) => l.id == id, orElse: () => all.first);

  static const all = [hudson, indiana, iowa, ohio, chicago, arizona];

  // Shared chapter boundaries: worksite 4100-5000, canopy 5000-5450,
  // bridge 5450-6050, tunnel 6050-6820.
  static const hudson = LevelScenery('hudson', [
    ScenicZone(
      0,
      600,
      ['town', 'city'],
      road: 'asphalt-fresh',
      shoulder: 'sidewalk',
      near: 7,
      mid: 5,
      far: .6,
    ),
    ScenicZone(
      600,
      2100,
      ['river', 'forest'],
      near: 3,
      mid: 4,
      far: 1.2,
      setPieces: [SetPiece(SetPiece.waterTower, 1500, side: -1, offsetM: 320)],
    ),
    ScenicZone(
      2100,
      3200,
      ['farm', 'plains'],
      shoulder: 'grass',
      near: 3,
      mid: 2,
      far: 1.5,
      setPieces: [
        SetPiece(SetPiece.farmstead, 2500, side: -1, offsetM: 170),
        SetPiece(SetPiece.grazing, 2900, side: 1, offsetM: 140),
      ],
    ),
    ScenicZone(3200, 4100, ['forest'], quiet: true, near: 2, mid: 1.5),
    ScenicZone(
      4100,
      5000,
      ['town'],
      road: 'concrete',
      shoulder: 'sidewalk',
      near: 5,
      mid: 4,
    ),
    ScenicZone(5000, 5450, ['forest'], near: 2, mid: 3),
    ScenicZone(
      5450,
      6050,
      ['river'],
      near: 2,
      mid: 2,
      setPieces: [SetPiece(SetPiece.bridge, 5460, end: 5640)],
    ),
    ScenicZone(6050, 6820, ['forest'], quiet: true),
    ScenicZone(
      6820,
      9000,
      ['town', 'city'],
      road: 'brick',
      shoulder: 'sidewalk',
      near: 6,
      mid: 5,
    ),
  ]);

  static const indiana = LevelScenery('indiana', [
    ScenicZone(
      0,
      700,
      ['farm'],
      shoulder: 'grass',
      near: 3,
      mid: 3,
      far: 1.5,
      setPieces: [SetPiece(SetPiece.farmstead, 450, side: 1, offsetM: 160)],
    ),
    ScenicZone(700, 2200, ['forest', 'farm'], near: 3, mid: 4),
    ScenicZone(
      2200,
      3400,
      ['farm', 'plains'],
      shoulder: 'grass',
      ground: 'crop-rows',
      near: 2,
      mid: 2,
      far: 2,
      setPieces: [
        SetPiece(SetPiece.farmstead, 2700, side: -1, offsetM: 190),
        SetPiece(SetPiece.grazing, 3100, side: 1, offsetM: 120),
      ],
    ),
    ScenicZone(3400, 4100, ['forest'], near: 3, mid: 4),
    ScenicZone(
      4100,
      5000,
      ['town'],
      road: 'concrete',
      shoulder: 'sidewalk',
      near: 5,
      mid: 4,
    ),
    ScenicZone(5000, 5450, ['forest']),
    ScenicZone(
      5450,
      6050,
      ['river'],
      setPieces: [SetPiece(SetPiece.bridge, 5720, end: 5960)],
    ),
    ScenicZone(6050, 6820, ['forest'], quiet: true),
    ScenicZone(
      6820,
      9000,
      ['farm'],
      shoulder: 'grass',
      far: 1.6,
      setPieces: [SetPiece(SetPiece.farmstead, 7100, side: 1, offsetM: 210)],
    ),
  ]);

  static const iowa = LevelScenery('iowa', [
    ScenicZone(
      0,
      1600,
      ['plains', 'farm'],
      quiet: true,
      near: 1.5,
      mid: .8,
      far: 1.6,
      setPieces: [
        SetPiece(SetPiece.farmstead, 600, side: -1, offsetM: 150),
        SetPiece(SetPiece.grazing, 1100, side: 1, offsetM: 110),
        SetPiece(SetPiece.waterTower, 1400, side: 1, offsetM: 400),
      ],
    ),
    ScenicZone(
      1600,
      3400,
      ['farm', 'plains'],
      road: 'concrete',
      shoulder: 'grass',
      ground: 'crop-rows',
      near: 2.5,
      mid: 1.5,
      far: 2,
      setPieces: [
        SetPiece(SetPiece.farmstead, 2200, side: 1, offsetM: 160),
        SetPiece(SetPiece.grazing, 2650, side: -1, offsetM: 90),
        SetPiece(SetPiece.farmstead, 3100, side: -1, offsetM: 260),
      ],
    ),
    ScenicZone(3400, 4100, ['plains'], quiet: true, near: 1, mid: .5),
    ScenicZone(
      4100,
      5000,
      ['town', 'farm'],
      road: 'concrete',
      shoulder: 'sidewalk',
      near: 4,
      mid: 3,
      setPieces: [SetPiece(SetPiece.village, 4500, side: -1)],
    ),
    ScenicZone(
      5000,
      5450,
      ['farm'],
      near: 2,
      mid: 1.5,
      far: 2,
      setPieces: [SetPiece(SetPiece.grazing, 5200, side: -1, offsetM: 100)],
    ),
    ScenicZone(
      5450,
      6050,
      ['river'],
      setPieces: [SetPiece(SetPiece.bridge, 5720, end: 5960)],
    ),
    ScenicZone(6050, 6820, ['plains'], quiet: true),
    ScenicZone(
      6820,
      9000,
      ['farm', 'plains'],
      quiet: true,
      far: 2,
      setPieces: [SetPiece(SetPiece.farmstead, 7200, side: 1, offsetM: 170)],
    ),
  ]);

  static const ohio = LevelScenery('ohio', [
    ScenicZone(0, 950, ['forest', 'farm'], near: 3, mid: 4),
    ScenicZone(950, 3050, ['forest'], near: 3, mid: 5, far: .6),
    ScenicZone(
      3050,
      4100,
      ['forest', 'farm'],
      near: 2,
      mid: 3,
      far: 1.4,
      setPieces: [SetPiece(SetPiece.farmstead, 3600, side: 1, offsetM: 160)],
    ),
    ScenicZone(
      4100,
      5000,
      ['town'],
      road: 'concrete',
      shoulder: 'sidewalk',
      near: 5,
      mid: 4,
    ),
    ScenicZone(5000, 5450, ['forest']),
    ScenicZone(
      5450,
      6050,
      ['river'],
      setPieces: [SetPiece(SetPiece.bridge, 5720, end: 5960)],
    ),
    ScenicZone(6050, 6820, ['forest'], quiet: true),
    ScenicZone(6820, 9000, ['forest'], near: 3, mid: 4),
  ]);

  static const chicago = LevelScenery('chicago', [
    ScenicZone(
      0,
      2500,
      ['city', 'town'],
      road: 'asphalt-fresh',
      shoulder: 'sidewalk',
      near: 6,
      mid: 6,
      far: .5,
    ),
    ScenicZone(
      2500,
      3000,
      ['city'],
      quiet: true,
      road: 'concrete',
      shoulder: 'sidewalk',
    ),
    ScenicZone(
      3000,
      4100,
      ['city', 'town'],
      road: 'asphalt-fresh',
      shoulder: 'sidewalk',
      near: 6,
      mid: 6,
      far: .5,
    ),
    ScenicZone(
      4100,
      5000,
      ['city'],
      road: 'concrete',
      shoulder: 'sidewalk',
      near: 5,
      mid: 5,
    ),
    ScenicZone(
      5000,
      5450,
      ['town'],
      road: 'brick',
      shoulder: 'sidewalk',
      near: 5,
      mid: 4,
    ),
    ScenicZone(
      5450,
      6050,
      ['river', 'city'],
      road: 'asphalt-fresh',
      shoulder: 'sidewalk',
      setPieces: [SetPiece(SetPiece.bridge, 5720, end: 5960)],
    ),
    ScenicZone(6050, 6820, ['city'], quiet: true, shoulder: 'sidewalk'),
    ScenicZone(
      6820,
      9000,
      ['city'],
      road: 'asphalt-fresh',
      shoulder: 'sidewalk',
      near: 6,
      mid: 6,
    ),
  ]);

  // No sand texture is packed: the red dirt shoulder tile is the desert
  // floor (the green meadow tinted tan read as lawn in the Sonoran desert).
  static const arizona = LevelScenery('arizona', [
    ScenicZone(
      0,
      1000,
      ['desert', 'plains'],
      ground: 'dirt-shoulder',
      quiet: true,
      near: 2,
      mid: 1,
    ),
    ScenicZone(
      1000,
      2400,
      ['desert', 'plains'],
      ground: 'dirt-shoulder',
      near: 2.5,
      mid: 1.5,
      far: 1.2,
    ),
    ScenicZone(
      2400,
      4100,
      ['desert'],
      ground: 'dirt-shoulder',
      quiet: true,
      near: 1.5,
      mid: .8,
      setPieces: [SetPiece(SetPiece.grazing, 3700, side: -1, offsetM: 150)],
    ),
    ScenicZone(
      4100,
      5000,
      ['town', 'desert'],
      ground: 'dirt-shoulder',
      road: 'concrete',
      near: 4,
      mid: 3,
      setPieces: [SetPiece(SetPiece.waterTower, 4600, side: 1, offsetM: 190)],
    ),
    ScenicZone(5000, 5450, ['desert'], ground: 'dirt-shoulder'),
    ScenicZone(
      5450,
      6050,
      ['river', 'desert'],
      ground: 'dirt-shoulder',
      setPieces: [SetPiece(SetPiece.bridge, 5720, end: 5960)],
    ),
    ScenicZone(6050, 6820, ['desert'], ground: 'dirt-shoulder', quiet: true),
    ScenicZone(
      6820,
      9000,
      ['desert'],
      ground: 'dirt-shoulder',
      near: 2,
      mid: 1,
    ),
  ]);
}
