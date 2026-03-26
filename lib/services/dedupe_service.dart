import 'dart:io';
import 'package:crypto/crypto.dart';

Future<String> makeFingerprint(
  File file,
  String startTime,
  String recordKey,
) async {
  final bytes = await file.readAsBytes();
  final hash = sha256.convert(bytes).toString();
  return '$recordKey|$hash|$startTime';
}
