import 'dart:math';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/models.dart';

const _schema = [
  '''CREATE TABLE exams(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL, created_at TEXT NOT NULL)''',
  '''CREATE TABLE questions(id INTEGER PRIMARY KEY AUTOINCREMENT,
     exam_id INTEGER NOT NULL REFERENCES exams(id) ON DELETE CASCADE,
     text TEXT NOT NULL, position INTEGER NOT NULL)''',
  '''CREATE TABLE options(id INTEGER PRIMARY KEY AUTOINCREMENT,
     question_id INTEGER NOT NULL REFERENCES questions(id) ON DELETE CASCADE,
     text TEXT NOT NULL, is_correct INTEGER NOT NULL, position INTEGER NOT NULL)''',
  '''CREATE TABLE versions(id INTEGER PRIMARY KEY AUTOINCREMENT,
     exam_id INTEGER NOT NULL REFERENCES exams(id) ON DELETE CASCADE,
     code TEXT NOT NULL, scoring TEXT NOT NULL, penalty REAL NOT NULL, created_at TEXT NOT NULL)''',
  '''CREATE TABLE version_questions(id INTEGER PRIMARY KEY AUTOINCREMENT,
     version_id INTEGER NOT NULL REFERENCES versions(id) ON DELETE CASCADE,
     question_id INTEGER NOT NULL REFERENCES questions(id) ON DELETE CASCADE,
     position INTEGER NOT NULL)''',
  '''CREATE TABLE version_options(id INTEGER PRIMARY KEY AUTOINCREMENT,
     version_question_id INTEGER NOT NULL REFERENCES version_questions(id) ON DELETE CASCADE,
     option_id INTEGER NOT NULL REFERENCES options(id) ON DELETE CASCADE,
     position INTEGER NOT NULL)''',
  '''CREATE TABLE results(id INTEGER PRIMARY KEY AUTOINCREMENT,
     last_name TEXT NOT NULL, first_name TEXT NOT NULL,
     exam_id INTEGER NOT NULL, version_id INTEGER NOT NULL REFERENCES versions(id) ON DELETE CASCADE,
     exam_title TEXT NOT NULL, version_code TEXT NOT NULL,
     date TEXT NOT NULL, score REAL NOT NULL, answers TEXT NOT NULL, image_path TEXT)''',
];

class AppDb {
  AppDb._();
  static final instance = AppDb._();
  Database? _db;
  Future<Database> get db async => _db ??= await _open();

