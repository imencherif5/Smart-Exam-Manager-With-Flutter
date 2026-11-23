import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../db/app_db.dart';
import '../models/models.dart';
import '../services/scoring.dart';

/// Saisie / vérification des réponses, correction en vert et rouge, note sur 20.
/// Avec readOnly = true : sert à consulter un résultat déjà enregistré.
class ReviewScreen extends StatefulWidget {
  final ExamVersion version;
  final Map<int, Set<int>> answers;
  final Set<int> ambiguous;
  final String lastName, firstName;
  final String? imagePath;
  final bool readOnly;

  const ReviewScreen({
    super.key,
    required this.version,
    this.answers = const {},
    this.ambiguous = const {},
    this.lastName = '',
    this.firstName = '',
    this.imagePath,
    this.readOnly = false,
  });

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  static const Color primary = Color(0xFF0D9488);
  static const Color bg = Color(0xFFF5F7FA);

  late final Map<int, Set<int>> _ans = {
    for (final e in widget.answers.entries) e.key: {...e.value},
  };

  late final Set<int> _amb = {...widget.ambiguous};

  late final _last = TextEditingController(text: widget.lastName);
  late final _first = TextEditingController(text: widget.firstName);

  late bool _corrected = widget.readOnly;

  bool _saving = false;

  ExamVersion get v => widget.version;

  double get _score => totalScore(v, _ans);

  void _toggle(int q, int o) {
    if (widget.readOnly) return;

    setState(() {
      final s = _ans.putIfAbsent(q, () => <int>{});

      if (!s.add(o)) s.remove(o);

      _amb.remove(q);
      _corrected = false;
    });
  }

  Future<void> _save() async {
    if (_saving) return;

    if (_last.text.trim().isEmpty && _first.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saisissez le nom ou le prénom')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      await AppDb.instance.saveResult({
        'last_name': _last.text.trim(),
        'first_name': _first.text.trim(),
        'exam_id': v.examId,
        'version_id': v.id,
        'exam_title': v.examTitle,
        'version_code': v.code,
        'date': DateTime.now().toIso8601String(),
        'score': _score,
        'answers': jsonEncode({
          for (final e in _ans.entries) '${e.key}': (e.value.toList()..sort()),
        }),
        'image_path': widget.imagePath,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Résultat enregistré')));

      Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showImage() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: InteractiveViewer(child: Image.file(File(widget.imagePath!))),
      ),
    );
  }

  Widget _bubble(int q, int o) {
    final sel = _ans[q]?.contains(o) ?? false;
    final ok = v.correctOf(q).contains(o);

    Color bg = Colors.transparent;
    Color fg = const Color(0xFF172033);
    Color border = const Color(0xFFCBD5E1);

    if (_corrected) {
      if (sel) {
        bg = ok ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
        fg = Colors.white;
        border = bg;
      } else if (ok) {
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF166534);
        border = const Color(0xFF16A34A);
      }
    } else if (sel) {
      bg = primary;
      fg = Colors.white;
      border = primary;
    }

    return InkWell(
      onTap: () => _toggle(q, o),
      customBorder: const CircleBorder(),
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: bg,
          border: Border.all(color: border, width: 1.5),
        ),
        child: Text(
          letter(o),
          style: TextStyle(
            color: fg,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  Widget _questionCard(int q) {
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2F1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${q + 1}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: primary,
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      v.questions[q].text,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: Color(0xFF172033),
                        height: 1.4,
                      ),
                    ),
                  ),
                ),

                if (_amb.contains(q))
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange,
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 18),

            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (var o = 0; o < v.questions[q].options.length; o++)
                  _bubble(q, o),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _studentSection() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.person_outline_rounded, color: primary),
                SizedBox(width: 10),
                Text(
                  'Informations de l’étudiant',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),

            const SizedBox(height: 16),

            TextField(
              controller: _last,
              enabled: !widget.readOnly,
              decoration: InputDecoration(
                labelText: 'Nom',
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: _first,
              enabled: !widget.readOnly,
              decoration: InputDecoration(
                labelText: 'Prénom',
                prefixIcon: const Icon(Icons.person),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legend() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 12,
        children: [
          _legendItem(const Color(0xFF16A34A), 'Correcte'),
          _legendItem(const Color(0xFFDC2626), 'Incorrecte'),
          _legendItem(const Color(0xFFDCFCE7), 'Bonne réponse non cochée'),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: color == const Color(0xFFDCFCE7)
                  ? const Color(0xFF16A34A)
                  : color,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
        ),
      ],
    );
  }

  Widget _scorePanel() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _corrected ? const Color(0xFFE0F2F1) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _corrected ? primary : Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              _corrected
                  ? Icons.check_circle_rounded
                  : Icons.pending_actions_rounded,
              color: _corrected ? Colors.white : primary,
              size: 28,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _corrected ? 'Note obtenue' : 'Correction non effectuée',
                  style: TextStyle(
                    color: _corrected
                        ? const Color(0xFF115E59)
                        : const Color(0xFF475569),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _corrected ? 'Résultat calculé' : 'Appuyez sur Corriger',
                  style: TextStyle(
                    color: _corrected
                        ? const Color(0xFF115E59)
                        : const Color(0xFF64748B),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          Text(
            _corrected ? _score.toStringAsFixed(2) : '—',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 24,
              color: _corrected ? primary : const Color(0xFF64748B),
            ),
          ),

          const SizedBox(width: 4),

          Text(
            '/20',
            style: TextStyle(
              color: _corrected ? primary : const Color(0xFF64748B),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _last.dispose();
    _first.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          '${v.examTitle} · Version ${v.code}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF172033),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (widget.imagePath != null)
            IconButton(
              icon: const Icon(Icons.image_outlined),
              tooltip: 'Afficher la copie',
              onPressed: _showImage,
              color: primary,
            ),
        ],
      ),

      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _scorePanel(),

              if (!widget.readOnly) ...[
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => setState(() => _corrected = true),
                        icon: const Icon(Icons.fact_check_rounded),
                        label: const Text('Corriger'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primary,
                          side: const BorderSide(color: primary),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_rounded),
                        label: Text(
                          _saving ? 'Enregistrement...' : 'Enregistrer',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),

      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFE0F2F1),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.fact_check_rounded, color: primary, size: 34),
                const SizedBox(height: 14),
                const Text(
                  'Vérification des réponses',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 21,
                    color: Color(0xFF115E59),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${v.questions.length} questions · Version ${v.code}',
                  style: const TextStyle(color: Color(0xFF115E59)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          _studentSection(),

          if (_amb.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${_amb.length} question(s) à vérifier. '
                      'Les réponses ambiguës peuvent être modifiées.',
                      style: const TextStyle(
                        color: Color(0xFF9A3412),
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          if (_corrected) ...[_legend(), const SizedBox(height: 20)],

          const Text(
            'Questions',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 19,
              color: Color(0xFF172033),
            ),
          ),

          const SizedBox(height: 16),

          for (var q = 0; q < v.questions.length; q++) _questionCard(q),

          const SizedBox(height: 160),
        ],
      ),
    );
  }
}
