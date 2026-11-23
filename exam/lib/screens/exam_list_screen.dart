import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../db/app_db.dart';
import '../services/json_import.dart';
import 'exam_edit_screen.dart';
import 'versions_screen.dart';

class ExamListScreen extends StatefulWidget {
  const ExamListScreen({super.key});

  @override
  State<ExamListScreen> createState() => _ExamListScreenState();
}

class _ExamListScreenState extends State<ExamListScreen> {
  static const Color primary = Color(0xFF0D9488);
  static const Color bg = Color(0xFFF5F7FA);

  late Future<List<Map<String, Object?>>> _f = AppDb.instance.listExams();

  // Recharger les examens sans opération async dans setState.
  // Recharger la liste des examens.
  void _reload() {
    setState(() {
      _f = AppDb.instance.listExams();
    });
  }

  void _msg(String s) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  // Importation JSON compatible avec Flutter Web.

  Future<void> _import() async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (file == null) return;

      // Lire le contenu du fichier
      final bytes = await file.readAsBytes();
      final content = utf8.decode(bytes);

      // Convertir le JSON en examen
      final exam = JsonImport.parse(content);

      if (exam.title.trim().isEmpty) {
        throw Exception('Le titre de l’examen est vide.');
      }

      if (exam.questions.isEmpty) {
        throw Exception('Le fichier ne contient aucune question.');
      }

      // Enregistrer l'examen dans SQLite
      await AppDb.instance.saveExam(exam);

      if (!mounted) return;

      _reload();

      if (!mounted) return;

      _msg('Examen importé avec succès : ${exam.title}');
    } on FormatException catch (e) {
      if (mounted) {
        _msg('JSON invalide : ${e.message}');
      }
    } catch (e) {
      if (mounted) {
        _msg('Erreur lors de l’importation : $e');
      }
    }
  }

  Future<void> _edit(int? id) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ExamEditScreen(examId: id)),
    );

    if (changed == true && mounted) {
      _reload();
    }
  }

  Future<void> _delete(int id, String title) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Supprimer cet examen ?'),
        content: Text(
          '« $title », ses versions et ses résultats '
          'seront supprimés définitivement.',
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

    if (ok == true) {
      await AppDb.instance.deleteExam(id);

      if (mounted) {
        _reload();
      }
    }
  }

  void _add() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 20),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Créer un examen',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                tileColor: const Color(0xFFF5F7FA),
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE0F2F1),
                  child: Icon(Icons.edit_rounded, color: primary),
                ),
                title: const Text(
                  'Saisie manuelle',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('Créer les questions directement'),
                onTap: () {
                  Navigator.pop(ctx);
                  _edit(null);
                },
              ),
              const SizedBox(height: 12),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                tileColor: const Color(0xFFF5F7FA),
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFDBEAFE),
                  child: Icon(Icons.file_open_rounded, color: Colors.blue),
                ),
                title: const Text(
                  'Importer un fichier JSON',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('Importer un examen préparé'),
                onTap: () {
                  Navigator.pop(ctx);
                  _import();
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
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
                Icons.library_books_rounded,
                color: primary,
                size: 45,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Aucun examen',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF172033),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Créez votre premier examen ou importez '
              'un fichier JSON pour commencer.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF64748B), height: 1.5),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _add,
              icon: const Icon(Icons.add),
              label: const Text('Créer un examen'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _examCard(Map<String, Object?> e) {
    final id = e['id'] as int;
    final title = e['title'] as String;

    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => VersionsScreen(examId: id, title: title),
            ),
          );

          if (mounted) {
            _reload();
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2F1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.description_rounded,
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
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF172033),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _infoChip(Icons.quiz_rounded, '${e['nq']} questions'),
                        _infoChip(Icons.copy_rounded, '${e['nv']} versions'),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Color(0xFF64748B)),
                onSelected: (a) {
                  if (a == 'edit') {
                    _edit(id);
                  } else {
                    _delete(id, title);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 20),
                        SizedBox(width: 10),
                        Text('Modifier'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'del',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 20),
                        SizedBox(width: 10),
                        Text('Supprimer'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Examens',
          style: TextStyle(
            color: Color(0xFF172033),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        backgroundColor: primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nouvel examen'),
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

          final exams = snap.data ?? [];

          if (exams.isEmpty) {
            return _emptyState();
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
                    Icon(Icons.library_books_rounded, color: primary, size: 34),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Votre bibliothèque',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Color(0xFF115E59),
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            'Gérez vos examens et leurs versions.',
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
                '${exams.length} examen(s)',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF172033),
                ),
              ),
              const SizedBox(height: 16),
              for (final e in exams) _examCard(e),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }
}