  Future<Database> _open() async {
    try {
      final path = join(await getDatabasesPath(), 'qcm.db');

      print('DATABASE PATH: $path');

      final database = await openDatabase(
        path,
        version: 1,
        onConfigure: (d) async {
          await d.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (d, _) async {
          for (final s in _schema) {
            await d.execute(s);
          }
        },
      );

      print('DATABASE OPENED SUCCESSFULLY');

      return database;
    } catch (e, stackTrace) {
      print('DATABASE ERROR: $e');
      print('STACK TRACE: $stackTrace');
      rethrow;
    }
  }

  // ---------- Examens ----------
  Future<List<Map<String, Object?>>> listExams() async =>
      (await db).rawQuery('''
    SELECT e.id, e.title,
      (SELECT COUNT(*) FROM questions WHERE exam_id = e.id) AS nq,
      (SELECT COUNT(*) FROM versions WHERE exam_id = e.id) AS nv
    FROM exams e ORDER BY e.id DESC''');

  /// Si l'examen existe déjà, ses versions et résultats sont supprimés (les questions changent).
  Future<int> saveExam(Exam e) async {
    final d = await db;
    return d.transaction((t) async {
      int id;
      if (e.id == null) {
        id = await t.insert('exams', {
          'title': e.title,
          'created_at': DateTime.now().toIso8601String(),
        });
      } else {
        id = e.id!;
        await t.update(
          'exams',
          {'title': e.title},
          where: 'id=?',
          whereArgs: [id],
        );
        await t.delete('versions', where: 'exam_id=?', whereArgs: [id]);
        await t.delete('questions', where: 'exam_id=?', whereArgs: [id]);
      }
      for (var i = 0; i < e.questions.length; i++) {
        final q = e.questions[i];
        final qid = await t.insert('questions', {
          'exam_id': id,
          'text': q.text,
          'position': i,
        });
        for (var j = 0; j < q.options.length; j++) {
          await t.insert('options', {
            'question_id': qid,
            'text': q.options[j].text,
            'is_correct': q.options[j].isCorrect ? 1 : 0,
            'position': j,
          });
        }
      }
      return id;
    });
  }

  Future<Exam> loadExam(int id) async {
    final d = await db;
    final e = (await d.query('exams', where: 'id=?', whereArgs: [id])).first;
    final qs = await d.query(
      'questions',
      where: 'exam_id=?',
      whereArgs: [id],
      orderBy: 'position',
    );
    final questions = <Question>[];
    for (final q in qs) {
      final os = await d.query(
        'options',
        where: 'question_id=?',
        whereArgs: [q['id']],
        orderBy: 'position',
      );
      questions.add(
        Question(
          id: q['id'] as int,
          text: q['text'] as String,
          options: [
            for (final o in os)
              Option(
                id: o['id'] as int,
                text: o['text'] as String,
                isCorrect: o['is_correct'] == 1,
              ),
          ],
        ),
      );
    }
    return Exam(id: id, title: e['title'] as String, questions: questions);
  }

  Future<void> deleteExam(int id) async =>
      (await db).delete('exams', where: 'id=?', whereArgs: [id]);

  // ---------- Versions ----------
  Future<int> versionCount(int examId) async =>
      Sqflite.firstIntValue(
        await (await db).rawQuery(
          'SELECT COUNT(*) FROM versions WHERE exam_id=?',
          [examId],
        ),
      ) ??
      0;

  Future<List<Map<String, Object?>>> listVersions(int examId) async =>
      (await db).query(
        'versions',
        where: 'exam_id=?',
        whereArgs: [examId],
        orderBy: 'code',
      );

  Future<void> deleteVersion(int id) async =>
      (await db).delete('versions', where: 'id=?', whereArgs: [id]);

  Future<void> createVersions({
    required int examId,
    required int count,
    required bool shuffleQuestions,
    required bool shuffleOptions,
    required String scoring,
    required double penalty,
  }) async {
    final exam = await loadExam(examId);
    final existing = await versionCount(examId);
    if (existing + count > 26) throw Exception('Maximum 26 versions (A à Z)');
    final rnd = Random();
    final d = await db;
    await d.transaction((t) async {
      for (var v = 0; v < count; v++) {
        final vid = await t.insert('versions', {
          'exam_id': examId,
          'code': String.fromCharCode(65 + existing + v),
          'scoring': scoring,
          'penalty': penalty,
          'created_at': DateTime.now().toIso8601String(),
        });
        final qs = [...exam.questions];
        if (shuffleQuestions) qs.shuffle(rnd);
        for (var i = 0; i < qs.length; i++) {
          final vq = await t.insert('version_questions', {
            'version_id': vid,
            'question_id': qs[i].id,
            'position': i,
          });
          final os = [...qs[i].options];
          if (shuffleOptions) os.shuffle(rnd);
          for (var j = 0; j < os.length; j++) {
            await t.insert('version_options', {
              'version_question_id': vq,
              'option_id': os[j].id,
              'position': j,
            });
          }
        }
      }
    });
  }

  Future<ExamVersion> loadVersion(int vid) async {
    final d = await db;
    final v = (await d.query(
      'versions',
      where: 'id=?',
      whereArgs: [vid],
    )).first;
    final exam = (await d.query(
      'exams',
      where: 'id=?',
      whereArgs: [v['exam_id']],
    )).first;
    final vqs = await d.rawQuery(
      '''SELECT vq.id AS vqid, q.text AS text FROM version_questions vq
      JOIN questions q ON q.id = vq.question_id WHERE vq.version_id=? ORDER BY vq.position''',
      [vid],
    );
    final qs = <Question>[];
    for (final r in vqs) {
      final os = await d.rawQuery(
        '''SELECT o.text AS text, o.is_correct AS c FROM version_options vo
        JOIN options o ON o.id = vo.option_id WHERE vo.version_question_id=? ORDER BY vo.position''',
        [r['vqid']],
      );
      qs.add(
        Question(
          text: r['text'] as String,
          options: [
            for (final o in os)
              Option(text: o['text'] as String, isCorrect: o['c'] == 1),
          ],
        ),
      );
    }
    return ExamVersion(
      id: vid,
      examId: v['exam_id'] as int,
      examTitle: exam['title'] as String,
      code: v['code'] as String,
      scoring: v['scoring'] as String,
      penalty: (v['penalty'] as num).toDouble(),
      questions: qs,
    );
  }

  // ---------- Résultats ----------
  Future<void> saveResult(Map<String, Object?> r) async {
    await (await db).insert('results', r);
  }

  Future<List<Map<String, Object?>>> searchResults(String q) async =>
      (await db).query(
        'results',
        where: q.isEmpty ? null : 'last_name LIKE ? OR first_name LIKE ?',
        whereArgs: q.isEmpty ? null : ['%$q%', '%$q%'],
        orderBy: 'id DESC',
      );

  /// Supprime le résultat et renvoie le chemin de l'image associée (à effacer par l'appelant).
  Future<String?> deleteResult(int id) async {
    final d = await db;
    final r = await d.query(
      'results',
      columns: ['image_path'],
      where: 'id=?',
      whereArgs: [id],
    );
    await d.delete('results', where: 'id=?', whereArgs: [id]);
    return r.isEmpty ? null : r.first['image_path'] as String?;
  }
}
