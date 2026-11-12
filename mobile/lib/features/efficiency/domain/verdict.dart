/// Ánh xạ verdict trong efficiency/current (contracts/firestore/efficiency.schema.json) sang nhãn hiển thị.
enum Verdict {
  better,
  cheaperNotWorse,
  tradeoff,
  worse,
  noClearDifference,
  insufficient
}

Verdict verdictFromJson(String v) => switch (v) {
      'better' => Verdict.better,
      'cheaper_not_worse' => Verdict.cheaperNotWorse,
      'tradeoff' => Verdict.tradeoff,
      'worse' => Verdict.worse,
      'no_clear_difference' => Verdict.noClearDifference,
      _ => Verdict.insufficient,
    };

extension VerdictLabel on Verdict {
  String get label => switch (this) {
        Verdict.better => 'Better',
        Verdict.cheaperNotWorse => 'Cheaper, no worse',
        Verdict.tradeoff => 'Trade-off',
        Verdict.worse => 'Worse',
        Verdict.noClearDifference => 'No clear difference',
        Verdict.insufficient => 'Not enough data',
      };
}
