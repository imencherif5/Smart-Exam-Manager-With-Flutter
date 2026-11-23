import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../db/app_db.dart';
import 'review_screen.dart';

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  static const Color primary = Color(0xFF0D9488);
  static const Color bg = Color(0xFFF5F7FA);

  String _q = '';

  late Future<List<Map<String, Object?>>> _f = AppDb.instance.searchResults('');

  void _reload() =>
      setState(() => _f = AppDb.instance.searchResults(_q.trim()));

  Future<void> _open(Map<String, Object?> r) async {
    final v = await AppDb.instance.loadVersion(r['version_id'] as int);

    final answers = (jsonDecode(r['answers'] as String) as Map).map(
      (k, val) =>
          MapEntry(int.parse(k as String), (val as List).cast<int>().toSet()),
    );

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReviewScreen(
          version: v,
          answers: answers,
          lastName: r['last_name'] as String,
          firstName: r['first_name'] as String,
          imagePath: r['image_path'] as String?,
          readOnly: true,
        ),
      ),
    );
  }

  Future<void> _delete(Map<String, Object?> r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Supprimer ce résultat ?'),
        content: Text(
          '${r['last_name']} ${r['first_name']} – '
          '${(r['score'] as num).toStringAsFixed(2)} / 20',
        ),
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

    final img = await AppDb.instance.deleteResult(r['id'] as int);

    if (img != null && await File(img).exists()) {
      await File(img).delete();
    }

    if (mounted) _reload();
  }

  Widget _resultCard(Map<String, Object?> r) {
    final score = (r['score'] as num).toDouble();
    final name = '${r['last_name']} ${r['first_name']}';
    final date = (r['date'] as String).substring(0, 10);

    Color scoreColor;
    if (score >= 15) {
      scoreColor = const Color(0xFF16A34A);
    } else if (score >= 10) {
      scoreColor = const Color(0xFF0D9488);
    } else {
      scoreColor = const Color(0xFFEF4444);
    }

    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _open(r),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2F1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      color: primary,
                      size: 28,
                    ),
                  ),

                  const SizedBox(width: 14),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Color(0xFF172033),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          r['exam_title'] as String,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: scoreColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        Text(
                          score.toStringAsFixed(2),
                          style: TextStyle(
                            color: scoreColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          ),
                        ),
                        Text(
                          '/20',
                          style: TextStyle(color: scoreColor, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  _detail(Icons.copy_rounded, 'Version ${r['version_code']}'),
                  const SizedBox(width: 12),
                  _detail(Icons.calendar_today_rounded, date),
                  const Spacer(),
                  IconButton(
                    onPressed: () => _delete(r),
                    tooltip: 'Supprimer',
                    icon: const Icon(Icons.delete_outline_rounded),
                    color: const Color(0xFFEF4444),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detail(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF64748B)),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
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
                Icons.analytics_rounded,
                size: 45,
                color: primary,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Aucun résultat',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF172033),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Les résultats enregistrés apparaîtront ici.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF64748B)),
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
        title: const Text(
          'Résultats',
          style: TextStyle(
            color: Color(0xFF172033),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: TextField(
              onChanged: (s) {
                _q = s;
                _reload();
              },
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded, color: primary),
                hintText: 'Rechercher par nom ou prénom',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          Expanded(
            child: FutureBuilder<List<Map<String, Object?>>>(
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

                final rs = snap.data ?? [];

                if (rs.isEmpty) return _emptyState();

                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 90),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2F1),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.analytics_rounded,
                            color: primary,
                            size: 34,
                          ),
                          SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Suivi des résultats',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Color(0xFF115E59),
                                  ),
                                ),
                                SizedBox(height: 5),
                                Text(
                                  'Consultez les notes et les corrections.',
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
                      '${rs.length} résultat(s)',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF172033),
                      ),
                    ),

                    const SizedBox(height: 16),

                    for (final r in rs) _resultCard(r),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
