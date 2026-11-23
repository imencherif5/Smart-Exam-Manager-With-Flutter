import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import '../models/models.dart';
import 'grid_layout.dart';

class OmrResult {
  final Map<int, Set<int>> answers; // question -> propositions cochées
  final Set<int> ambiguous; // questions à vérifier à la main
  final String lastName, firstName;
  OmrResult(this.answers, this.ambiguous, this.lastName, this.firstName);
}

class _Blob {
  final double cx, cy;
  _Blob(this.cx, this.cy);
}

typedef _Mapper = Point<double> Function(double xmm, double ymm);

/// Lecture d'une grille photographiée :
/// 1) niveaux de gris + seuil d'Otsu, 2) détection des 4 repères noirs (carrés pleins),
/// 3) conversion mm -> pixels par interpolation entre les 4 repères,
/// 4) mesure du taux de noir dans chaque case, 5) OCR du nom et du prénom.
class OmrService {
  static const _maxSide = 1400;
  static const _marked = 0.55; // taux de noir >= : case cochée
  static const _unsure = 0.25; // entre les deux : ambigu

  static Future<OmrResult> scan(String path, ExamVersion v) async {
    final decoded = img.decodeImage(await File(path).readAsBytes());
    if (decoded == null) throw Exception('Image illisible');
    var src = img.bakeOrientation(decoded);
    if (max(src.width, src.height) > _maxSide) {
      src = src.width >= src.height ? img.copyResize(src, width: _maxSide) : img.copyResize(src, height: _maxSide);
    }
    final w = src.width, h = src.height;
    final gray = Uint8List(w * h);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final p = src.getPixel(x, y);
        gray[y * w + x] = (0.299 * p.r + 0.587 * p.g + 0.114 * p.b).round().clamp(0, 255).toInt();
      }
    }
    final th = _otsu(gray);
    final dark = Uint8List(w * h);
    for (var i = 0; i < gray.length; i++) {
      dark[i] = gray[i] < th ? 1 : 0;
    }

    final m = _findMarkers(dark, w, h); // tl, tr, bl, br
    final tl = m[0], tr = m[1], bl = m[2], br = m[3];
    Point<double> map(double xmm, double ymm) {
      final u = xmm / GridLayout.fw, t = ymm / GridLayout.fh;
      double mix(double a, double b, double c, double d) =>
          (1 - u) * (1 - t) * a + u * (1 - t) * b + (1 - u) * t * c + u * t * d;
      return Point(mix(tl.x, tr.x, bl.x, br.x), mix(tl.y, tr.y, bl.y, br.y));
    }

    final scale = (tl.distanceTo(tr) / GridLayout.fw + tl.distanceTo(bl) / GridLayout.fh) / 2; // px par mm
    final lay = GridLayout(v.questions.length);
    final answers = <int, Set<int>>{};
    final ambiguous = <int>{};

    for (var q = 0; q < v.questions.length; q++) {
      final sel = <int>{};
      for (var o = 0; o < v.questions[q].options.length; o++) {
        final c = map(lay.bx(q, o), lay.by(q));
        final r = lay.radius * scale * 0.65; // on évite le contour imprimé
        var dk = 0, tot = 0;
        final ri = r.ceil();
        for (var dy = -ri; dy <= ri; dy++) {
          for (var dx = -ri; dx <= ri; dx++) {
            if (dx * dx + dy * dy > r * r) continue;
            final x = (c.x + dx).round(), y = (c.y + dy).round();
            if (x < 0 || y < 0 || x >= w || y >= h) continue;
            tot++;
            dk += dark[y * w + x];
          }
        }
        final fill = tot == 0 ? 0.0 : dk / tot;
        if (fill >= _marked) {
          sel.add(o);
        } else if (fill >= _unsure) {
          ambiguous.add(q);
        }
      }
      // plusieurs cases cochées alors qu'une seule bonne réponse existe : à vérifier
      if (sel.length > 1 && v.correctOf(q).length == 1) ambiguous.add(q);
      if (sel.isNotEmpty) answers[q] = sel;
    }

    String last = '', first = '';
    try {
      last = (await _readBox(src, map, GridLayout.nameX, GridLayout.nomY, GridLayout.nameW, GridLayout.nameH))
          .toUpperCase();
      first = await _readBox(src, map, GridLayout.nameX, GridLayout.prenomY, GridLayout.nameW, GridLayout.nameH);
    } catch (_) {
      // OCR indisponible : l'enseignant saisira le nom
    }
    return OmrResult(answers, ambiguous, last, first);
  }

  static int _otsu(Uint8List g) {
    final hist = List<int>.filled(256, 0);
    for (final v in g) {
      hist[v]++;
    }
    final total = g.length;
    double sum = 0;
    for (var i = 0; i < 256; i++) {
      sum += i * hist[i];
    }
    double sumB = 0, best = 0;
    int wB = 0, th = 127;
    for (var t = 0; t < 256; t++) {
      wB += hist[t];
      if (wB == 0) continue;
      final wF = total - wB;
      if (wF == 0) break;
      sumB += t * hist[t];
      final mB = sumB / wB, mF = (sum - sumB) / wF;
      final between = wB.toDouble() * wF * (mB - mF) * (mB - mF);
      if (between > best) {
        best = between;
        th = t;
      }
    }
    return th;
  }

  /// Cherche les carrés noirs pleins (composantes connexes) et garde le plus proche de chaque coin.
  static List<Point<double>> _findMarkers(Uint8List dark, int w, int h) {
    final seen = Uint8List(w * h);
    final stack = Int32List(w * h);
    final maxDim = max(w, h);
    final cands = <_Blob>[];
    for (var s = 0; s < dark.length; s++) {
      if (dark[s] == 0 || seen[s] == 1) continue;
      var sp = 0;
      stack[sp++] = s;
      seen[s] = 1;
      var minX = w, maxX = 0, minY = h, maxY = 0, cnt = 0, sx = 0, sy = 0;
      while (sp > 0) {
        final p = stack[--sp];
        final x = p % w, y = p ~/ w;
        cnt++;
        sx += x;
        sy += y;
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
        if (x > 0 && dark[p - 1] == 1 && seen[p - 1] == 0) {
          seen[p - 1] = 1;
          stack[sp++] = p - 1;
        }
        if (x < w - 1 && dark[p + 1] == 1 && seen[p + 1] == 0) {
          seen[p + 1] = 1;
          stack[sp++] = p + 1;
        }
        if (y > 0 && dark[p - w] == 1 && seen[p - w] == 0) {
          seen[p - w] = 1;
          stack[sp++] = p - w;
        }
        if (y < h - 1 && dark[p + w] == 1 && seen[p + w] == 0) {
          seen[p + w] = 1;
          stack[sp++] = p + w;
        }
      }
      final bw = maxX - minX + 1, bh = maxY - minY + 1;
      if (bw < maxDim * 0.012 || bw > maxDim * 0.15 || bh < maxDim * 0.012 || bh > maxDim * 0.15) continue;
      final ratio = bw / bh;
      if (ratio < 0.7 || ratio > 1.4) continue;
      if (cnt / (bw * bh) < 0.85) continue; // carré plein (une case noircie fait ~0,78)
      cands.add(_Blob(sx / cnt, sy / cnt));
    }

    Point<double> pick(bool left, bool top) {
      final cx = left ? 0.0 : w.toDouble(), cy = top ? 0.0 : h.toDouble();
      _Blob? best;
      var bd = double.infinity;
      for (final b in cands) {
        if ((b.cx < w / 2) != left || (b.cy < h / 2) != top) continue;
        final dx = b.cx - cx, dy = b.cy - cy;
        final d = dx * dx + dy * dy;
        if (d < bd) {
          bd = d;
          best = b;
        }
      }
      if (best == null) {
        throw Exception("les 4 repères noirs de la grille n'ont pas été détectés. "
            'Cadrez toute la grille, bien à plat, avec un bon éclairage.');
      }
      return Point(best.cx, best.cy);
    }

    return [pick(true, true), pick(false, true), pick(true, false), pick(false, false)];
  }

  static Future<String> _readBox(img.Image src, _Mapper map, double x, double y, double bw, double bh) async {
    final pts = [map(x, y), map(x + bw, y), map(x, y + bh), map(x + bw, y + bh)];
    int cl(num v, int hi) => v.clamp(0, hi).toInt();
    final x0 = cl(pts.map((p) => p.x).reduce(min).floor(), src.width - 1);
    final x1 = cl(pts.map((p) => p.x).reduce(max).ceil(), src.width - 1);
    final y0 = cl(pts.map((p) => p.y).reduce(min).floor(), src.height - 1);
    final y1 = cl(pts.map((p) => p.y).reduce(max).ceil(), src.height - 1);
    var crop = img.copyCrop(src, x: x0, y: y0, width: max(1, x1 - x0), height: max(1, y1 - y0));
    if (crop.height < 120) crop = img.copyResize(crop, height: 120);
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/ocr_${DateTime.now().microsecondsSinceEpoch}.png');
    await f.writeAsBytes(img.encodePng(crop));
    final rec = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final r = await rec.processImage(InputImage.fromFilePath(f.path));
      return r.text.replaceAll('\n', ' ').trim();
    } finally {
      await rec.close();
      if (await f.exists()) await f.delete();
    }
  }
}
