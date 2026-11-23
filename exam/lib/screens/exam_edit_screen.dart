import 'package:flutter/material.dart';

import '../db/app_db.dart';
import '../models/models.dart';
import '../services/grid_layout.dart';

class _OptD {
  final text = TextEditingController();
  bool correct;

  _OptD({String t = '', this.correct = false}) {
    text.text = t;
  }
}

class _QD {
  final text = TextEditingController();
  final List<_OptD> opts;

  _QD({String t = '', required this.opts}) {
    text.text = t;
  }
}

class ExamEditScreen extends StatefulWidget {
  final int? examId;

  const ExamEditScreen({super.key, this.examId});

  @override
  State<ExamEditScreen> createState() => _ExamEditScreenState();
}

class _ExamEditScreenState extends State<ExamEditScreen> {
  static const Color primary = Color(0xFF0D9488);
  static const Color bg = Color(0xFFF5F7FA);

  final _title = TextEditingController();
  final List<_QD> _qs = [];

  bool _hasVersions = false, _loading = true, _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  _QD _blank() => _QD(opts: [for (var i = 0; i < 4; i++) _OptD()]);

  Future<void> _load() async {
    if (widget.examId != null) {
      final e = await AppDb.instance.loadExam(widget.examId!);
      _hasVersions = await AppDb.instance.versionCount(e.id!) > 0;

      _title.text = e.title;

      for (final q in e.questions) {
        _qs.add(
          _QD(
            t: q.text,
            opts: [
              for (final o in q.options) _OptD(t: o.text, correct: o.isCorrect),
            ],
          ),
        );
      }
    } else {
      _qs.add(_blank());
    }

    if (mounted) setState(() => _loading = false);
  }

  String? _validate() {
    if (_title.text.trim().isEmpty) return 'Titre manquant';

    if (_qs.isEmpty) return 'Ajoutez au moins une question';

    if (_qs.length > GridLayout.maxQuestions) {
      return 'Maximum ${GridLayout.maxQuestions} questions';
    }

    for (var i = 0; i < _qs.length; i++) {
      final q = _qs[i];

      if (q.text.text.trim().isEmpty) {
        return 'Question ${i + 1} : énoncé vide';
      }

      if (q.opts.length < 2) {
        return 'Question ${i + 1} : au moins 2 propositions';
      }

      if (q.opts.any((o) => o.text.text.trim().isEmpty)) {
        return 'Question ${i + 1} : proposition vide';
      }

      if (!q.opts.any((o) => o.correct)) {
        return 'Question ${i + 1} : cochez au moins une bonne réponse';
      }
    }

    return null;
  }

  Future<void> _save() async {
    if (_saving) return;

    final err = _validate();

    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }

    if (_hasVersions) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Modifier cet examen ?'),
          content: const Text(
            'Ses versions et ses résultats seront supprimés '
            '(les questions changent).',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Continuer'),
            ),
          ],
        ),
      );

      if (ok != true) return;
    }

    setState(() => _saving = true);

    try {
      final exam = Exam(
        id: widget.examId,
        title: _title.text.trim(),
        questions: [
          for (final q in _qs)
            Question(
              text: q.text.text.trim(),
              options: [
                for (final o in q.opts)
                  Option(text: o.text.text.trim(), isCorrect: o.correct),
              ],
            ),
        ],
      );

      await AppDb.instance.saveExam(exam);

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _addQuestion() {
    if (_qs.length >= GridLayout.maxQuestions) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Maximum ${GridLayout.maxQuestions} questions')),
      );
      return;
    }

    setState(() => _qs.add(_blank()));
  }

  void _deleteQuestion(int i) {
    if (_qs.length == 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Un examen doit contenir au moins une question.'),
        ),
      );
      return;
    }

    final q = _qs.removeAt(i);

    q.text.dispose();
    for (final o in q.opts) {
      o.text.dispose();
    }

    setState(() {});
  }

  void _deleteOption(_QD q, int j) {
    final o = q.opts.removeAt(j);
    o.text.dispose();
    setState(() {});
  }

  Widget _optionRow(_QD q, int j) {
    final option = q.opts[j];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: option.correct
            ? const Color(0xFFE0F2F1)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: option.correct
              ? primary.withOpacity(0.4)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Checkbox(
            value: option.correct,
            activeColor: primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5),
            ),
            onChanged: (v) => setState(() => option.correct = v ?? false),
          ),
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: option.correct ? primary : Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              letter(j),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: option.correct ? Colors.white : const Color(0xFF64748B),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: option.text,
              decoration: InputDecoration(
                hintText: 'Proposition ${letter(j)}',
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          IconButton(
            onPressed: q.opts.length > 2 ? () => _deleteOption(q, j) : null,
            icon: const Icon(Icons.close_rounded, size: 20),
            color: const Color(0xFF64748B),
          ),
        ],
      ),
    );
  }

  Widget _questionCard(int i) {
    final q = _qs[i];

    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2F1),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: primary,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Question',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF172033),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _deleteQuestion(i),
                  icon: const Icon(Icons.delete_outline_rounded),
                  color: const Color(0xFFEF4444),
                ),
              ],
            ),

            const SizedBox(height: 14),

            TextField(
              controller: q.text,
              minLines: 2,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Énoncé de la question...',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),

            const SizedBox(height: 20),

            const Row(
              children: [
                Icon(Icons.check_circle_outline, color: primary, size: 20),
                SizedBox(width: 8),
                Text(
                  'Propositions',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            ),

            const SizedBox(height: 8),

            const Text(
              'Cochez les bonnes réponses.',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
            ),

            const SizedBox(height: 14),

            for (var j = 0; j < q.opts.length; j++) _optionRow(q, j),

            if (q.opts.length < 5)
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => q.opts.add(_OptD())),
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter une proposition'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primary,
                    side: BorderSide(color: primary.withOpacity(0.4)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _title.dispose();

    for (final q in _qs) {
      q.text.dispose();
      for (final o in q.opts) {
        o.text.dispose();
      }
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: bg,
        body: Center(child: CircularProgressIndicator(color: primary)),
      );
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          widget.examId == null ? 'Nouvel examen' : 'Modifier l’examen',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF172033),
          ),
        ),
        actions: [
          IconButton(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_rounded),
            color: primary,
            tooltip: 'Enregistrer',
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addQuestion,
        backgroundColor: primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Ajouter une question'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFE0F2F1),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.edit_note_rounded, color: primary, size: 34),
                SizedBox(height: 14),
                Text(
                  'Préparation du QCM',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 21,
                    color: Color(0xFF115E59),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Saisissez les questions et cochez les '
                  'propositions correctes.',
                  style: TextStyle(color: Color(0xFF115E59), height: 1.5),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _title,
                decoration: InputDecoration(
                  labelText: 'Titre de l’examen',
                  prefixIcon: const Icon(Icons.title_rounded, color: primary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          Row(
            children: [
              const Expanded(
                child: Text(
                  'Questions',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 19,
                    color: Color(0xFF172033),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2F1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_qs.length} / ${GridLayout.maxQuestions}',
                  style: const TextStyle(
                    color: primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          for (var i = 0; i < _qs.length; i++) _questionCard(i),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_rounded),
              label: Text(
                _saving ? 'Enregistrement...' : 'Enregistrer l’examen',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 17),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
