import 'dart:math';
import '../models/models.dart';

const scoringLabels = {
  'strict': 'Strict',
  'proportional': 'Proportionnelle',
  'penalty': 'Avec pénalité',
  'all_or_nothing': 'Tous ou rien',
};

/// Fraction (0..1) des points obtenue pour une question.
/// - all_or_nothing : 1 seulement si la sélection est exactement la bonne.
/// - strict         : 0 dès qu'une mauvaise case est cochée, sinon bonnes cochées / bonnes attendues.
/// - proportional   : propositions bien traitées (bonne cochée ou fausse laissée vide) / nb propositions.
/// - penalty        : (bonnes - pénalité x mauvaises) / bonnes attendues, minimum 0.
double questionFraction(String type, Set<int> correct, Set<int> chosen, int nOpts, double penalty) {
  if (correct.isEmpty) return chosen.isEmpty ? 1.0 : 0.0;
  final good = chosen.intersection(correct).length;
  final bad = chosen.length - good;
  switch (type) {
    case 'all_or_nothing':
      return (bad == 0 && good == correct.length) ? 1.0 : 0.0;
    case 'strict':
      return bad > 0 ? 0.0 : good / correct.length;
    case 'proportional':
      final wrongOpts = nOpts - correct.length;
      return (good + (wrongOpts - bad)) / nOpts;
    case 'penalty':
      return max(0.0, (good - penalty * bad) / correct.length);
  }
  return 0.0;
}

/// Note sur 20 : toutes les questions ont le même poids.
double totalScore(ExamVersion v, Map<int, Set<int>> answers) {
  if (v.questions.isEmpty) return 0;
  var sum = 0.0;
  for (var q = 0; q < v.questions.length; q++) {
    sum += questionFraction(v.scoring, v.correctOf(q), answers[q] ?? <int>{}, v.questions[q].options.length, v.penalty);
  }
  return sum / v.questions.length * 20;
}
