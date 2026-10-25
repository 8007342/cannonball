import 'package:flutter/foundation.dart';

/// Original working vehicle designs, except the specifically requested final car.
@immutable
class CarSpec {
  const CarSpec({
    required this.id,
    required this.name,
    required this.year,
    required this.description,
    required this.color,
    required this.topSpeed,
    required this.handling,
    required this.acceleration,
    required this.unlockHint,
  });
  final String id, name, description, unlockHint;
  final int year, color;
  final double topSpeed, handling, acceleration;
}

const cars = <CarSpec>[
  CarSpec(
    id: 'wagon',
    name: 'Hand-me-down Wagon',
    year: 1987,
    description: 'Faded paint. A lucky keychain. A whole country ahead.',
    color: 0xffdbad59,
    topSpeed: 136,
    handling: 1,
    acceleration: 22,
    unlockHint: 'Your first set of keys.',
  ),
  CarSpec(
    id: 'coupe',
    name: 'Allegheny Coupe',
    year: 1991,
    description: 'Light on its feet, with a little more to give.',
    color: 0xffe56b58,
    topSpeed: 145,
    handling: 1.13,
    acceleration: 25,
    unlockHint: 'Take the old Allegheny road through Pennsylvania.',
  ),
  CarSpec(
    id: 'rally',
    name: 'Prairie Rally',
    year: 1998,
    description: 'Sure-footed through rain and high-country snow.',
    color: 0xff7fb5c2,
    topSpeed: 149,
    handling: 1.29,
    acceleration: 28,
    unlockHint: 'Follow the farm-road radio clue west of Omaha.',
  ),
  CarSpec(
    id: 'muscle',
    name: 'Monarch V8',
    year: 1970,
    description: 'A mountain of torque. A very long hood.',
    color: 0xffad7eaf,
    topSpeed: 157,
    handling: 1.06,
    acceleration: 31,
    unlockHint: 'Find the longer way over Monarch Pass.',
  ),
  CarSpec(
    id: 'grandtourer',
    name: 'Route 66 GT',
    year: 2004,
    description: 'Long-legged, low-slung, and made for the sunset.',
    color: 0xff69a68c,
    topSpeed: 163,
    handling: 1.21,
    acceleration: 34,
    unlockHint: 'The old road out of Flagstaff still has a few secrets.',
  ),
  CarSpec(
    id: 'corvette',
    name: 'Corvette Stingray Coupe',
    year: 2019,
    description: 'White paint. Targa panel off. Your coast-to-coast reward.',
    color: 0xfff7f3e9,
    topSpeed: 170,
    handling: 1.35,
    acceleration: 38,
    unlockHint: 'Collect every other key, then finish at the Pacific.',
  ),
];

@immutable
class RouteVisit {
  const RouteVisit(this.edgeId, this.fraction);
  final String edgeId;
  final double fraction;
  Map<String, Object> toJson() => {'edgeId': edgeId, 'fraction': fraction};
}

/// Immutable local record. Server acceptance is a separate operation.
@immutable
class RunReceipt {
  RunReceipt({
    required this.seed,
    required this.carId,
    required this.elapsedMs,
    required this.distanceMiles,
    required this.completed,
    required List<RouteVisit> route,
    required List<String> gates,
    required this.crashes,
    required Set<String> earnedUnlockIds,
  }) : route = List.unmodifiable(route),
       gates = List.unmodifiable(gates),
       earnedUnlockIds = Set.unmodifiable(earnedUnlockIds);
  static const rulesetVersion = 'cannonball-1';
  static const contentVersion = 'us-corridors-1';
  final int seed, elapsedMs, crashes;
  final String carId;
  final double distanceMiles;
  final bool completed;
  final List<RouteVisit> route;
  final List<String> gates;
  final Set<String> earnedUnlockIds;
  Map<String, Object> toJson() => {
    'rulesetVersion': rulesetVersion,
    'contentVersion': contentVersion,
    'seed': seed,
    'carId': carId,
    'elapsedMs': elapsedMs,
    'distanceMiles': distanceMiles,
    'completed': completed,
    'route': route.map((e) => e.toJson()).toList(),
    'gates': gates,
    'crashes': crashes,
    'earnedUnlockIds': earnedUnlockIds.toList()..sort(),
  };
}
