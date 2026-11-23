import 'dart:convert';
import '../models/models.dart';
import 'grid_layout.dart';

/// Format attendu :
/// {"title":"...","questions":[{"text":"...","options":[{"text":"...","correct":true}, ...]}]}
class JsonImport {
  static Exam parse(String source) {
    dynamic data;
    try {
      data = jsonDecode(source);
    } on FormatException {
      throw FormatException('fichier JSON mal formé');
    }
    if (data is! Map) throw FormatException('objet racine attendu');
    final title = (data['title'] ?? '').toString().trim();
    if (title.isEmpty) throw FormatException('titre manquant');
    final qs = data['questions'];
    if (qs is! List || qs.isEmpty) throw FormatException('liste "questions" manquante ou vide');
    if (qs.length > GridLayout.maxQuestions) {
      throw FormatException('maximum ${GridLayout.maxQuestions} questions');
    }
    final questions = <Question>[];
    for (var i = 0; i < qs.length; i++) {
      final q = qs[i];
      if (q is! Map) throw FormatException('question ${i + 1} invalide');
      final text = (q['text'] ?? '').toString().trim();
      if (text.isEmpty) throw FormatException('question ${i + 1} : énoncé vide');
      final os = q['options'];
      if (os is! List || os.length < 2 || os.length > 5) {
        throw FormatException('question ${i + 1} : 2 à 5 propositions attendues');
      }
      final options = <Option>[];
      for (final o in os) {
        final t = (o is Map ? (o['text'] ?? '') : '').toString().trim();
        if (t.isEmpty) throw FormatException('question ${i + 1} : proposition vide');
        options.add(Option(text: t, isCorrect: (o as Map)['correct'] == true));
      }
      if (!options.any((o) => o.isCorrect)) throw FormatException('question ${i + 1} : aucune bonne réponse');
      questions.add(Question(text: text, options: options));
    }
    return Exam(title: title, questions: questions);
  }
}
