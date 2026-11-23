import 'dart:math';

class Option {
  final int? id;
  final String text;
  final bool isCorrect;
  const Option({this.id, required this.text, this.isCorrect = false});
}

class Question {
  final int? id;
  final String text;
  final List<Option> options;
  const Question({this.id, required this.text, required this.options});
}

class Exam {
  final int? id;
  final String title;
  final List<Question> questions;
  const Exam({this.id, required this.title, required this.questions});
}

/// Une version figée : questions et propositions déjà dans l'ordre de cette version.
class ExamVersion {
  final int id, examId;
  final String examTitle, code, scoring;
  final double penalty;
  final List<Question> questions;
  const ExamVersion({
    required this.id,
    required this.examId,
    required this.examTitle,
    required this.code,
    required this.scoring,
    required this.penalty,
    required this.questions,
  });

  /// Indices (positions dans cette version) des bonnes propositions de la question q.
  Set<int> correctOf(int q) => {
        for (var i = 0; i < questions[q].options.length; i++)
          if (questions[q].options[i].isCorrect) i
      };

  int get maxOptions => questions.map((q) => q.options.length).reduce(max);
}

String letter(int i) => String.fromCharCode(65 + i);
