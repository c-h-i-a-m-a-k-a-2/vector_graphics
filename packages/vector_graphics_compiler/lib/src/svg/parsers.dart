import 'dart:math';

import '../geometry/matrix.dart';
import '../geometry/path.dart';
import 'numbers.dart';

const String _transformCommandAtom = ' *,?([^(]+)\\(([^)]*)\\)';
final RegExp _transformValidator = RegExp('^($_transformCommandAtom)*\$');
final RegExp _transformCommand = RegExp(_transformCommandAtom);

typedef _MatrixParser = AffineMatrix Function(
    String? paramsStr, AffineMatrix current);

const Map<String, _MatrixParser> _matrixParsers = <String, _MatrixParser>{
  'matrix': _parseSvgMatrix,
  'translate': _parseSvgTranslate,
  'scale': _parseSvgScale,
  'rotate': _parseSvgRotate,
  'skewX': _parseSvgSkewX,
  'skewY': _parseSvgSkewY,
};

/// Parses a SVG transform attribute into a [AffineMatrix].
///
/// Also adds [x] and [y] to append as a final translation, e.g. for `<use>`.
AffineMatrix? parseTransform(String? transform, AffineMatrix? parentMatrix) {
  if (transform == null || transform == '') {
    return parentMatrix;
  }

  if (!_transformValidator.hasMatch(transform)) {
    throw StateError('illegal or unsupported transform: $transform');
  }
  final Iterable<Match> matches =
      _transformCommand.allMatches(transform).toList().reversed;
  AffineMatrix result = AffineMatrix.identity;
  for (Match m in matches) {
    final String command = m.group(1)!.trim();
    final String? params = m.group(2);

    final _MatrixParser? transformer = _matrixParsers[command];
    if (transformer == null) {
      throw StateError('Unsupported transform: $command');
    }

    result = transformer(params, result);
  }
  if (parentMatrix != null) {
    return parentMatrix.multiplied(result);
  }
  return result;
}

final RegExp _valueSeparator = RegExp('( *, *| +)');

AffineMatrix _parseSvgMatrix(String? paramsStr, AffineMatrix current) {
  final List<String> params = paramsStr!.trim().split(_valueSeparator);
  assert(params.isNotEmpty);
  assert(params.length == 6);
  final double a = parseDouble(params[0])!;
  final double b = parseDouble(params[1])!;
  final double c = parseDouble(params[2])!;
  final double d = parseDouble(params[3])!;
  final double e = parseDouble(params[4])!;
  final double f = parseDouble(params[5])!;

  return AffineMatrix(a, b, c, d, e, f).multiplied(current);
}

AffineMatrix _parseSvgSkewX(String? paramsStr, AffineMatrix current) {
  final double x = parseDouble(paramsStr)!;
  return AffineMatrix(1.0, 0.0, tan(x), 1.0, 0.0, 0.0).multiplied(current);
}

AffineMatrix _parseSvgSkewY(String? paramsStr, AffineMatrix current) {
  final double y = parseDouble(paramsStr)!;
  return AffineMatrix(1.0, tan(y), 0.0, 1.0, 0.0, 0.0).multiplied(current);
}

AffineMatrix _parseSvgTranslate(String? paramsStr, AffineMatrix current) {
  final List<String> params = paramsStr!.split(_valueSeparator);
  assert(params.isNotEmpty);
  assert(params.length <= 2);
  final double x = parseDouble(params[0])!;
  final double y = params.length < 2 ? 0.0 : parseDouble(params[1])!;
  return AffineMatrix(1.0, 0.0, 0.0, 1.0, x, y).multiplied(current);
}

AffineMatrix _parseSvgScale(String? paramsStr, AffineMatrix current) {
  final List<String> params = paramsStr!.split(_valueSeparator);
  assert(params.isNotEmpty);
  assert(params.length <= 2);
  final double x = parseDouble(params[0])!;
  final double y = params.length < 2 ? x : parseDouble(params[1])!;
  return AffineMatrix(x, 0.0, 0.0, y, 0.0, 0.0).multiplied(current);
}

AffineMatrix _parseSvgRotate(String? paramsStr, AffineMatrix current) {
  final List<String> params = paramsStr!.split(_valueSeparator);
  assert(params.length <= 3);
  final double a = radians(parseDouble(params[0])!);

  final AffineMatrix rotate = AffineMatrix.identity.rotated(a);

  if (params.length > 1) {
    final double x = parseDouble(params[1])!;
    final double y = params.length == 3 ? parseDouble(params[2])! : x;
    return AffineMatrix(1.0, 0.0, 0.0, 1.0, x, y)
        .multiplied(current)
        .multiplied(rotate)
        .multiplied(AffineMatrix(1.0, 0.0, 0.0, 1.0, -x, -y));
  } else {
    return rotate.multiplied(current);
  }
}

/// Parses a `fill-rule` attribute.
PathFillType? parseRawFillRule(String? rawFillRule) {
  if (rawFillRule == 'inherit' || rawFillRule == null) {
    return null;
  }

  return rawFillRule != 'evenodd' ? PathFillType.nonZero : PathFillType.evenOdd;
}

// final RegExp _whitespacePattern = RegExp(r'\s');

// /// Resolves an image reference, potentially downloading it via HTTP.
// Future<Image> resolveImage(String href) async {
//   assert(href != '');

//   final Future<Image> Function(Uint8List) decodeImage =
//       (Uint8List bytes) async {
//     final Codec codec = await instantiateImageCodec(bytes);
//     final FrameInfo frame = await codec.getNextFrame();
//     return frame.image;
//   };

//   if (href.startsWith('http')) {
//     throw UnsupportedError('Cannot request http images');
//   }

//   if (href.startsWith('data:')) {
//     final int commaLocation = href.indexOf(',') + 1;
//     final Uint8List bytes = base64.decode(
//         href.substring(commaLocation).replaceAll(_whitespacePattern, ''));
//     return decodeImage(bytes);
//   }

//   throw UnsupportedError('Could not resolve image href: $href');
// }

// const ParagraphConstraints _infiniteParagraphConstraints = ParagraphConstraints(
//   width: double.infinity,
// );

// /// A [DrawablePaint] with a transparent stroke.
// const DrawablePaint transparentStroke =
//     DrawablePaint(PaintingStyle.stroke, color: Color(0x0));

// /// Creates a [Paragraph] object using the specified [text], [style], and
// /// [foregroundOverride].
// Paragraph createParagraph(
//   String text,
//   DrawableStyle style,
//   DrawablePaint? foregroundOverride,
// ) {
//   final ParagraphBuilder builder = ParagraphBuilder(ParagraphStyle())
//     ..pushStyle(
//       style.textStyle!.toFlutterTextStyle(
//         foregroundOverride: foregroundOverride,
//       ),
//     )
//     ..addText(text);
//   return builder.build()..layout(_infiniteParagraphConstraints);
// }

/// Parses strings in the form of '1.0' or '100%'.
double parseDecimalOrPercentage(String val, {double multiplier = 1.0}) {
  if (isPercentage(val)) {
    return parsePercentage(val, multiplier: multiplier);
  } else {
    return parseDouble(val)!;
  }
}

/// Parses values in the form of '100%'.
double parsePercentage(String val, {double multiplier = 1.0}) {
  return parseDouble(val.substring(0, val.length - 1))! / 100 * multiplier;
}

/// Whether a string should be treated as a percentage (i.e. if it ends with a `'%'`).
bool isPercentage(String val) => val.endsWith('%');
