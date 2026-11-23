import 'dart:math';

/// Géométrie de la grille, en millimètres. Utilisée à la fois par le PDF et par la lecture
/// de la photo : c'est ce qui garantit que les cases détectées sont bien celles imprimées.
/// Origine (0,0) = centre du repère noir en haut à gauche.
class GridLayout {
  static const maxQuestions = 30;
  static const cardW = 94.0, cardH = 88.0; // une grille (6 par A4)
  static const ox = 7.0, oy = 6.0; // position de l'origine dans la carte
  static const fw = 80.0, fh = 76.0; // distance entre repères (largeur, hauteur)
  static const nameX = 14.0, nameW = 64.0, nameH = 6.0, nomY = 7.0, prenomY = 14.5;
  static const answerTop = 26.5, answerBottom = 72.0, colW = 40.0;

  final int n;
  const GridLayout(this.n);

  int get rows => (n / 2).ceil();
  double get pitch => (answerBottom - answerTop) / rows;
  double get radius => min(1.8, pitch * 0.36);
  double xOf(int col, int o) => col * colW + 13 + o * 5.5;
  double bx(int q, int o) => xOf(q ~/ rows, o);
  double by(int q) => answerTop + (q % rows + 0.5) * pitch;
  double numX(int q) => (q ~/ rows) * colW + 4;
}
