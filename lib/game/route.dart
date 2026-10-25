import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// Corridor-level geography, researched 2026-10-25. Approximate distances and
/// schematic junctions are NOT a verified turn-by-turn production route atlas.
/// Sources and outstanding exact-junction/landmark review: docs/research/design.md.
enum Biome { city, forest, prairie, mountain, canyon, desert, coast }

enum RaceWeather { clear, rain, snow, sunset }

@immutable
class RouteNode {
  const RouteNode(this.id, this.name, this.lat, this.lon);
  final String id, name;
  final double lat, lon;
}

@immutable
class RouteEdge {
  const RouteEdge(
    this.id,
    this.from,
    this.to,
    this.road,
    this.miles,
    this.biome,
    this.landmark, {
    this.secretUnlockId,
  });
  final String id, from, to, road, landmark;
  final double miles;
  final Biome biome;
  final String? secretUnlockId;
  double get length => miles * RouteGraph.unitsPerMile;
  bool get secret => secretUnlockId != null;
}

class RouteGraph {
  const RouteGraph();
  static const double unitsPerMile = 18;
  static const double speedScale = .52;
  final nodes = const <RouteNode>[
    RouteNode('ny', 'Red Ball Garage · New York', 40.745, -73.973),
    RouteNode('poconos', 'Pocono Mountains', 41.00, -75.20),
    RouteNode('youngstown', 'Youngstown', 41.10, -80.65),
    RouteNode('chicago', 'Chicago', 41.88, -87.63),
    RouteNode('columbus', 'Columbus', 39.96, -83.00),
    RouteNode('st-louis', 'St. Louis', 38.63, -90.20),
    RouteNode('omaha', 'Omaha', 41.26, -95.94),
    RouteNode('big-springs', 'Big Springs', 41.06, -102.07),
    RouteNode('denver', 'Denver', 39.74, -104.99),
    RouteNode('grand-junction', 'Grand Junction', 39.06, -108.55),
    RouteNode('salina', 'Salina · Utah', 38.96, -111.86),
    RouteNode('las-vegas', 'Las Vegas', 36.17, -115.14),
    RouteNode('oklahoma', 'Oklahoma City', 35.47, -97.52),
    RouteNode('amarillo', 'Amarillo', 35.22, -101.83),
    RouteNode('albuquerque', 'Albuquerque', 35.08, -106.65),
    RouteNode('flagstaff', 'Flagstaff', 35.20, -111.65),
    RouteNode('barstow', 'Barstow', 34.90, -117.02),
    RouteNode('san-bernardino', 'San Bernardino', 34.11, -117.29),
    RouteNode('redondo', 'The Portofino · Redondo Beach', 33.85, -118.40),
  ];
  final edges = const <RouteEdge>[
    RouteEdge(
      'hudson',
      'ny',
      'poconos',
      'Manhattan / I-80',
      90,
      Biome.city,
      'Hudson River',
    ),
    RouteEdge(
      'keystone',
      'poconos',
      'youngstown',
      'I-80 · Pennsylvania',
      330,
      Biome.forest,
      'Delaware Water Gap',
    ),
    RouteEdge(
      'allegheny',
      'poconos',
      'youngstown',
      'US-6 / I-79 / I-80',
      410,
      Biome.forest,
      'Allegheny backroads',
      secretUnlockId: 'coupe',
    ),
    RouteEdge(
      'great-lakes',
      'youngstown',
      'chicago',
      'I-80 / I-90',
      455,
      Biome.forest,
      'Great Lakes country',
    ),
    RouteEdge(
      'buckeye',
      'youngstown',
      'columbus',
      'I-76 / I-71',
      180,
      Biome.prairie,
      'Ohio heartland',
    ),
    RouteEdge(
      'heartland',
      'columbus',
      'st-louis',
      'I-70 · Indianapolis',
      420,
      Biome.prairie,
      'Gateway Arch',
    ),
    RouteEdge(
      'illinois',
      'chicago',
      'st-louis',
      'I-55',
      300,
      Biome.prairie,
      'Illinois farm country',
    ),
    RouteEdge(
      'prairie',
      'chicago',
      'omaha',
      'I-80 · Iowa',
      470,
      Biome.prairie,
      'Missouri River',
    ),
    RouteEdge(
      'nebraska',
      'omaha',
      'big-springs',
      'I-80 · Nebraska',
      355,
      Biome.prairie,
      'Platte River valley',
    ),
    RouteEdge(
      'plains-backroad',
      'omaha',
      'denver',
      'US-6 / US-34 / I-25',
      560,
      Biome.prairie,
      'High Plains farm roads',
      secretUnlockId: 'rally',
    ),
    RouteEdge(
      'front-range',
      'big-springs',
      'denver',
      'I-76 · Colorado',
      195,
      Biome.prairie,
      'Front Range',
    ),
    RouteEdge(
      'rockies',
      'denver',
      'grand-junction',
      'I-70 · Colorado',
      245,
      Biome.mountain,
      'Glenwood Canyon',
    ),
    RouteEdge(
      'monarch-pass',
      'denver',
      'grand-junction',
      'US-285 / US-50',
      320,
      Biome.mountain,
      'Monarch Pass',
      secretUnlockId: 'muscle',
    ),
    RouteEdge(
      'canyonlands',
      'grand-junction',
      'salina',
      'I-70 · Utah',
      250,
      Biome.canyon,
      'San Rafael Swell',
    ),
    RouteEdge(
      'high-desert',
      'salina',
      'las-vegas',
      'I-70 / I-15',
      290,
      Biome.desert,
      'Virgin River Gorge',
    ),
    RouteEdge(
      'ozarks',
      'st-louis',
      'oklahoma',
      'I-44 · Tulsa',
      500,
      Biome.forest,
      'Ozark hills',
    ),
    RouteEdge(
      'red-earth',
      'oklahoma',
      'amarillo',
      'I-40',
      260,
      Biome.prairie,
      'Red earth country',
    ),
    RouteEdge(
      'panhandle',
      'amarillo',
      'albuquerque',
      'I-40 · New Mexico',
      285,
      Biome.desert,
      'Sandia Mountains',
    ),
    RouteEdge(
      'mesa',
      'albuquerque',
      'flagstaff',
      'I-40 · Arizona',
      325,
      Biome.canyon,
      'Painted Desert',
    ),
    RouteEdge(
      'mojave',
      'flagstaff',
      'barstow',
      'I-40 · Mojave',
      355,
      Biome.desert,
      'Mojave Desert',
    ),
    RouteEdge(
      'route66',
      'flagstaff',
      'barstow',
      'Historic US-66 / I-40',
      390,
      Biome.desert,
      'Seligman · the old road',
      secretUnlockId: 'grandtourer',
    ),
    RouteEdge(
      'neon-desert',
      'las-vegas',
      'barstow',
      'I-15 · Mojave',
      155,
      Biome.desert,
      'Mojave Joshua trees',
    ),
    RouteEdge(
      'cajon',
      'barstow',
      'san-bernardino',
      'I-15 · Cajon Pass',
      75,
      Biome.mountain,
      'Cajon Pass',
    ),
    RouteEdge(
      'pacific',
      'san-bernardino',
      'redondo',
      'I-210 / I-605 / I-105 / I-405',
      85,
      Biome.coast,
      'Pacific Coast · Portofino',
    ),
  ];
  RouteNode node(String id) => nodes.firstWhere((e) => e.id == id);
  RouteEdge edge(String id) => edges.firstWhere((e) => e.id == id);
  List<RouteEdge> outgoing(String id) =>
      edges.where((e) => e.from == id).toList();
  double remainingMiles(String nodeId) {
    final choices = outgoing(nodeId);
    if (choices.isEmpty) return 0;
    return choices.map((e) => e.miles + remainingMiles(e.to)).reduce(math.min);
  }
}

const routeGraph = RouteGraph();
