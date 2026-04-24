import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

import 'app.dart';
import 'features/tts/presentation/controllers/sherpa_tts_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await pdfrxFlutterInitialize(dismissPdfiumWasmWarnings: true);
  sherpa_onnx.initBindings();
  await SherpaTtsService.instance.ensureInitialized();
  runApp(const LectioApp());
}
