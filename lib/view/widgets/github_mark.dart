import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// The GitHub mark, vendored as a painted path. It is a brand logo, not an SF
/// Symbol, so it cannot live in [AppIcons] (SF has only appleLogo among brands);
/// this is the one exception, for the "view source" link. Self-contained: no new
/// dependency and no icon-font change - the official 16x16 Octocat path is parsed
/// and filled at the requested [size].
class GithubMark extends StatelessWidget {
  const GithubMark({required this.color, this.size = 16, super.key});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GithubPainter(color)),
    );
  }
}

class _GithubPainter extends CustomPainter {
  _GithubPainter(this.color);

  final Color color;

  // Octicons "mark-github", 16x16 viewBox.
  static const _d =
      'M8 0c4.42 0 8 3.58 8 8a8.013 8.013 0 01-5.45 7.59c-.4.08-.55-.17-.55-.38 '
      '0-.27.01-1.13.01-2.2 0-.75-.25-1.23-.54-1.48 1.78-.2 3.65-.88 3.65-3.95 '
      '0-.88-.31-1.59-.82-2.15.08-.2.36-1.02-.08-2.12 0 0-.67-.22-2.2.82-.64-.18'
      '-1.32-.27-2-.27-.68 0-1.36.09-2 .27-1.53-1.03-2.2-.82-2.2-.82-.44 1.1-.16 '
      '1.92-.08 2.12-.51.56-.82 1.27-.82 2.15 0 3.06 1.86 3.75 3.64 3.95-.23.2-.44'
      '.55-.51 1.07-.46.21-1.61.55-2.33-.66-.15-.24-.6-.83-1.23-.82-.67.01-.27.38'
      '.01.53.34.19.73.9.82 1.13.16.45.68 1.31 2.69.94 0 .67.01 1.3.01 1.49 0 .21'
      '-.15.46-.55.38A8.013 8.013 0 010 8c0-4.42 3.58-8 8-8z';

  // Static: the path is constant, and the painter is rebuilt per color change.
  static final Path _mark = parseSvgPath(_d);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 16.0;
    canvas.save();
    canvas.scale(scale);
    canvas.drawPath(
      _mark,
      Paint()
        ..color = color
        ..isAntiAlias = true,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GithubPainter old) => old.color != color;
}

/// Minimal SVG path parser for the commands this mark uses: M/m, L/l, H/h, V/v,
/// C/c, A/a, Z/z, including implicit repeats and concatenated arc flags. Elliptic
/// arcs are converted to cubic segments. Not a general SVG parser - just enough
/// for the one vendored path above.
Path parseSvgPath(String d) {
  final path = Path();
  final scanner = _Scanner(d);
  double cx = 0, cy = 0; // current point
  double sx = 0, sy = 0; // subpath start
  String cmd = '';

  while (!scanner.atEnd) {
    final before = scanner.i;
    final next = scanner.peekCommand();
    if (next != null) cmd = scanner.readCommand();
    final rel = cmd.toLowerCase() == cmd;
    switch (cmd.toLowerCase()) {
      case 'm':
        cx = (rel ? cx : 0) + scanner.number();
        cy = (rel ? cy : 0) + scanner.number();
        path.moveTo(cx, cy);
        sx = cx;
        sy = cy;
        cmd = rel ? 'l' : 'L'; // subsequent pairs are implicit lineTos
      case 'l':
        cx = (rel ? cx : 0) + scanner.number();
        cy = (rel ? cy : 0) + scanner.number();
        path.lineTo(cx, cy);
      case 'h':
        cx = (rel ? cx : 0) + scanner.number();
        path.lineTo(cx, cy);
      case 'v':
        cy = (rel ? cy : 0) + scanner.number();
        path.lineTo(cx, cy);
      case 'c':
        final x1 = (rel ? cx : 0) + scanner.number();
        final y1 = (rel ? cy : 0) + scanner.number();
        final x2 = (rel ? cx : 0) + scanner.number();
        final y2 = (rel ? cy : 0) + scanner.number();
        cx = (rel ? cx : 0) + scanner.number();
        cy = (rel ? cy : 0) + scanner.number();
        path.cubicTo(x1, y1, x2, y2, cx, cy);
      case 'a':
        final rx = scanner.number();
        final ry = scanner.number();
        final rot = scanner.number();
        final largeArc = scanner.flag();
        final sweep = scanner.flag();
        final ex = (rel ? cx : 0) + scanner.number();
        final ey = (rel ? cy : 0) + scanner.number();
        _arcTo(path, cx, cy, rx, ry, rot, largeArc, sweep, ex, ey);
        cx = ex;
        cy = ey;
      case 'z':
        path.close();
        cx = sx;
        cy = sy;
    }
    // An iteration that consumed nothing (garbage char, or junk after a
    // consumption-free z) would otherwise spin this loop forever.
    if (scanner.i == before) {
      throw FormatException('unparseable SVG path data', d, scanner.i);
    }
  }
  return path;
}

