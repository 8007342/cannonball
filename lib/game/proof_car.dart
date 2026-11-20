import 'models.dart';

/// Sample-only starter. Production garage/server migration is a separate change.
const proofCar = CarSpec(
  id: 's2000',
  name: 'S2000',
  year: 2001,
  description: 'A little old. A lot to love. Your first set of keys.',
  color: 0xffd74639,
  topSpeed: 155,
  handling: 1.28,
  acceleration: 42,
  unlockHint: 'Your first set of keys.',
);

/// Bonus key card in the garage key box: an original white electric roadster
/// (inspired by recent electric hypercar roadsters; no badges or brand names).
/// Deliberately only a modest step over the starter: different cars are meant
/// to produce different runs on the one shared Top100.
const electricRoadster = CarSpec(
  id: 'electric_roadster',
  name: 'Electric Roadster',
  year: 2026,
  description: 'Silent, white and quick. The key is a card.',
  color: 0xfff3f2ee,
  topSpeed: 162,
  handling: 1.30,
  acceleration: 46,
  unlockHint: 'The key card hangs beside your first keys.',
);

/// Cars selectable in the proof garage, in key-box order.
const proofCars = [proofCar, electricRoadster];

CarSpec proofCarById(String? id) =>
    proofCars.where((car) => car.id == id).firstOrNull ?? proofCar;

/// LocalStore key holding the garage key choice (browser-local, like unlocks).
const proofCarStoreKey = 'cannonball.proof.car';
