/// Authored encounter rhythm, independent of car speed and collision rules.
/// Inspired by Valve's pressure/release distinction and Demon Attack's bounded
/// encounter budgets. These distances/counts are local tuning hypotheses.
class ProofEncounterBudget {
  const ProofEncounterBudget(this.phase, this.interval, this.capacity);
  final String phase;
  final double interval;
  final int capacity;

  static ProofEncounterBudget at(double distance) {
    final beat = distance % 1100;
    if (beat < 240) return const ProofEncounterBudget('release', 1.8, 12);
    if (beat < 560) return const ProofEncounterBudget('build', 1.0, 18);
    if (beat < 850) return const ProofEncounterBudget('overtake', .7, 22);
    return const ProofEncounterBudget('release', 1.8, 12);
  }
}