/// Converts one SVG elliptic arc (endpoint parameterization) to cubic segments,
/// per the SVG implementation notes. Radii are corrected up if too small.
void _arcTo(
  Path path,
  double x0,
  double y0,
  double rx,
  double ry,
  double xRotDeg,
  bool largeArc,
  bool sweep,
  double x,
  double y,
) {
  if (rx == 0 || ry == 0) {
    path.lineTo(x, y);
    return;
  }
  // Coincident endpoints: the spec says no arc, and the center math below
  // would divide by zero into NaN geometry.
  if (x0 == x && y0 == y) return;
  rx = rx.abs();
  ry = ry.abs();
  final phi = xRotDeg * math.pi / 180.0;
  final cosPhi = math.cos(phi), sinPhi = math.sin(phi);

  final dx = (x0 - x) / 2, dy = (y0 - y) / 2;
  final x1p = cosPhi * dx + sinPhi * dy;
  final y1p = -sinPhi * dx + cosPhi * dy;

  final lambda = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry);
  if (lambda > 1) {
    final s = math.sqrt(lambda);
    rx *= s;
    ry *= s;
  }

  final sign = largeArc != sweep ? 1.0 : -1.0;
  var num = rx * rx * ry * ry - rx * rx * y1p * y1p - ry * ry * x1p * x1p;
  final den = rx * rx * y1p * y1p + ry * ry * x1p * x1p;
  if (num < 0) num = 0;
  final co = sign * math.sqrt(num / den);
  final cxp = co * (rx * y1p) / ry;
  final cyp = co * -(ry * x1p) / rx;

  final cxc = cosPhi * cxp - sinPhi * cyp + (x0 + x) / 2;
  final cyc = sinPhi * cxp + cosPhi * cyp + (y0 + y) / 2;

  double angle(double ux, double uy, double vx, double vy) {
    final dot = ux * vx + uy * vy;
    final len = math.sqrt((ux * ux + uy * uy) * (vx * vx + vy * vy));
    var a = math.acos((dot / len).clamp(-1.0, 1.0));
    if (ux * vy - uy * vx < 0) a = -a;
    return a;
  }

  final theta1 = angle(1, 0, (x1p - cxp) / rx, (y1p - cyp) / ry);
  var dTheta = angle((x1p - cxp) / rx, (y1p - cyp) / ry, (-x1p - cxp) / rx, (-y1p - cyp) / ry);
  if (!sweep && dTheta > 0) dTheta -= 2 * math.pi;
  if (sweep && dTheta < 0) dTheta += 2 * math.pi;

  final segments = math.max(1, (dTheta.abs() / (math.pi / 2)).ceil());
  final delta = dTheta / segments;
  final t = 4 / 3 * math.tan(delta / 4);

  var angleStart = theta1;
  for (var seg = 0; seg < segments; seg++) {
    final cos1 = math.cos(angleStart), sin1 = math.sin(angleStart);
    final angleEnd = angleStart + delta;
    final cos2 = math.cos(angleEnd), sin2 = math.sin(angleEnd);

    // Segment endpoints on the ellipse.
    final e1x = cxc + cosPhi * rx * cos1 - sinPhi * ry * sin1;
    final e1y = cyc + sinPhi * rx * cos1 + cosPhi * ry * sin1;
    final e2x = cxc + cosPhi * rx * cos2 - sinPhi * ry * sin2;
    final e2y = cyc + sinPhi * rx * cos2 + cosPhi * ry * sin2;

    // Control points ride each endpoint's tangent (dE/dtheta), scaled by t.
    final q1x = e1x + t * (-(cosPhi * rx * sin1) - sinPhi * ry * cos1);
    final q1y = e1y + t * (-(sinPhi * rx * sin1) + cosPhi * ry * cos1);
    final q2x = e2x - t * (-(cosPhi * rx * sin2) - sinPhi * ry * cos2);
    final q2y = e2y - t * (-(sinPhi * rx * sin2) + cosPhi * ry * cos2);

    path.cubicTo(q1x, q1y, q2x, q2y, e2x, e2y);
    angleStart = angleEnd;
  }
}

class _Scanner {
  _Scanner(this.s);

  final String s;
  int i = 0;

  bool get atEnd {
    _skipSep();
    return i >= s.length;
  }

  void _skipSep() {
    while (i < s.length) {
      final c = s[i];
      if (c == ' ' || c == ',' || c == '\n' || c == '\t' || c == '\r') {
        i++;
      } else {
        break;
      }
    }
  }

  bool _isCommand(String c) => 'MmLlHhVvCcAaZz'.contains(c);

  String? peekCommand() {
    _skipSep();
    if (i >= s.length) return null;
    return _isCommand(s[i]) ? s[i] : null;
  }

  String readCommand() {
    _skipSep();
    return s[i++];
  }

  bool flag() {
    _skipSep();
    if (i >= s.length) throw FormatException('missing arc flag', s, i);
    return s[i++] == '1';
  }

  double number() {
    _skipSep();
    final start = i;
    if (i < s.length && (s[i] == '+' || s[i] == '-')) i++;
    while (i < s.length && _isDigit(s[i])) {
      i++;
    }
    if (i < s.length && s[i] == '.') {
      i++;
      while (i < s.length && _isDigit(s[i])) {
        i++;
      }
    }
    if (i < s.length && (s[i] == 'e' || s[i] == 'E')) {
      i++;
      if (i < s.length && (s[i] == '+' || s[i] == '-')) i++;
      while (i < s.length && _isDigit(s[i])) {
        i++;
      }
    }
    if (i == start) throw FormatException('expected a number', s, i);
    return double.parse(s.substring(start, i));
  }

  bool _isDigit(String c) => c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57;
}
