import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../db/app_db.dart';
import '../services/pdf_service.dart';
import '../services/scoring.dart';

class VersionsScreen extends StatefulWidget {
  final int examId;
  final String title;

  const VersionsScreen({super.key, required this.examId, required this.title});

  @override
  State<VersionsScreen> createState() => _VersionsScreenState();
}

class _VersionsScreenState extends State<VersionsScreen> {
  static const Color primary = Color(0xFF0D9488);
  static const Color bg = Color(0xFFF5F7FA);

  late Future<List<Map<String, Object?>>> _f = AppDb.instance.listVersions(
    widget.examId,
  );

  void _reload() {
    final future = AppDb.instance.listVersions(widget.examId);

    setState(() {
      _f = future;
    });
  }

  void _msg(String s) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  Future<void> _generate() async {
    var count = 2;
    var shuffleQ = true, shuffleO = true;
    var scoring = 'proportional';
    var penalty = 0.25;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            'Générer des versions',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2F1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.copy_rounded, color: primary),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Nombre de versions',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        onPressed: count > 1 ? () => setD(() => count--) : null,
                        icon: const Icon(Icons.remove_circle_outline),
                        color: primary,
                      ),
                      Text(
                        '$count',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        onPressed: count < 10
                            ? () => setD(() => count++)
                            : null,
                        icon: const Icon(Icons.add_circle_outline),
                        color: primary,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: primary,
                  title: const Text('Mélanger les questions'),
                  subtitle: const Text('Modifier l’ordre des questions'),
                  value: shuffleQ,
                  onChanged: (v) => setD(() => shuffleQ = v),
                ),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: primary,
                  title: const Text('Mélanger les propositions'),
                  subtitle: const Text('Modifier l’ordre des réponses'),
                  value: shuffleO,
                  onChanged: (v) => setD(() => shuffleO = v),
                ),

                const SizedBox(height: 12),

                DropdownButtonFormField<String>(
                  value: scoring,
                  decoration: InputDecoration(
                    labelText: 'Type de correction',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  items: [
                    for (final e in scoringLabels.entries)
                      DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: (v) => setD(() => scoring = v!),
                ),

                if (scoring == 'penalty') ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Paramètre de pénalité',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${(penalty * 100).round()} % d’une bonne réponse',
                          style: const TextStyle(color: Color(0xFF9A3412)),
                        ),
                        Slider(
                          value: penalty,
                          min: 0,
                          max: 1,
                          divisions: 20,
                          activeColor: primary,
                          onChanged: (v) => setD(() => penalty = v),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: primary),
              child: const Text('Générer'),
            ),
          ],
        ),
      ),
    );

    if (ok != true) return;

    try {
      await AppDb.instance.createVersions(
        examId: widget.examId,
        count: count,
        shuffleQuestions: shuffleQ,
        shuffleOptions: shuffleO,
        scoring: scoring,
        penalty: penalty,
      );

      if (mounted) _reload();
    } catch (e) {
      if (mounted) _msg('$e');
    }
  }

  Future<void> _action(int vid, String kind) async {
    if (kind == 'del') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Supprimer la version ?'),
          content: const Text('Cette version sera supprimée définitivement.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Supprimer'),
            ),
          ],
        ),
      );

      if (ok != true) return;

      await AppDb.instance.deleteVersion(vid);
      if (mounted) _reload();
      return;
    }

    try {
      final v = await AppDb.instance.loadVersion(vid);

      final bytes = switch (kind) {
        'exam' => await PdfService.examPdf(v),
        'grid' => await PdfService.gridSheetPdf(v),
        _ => await PdfService.keyPdf(v),
      };

      final name = '${v.examTitle}_${kind}_${v.code}'.replaceAll(
        RegExp(r'[^\w\-]+'),
        '_',
      );

      await Printing.sharePdf(bytes: bytes, filename: '$name.pdf');
    } catch (e) {
      if (mounted) _msg('Erreur PDF : $e');
    }
  }

  Widget _versionCard(Map<String, Object?> v) {
    final code = v['code'] as String;
    final id = v['id'] as int;
    final scoring = scoringLabels[v['scoring']] ?? '';

    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2F1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                code,
                style: const TextStyle(
                  color: primary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Version $code',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: Color(0xFF172033),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      scoring,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Color(0xFF64748B)),
              onSelected: (k) => _action(id, k),
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'exam',
                  child: ListTile(
                    leading: Icon(Icons.picture_as_pdf),
                    title: Text('PDF du sujet'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'grid',
                  child: ListTile(
                    leading: Icon(Icons.grid_on),
                    title: Text('PDF des grilles'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'key',
                  child: ListTile(
                    leading: Icon(Icons.fact_check_outlined),
                    title: Text('Grille de correction'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'del',
                  child: ListTile(
                    leading: Icon(Icons.delete_outline),
                    title: Text('Supprimer'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
          widget.title,
          style: const TextStyle(
            color: Color(0xFF172033),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _generate,
        backgroundColor: primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.shuffle_rounded),
        label: const Text('Générer des versions'),
      ),
      body: FutureBuilder<List<Map<String, Object?>>>(
        future: _f,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: primary),
            );
          }

          if (snap.hasError) {
            return Center(child: Text('Erreur : ${snap.error}'));
          }

          final vs = snap.data ?? [];

          if (vs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2F1),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Icon(
                        Icons.shuffle_rounded,
                        size: 45,
                        color: primary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Aucune version',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Générez des versions pour cet examen.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _generate,
                      icon: const Icon(Icons.shuffle),
                      label: const Text('Générer'),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2F1),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.copy_all_rounded, color: primary, size: 34),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Versions générées',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Color(0xFF115E59),
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            'Téléchargez les sujets et les grilles.',
                            style: TextStyle(
                              color: Color(0xFF115E59),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              Text(
                '${vs.length} version(s)',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF172033),
                ),
              ),

              const SizedBox(height: 16),

              for (final v in vs) _versionCard(v),

              const SizedBox(height: 90),
            ],
          );
        },
      ),
    );
  }
}
