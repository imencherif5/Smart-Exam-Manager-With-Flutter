import 'package:flutter/material.dart';

import 'correction_screen.dart';
import 'exam_list_screen.dart';
import 'results_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const Color primary = Color(0xFF0D9488);
  static const Color bg = Color(0xFFF5F7FA);

  Widget _menuCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget page,
    required Color color,
  }) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => page));
        },
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF172033),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 17,
                color: Color(0xFF94A3B8),
              ),
            ],
          ),
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
          'QCM Prof',
          style: TextStyle(
            color: Color(0xFF172033),
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: false,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Container(
            decoration: BoxDecoration(
              color: primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.school_rounded, color: primary),
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0D9488), Color(0xFF0F766E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.assignment_rounded,
                    color: Colors.white,
                    size: 36,
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Bienvenue sur QCM Prof',
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Préparez vos examens, générez vos versions '
                    'et corrigez les copies facilement.',
                    style: TextStyle(
                      color: Color(0xFFE0F2F1),
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            const Text(
              'Espace de travail',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: Color(0xFF172033),
              ),
            ),

            const SizedBox(height: 6),

            const Text(
              'Choisissez une fonctionnalité',
              style: TextStyle(color: Color(0xFF64748B)),
            ),

            const SizedBox(height: 18),

            _menuCard(
              context: context,
              icon: Icons.library_books_rounded,
              title: 'Examens',
              subtitle: 'Créer, importer, gérer et générer des versions',
              page: const ExamListScreen(),
              color: const Color(0xFF0D9488),
            ),

            const SizedBox(height: 14),

            _menuCard(
              context: context,
              icon: Icons.document_scanner_rounded,
              title: 'Correction',
              subtitle: 'Scanner une copie ou saisir les réponses',
              page: const CorrectionScreen(),
              color: const Color(0xFF2563EB),
            ),

            const SizedBox(height: 14),

            _menuCard(
              context: context,
              icon: Icons.analytics_rounded,
              title: 'Résultats',
              subtitle: 'Consulter, rechercher et gérer les notes',
              page: const ResultsScreen(),
              color: const Color(0xFF7C3AED),
            ),

            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2F1),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lightbulb_outline, color: primary),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Préparez vos versions et simplifiez '
                      'la correction de vos examens.',
                      style: TextStyle(
                        color: Color(0xFF115E59),
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
      ),
    );
  }
}
