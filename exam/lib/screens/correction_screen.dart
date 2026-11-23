import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

import '../db/app_db.dart';
import '../services/omr_service.dart';
import 'review_screen.dart';

class CorrectionScreen extends StatefulWidget {
  const CorrectionScreen({super.key});

  @override
  State<CorrectionScreen> createState() => _CorrectionScreenState();
}

class _CorrectionScreenState extends State<CorrectionScreen> {
  static const Color primary = Color(0xFF0D9488);
  static const Color bg = Color(0xFFF5F7FA);

  List<Map<String, Object?>> _exams = [], _versions = [];
  int? _examId, _versionId;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    AppDb.instance.listExams().then((e) {
      if (mounted) setState(() => _exams = e);
    });
  }

  Future<void> _pickExam(int? id) async {
    setState(() {
      _examId = id;
      _versionId = null;
      _versions = [];
    });

    if (id == null) return;

    final vs = await AppDb.instance.listVersions(id);
    if (mounted) setState(() => _versions = vs);
  }

  Future<void> _manual() async {
    final v = await AppDb.instance.loadVersion(_versionId!);

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ReviewScreen(version: v)),
    );
  }

  Future<void> _photo(ImageSource source) async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'La lecture par photo marche seulement sur Android/iOS. '
            'Utilisez la saisie manuelle.',
          ),
        ),
      );
      return;
    }

    final x = await ImagePicker().pickImage(source: source, imageQuality: 92);

    if (x == null) return;

    setState(() => _busy = true);

    await Future.delayed(const Duration(milliseconds: 80));

    try {
      final v = await AppDb.instance.loadVersion(_versionId!);

      final dir = await getApplicationDocumentsDirectory();
      final copies = Directory('${dir.path}/copies');

      await copies.create(recursive: true);

      final saved = await File(x.path)
          .copy('${copies.path}/${DateTime.now().millisecondsSinceEpoch}.jpg');

      final r = await OmrService.scan(saved.path, v);

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReviewScreen(
            version: v,
            answers: r.answers,
            ambiguous: r.ambiguous,
            lastName: r.lastName,
            firstName: r.firstName,
            imagePath: saved.path,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Lecture impossible : $e. '
              'Vous pouvez utiliser la saisie manuelle.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _sectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF172033),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
      ],
    );
  }

  Widget _actionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback? onTap,
    bool filled = false,
  }) {
    return SizedBox(
      width: double.infinity,
      child: filled
          ? FilledButton(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 14),
                  Icon(icon, size: 28),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(subtitle, style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_rounded),
                  const SizedBox(width: 12),
                ],
              ),
            )
          : OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: color,
                side: BorderSide(color: color.withOpacity(0.35)),
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 14),
                  Icon(icon, size: 28),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_rounded),
                  const SizedBox(width: 12),
                ],
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ready = _versionId != null && !_busy;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Correction',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF172033),
          ),
        ),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: const Color(0xFFDBEAFE),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.fact_check_rounded,
                      size: 35,
                      color: Color(0xFF2563EB),
                    ),
                    SizedBox(height: 14),
                    Text(
                      'Corriger une copie',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Sélectionnez votre examen et sa version '
                      'pour commencer la correction.',
                      style: TextStyle(color: Color(0xFF1D4ED8), height: 1.5),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              _sectionTitle(
                'Sélection de l’examen',
                'Choisissez l’examen et la version de la copie.',
              ),

              const SizedBox(height: 16),

              Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      DropdownButtonFormField<int>(
                        value: _examId,
                        decoration: InputDecoration(
                          labelText: 'Examen',
                          prefixIcon: const Icon(
                            Icons.menu_book_rounded,
                            color: primary,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        items: [
                          for (final e in _exams)
                            DropdownMenuItem(
                              value: e['id'] as int,
                              child: Text(e['title'] as String),
                            ),
                        ],
                        onChanged: _pickExam,
                      ),

                      const SizedBox(height: 16),

                      DropdownButtonFormField<int>(
                        value: _versionId,
                        decoration: InputDecoration(
                          labelText: 'Version',
                          prefixIcon: const Icon(
                            Icons.copy_all_rounded,
                            color: primary,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        items: [
                          for (final v in _versions)
                            DropdownMenuItem(
                              value: v['id'] as int,
                              child: Text('Version ${v['code']}'),
                            ),
                        ],
                        onChanged: _versions.isEmpty
                            ? null
                            : (v) => setState(() => _versionId = v),
                      ),

                      if (_examId != null && _versions.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.orange,
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Aucune version générée pour cet examen.',
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 28),

              _sectionTitle(
                'Méthode de correction',
                'Choisissez comment importer les réponses.',
              ),

              const SizedBox(height: 16),

              _actionCard(
                icon: Icons.camera_alt_rounded,
                title: 'Photographier la copie',
                subtitle: 'Prendre une photo avec la caméra',
                color: primary,
                filled: true,
                onTap: ready ? () => _photo(ImageSource.camera) : null,
              ),

              const SizedBox(height: 12),

              _actionCard(
                icon: Icons.image_rounded,
                title: 'Importer une image',
                subtitle: 'Choisir une image depuis la galerie',
                color: const Color(0xFF2563EB),
                onTap: ready ? () => _photo(ImageSource.gallery) : null,
              ),

              const SizedBox(height: 12),

              _actionCard(
                icon: Icons.edit_note_rounded,
                title: 'Saisie manuelle',
                subtitle: 'Saisir les réponses sans scanner',
                color: const Color(0xFF7C3AED),
                onTap: ready ? _manual : null,
              ),

              const SizedBox(height: 20),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lightbulb_outline_rounded, color: primary),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Vérifiez toujours les réponses détectées '
                        'avant d’enregistrer la note.',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (_busy)
            ColoredBox(
              color: Colors.black.withOpacity(0.35),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(28),
                  margin: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: primary),
                      SizedBox(height: 20),
                      Text(
                        'Analyse de la copie...',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Veuillez patienter',
                        style: TextStyle(color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
