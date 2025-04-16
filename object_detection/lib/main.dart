import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart'; // Add Provider

import 'Mobile.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter(); // Initialize Hive
  await Hive.openBox('settings'); 
  try {
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      print('Error: No cameras available');
      return;
    }
    final firstCamera = cameras.first;
    runApp(
      ChangeNotifierProvider(
        create: (_) => NavigationLogic(), // Provide NavigationLogic
        child: MyApp(camera: firstCamera),
      ),
    );
  } catch (e) {
    print('Error initializing cameras: $e');
  }
}

class MyApp extends StatelessWidget {
  final CameraDescription camera;
  const MyApp({super.key, required this.camera});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Navigation Assistant',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: MobileScreen(camera: camera),
    );
  }
}

// NavigationLogic remains unchanged
class NavigationLogic extends ChangeNotifier {
  final FlutterTts tts = FlutterTts();
  final ObjectDetector detector = ObjectDetector(
    options: ObjectDetectorOptions(
      mode: DetectionMode.single,
      classifyObjects: true,
      multipleObjects: true,
    ),
  );
  DateTime lastAlertTime = DateTime.now();
  double _alertCooldown = 2.0; // Changed to private with getter
  static const double smallAreaThreshold = 0.01; // 1%
  static const double frameInterval = 5000; // 1 frame every 5s
  DateTime lastFrameTime = DateTime.now();
  String lastInstruction = 'Initializing...';
  String lastError = '';
  int detectionCount = 0;
  int noDetectionFrames = 0;
  static const int noDetectionThreshold = 3;
  bool _isHapticFeedback = true;

  bool get isHapticFeedback => _isHapticFeedback;
  set isHapticFeedback(bool value) {
    _isHapticFeedback = value;
    notifyListeners();
  }

  double get alertCooldown => _alertCooldown;

  set alertCooldown(double value) {
    _alertCooldown = value;
    notifyListeners();
  }

  NavigationLogic() {
    _initTts();
  }

  Future<void> _initTts() async {
  try {
    final box = Hive.box('settings');
    final speechRate = box.get('speechRate', defaultValue: 0.5) as double;
    final pitch = box.get('pitch', defaultValue: 1.0) as double;
    final volume = box.get('volume', defaultValue: 1.0) as double;
    _alertCooldown = box.get('alertCooldown', defaultValue: 2.0) as double;
    print('Loaded settings: speechRate=$speechRate, pitch=$pitch, volume=$volume, alertCooldown=$_alertCooldown');
    await tts.setLanguage('en-US');
    await tts.setSpeechRate(speechRate);
    await tts.setPitch(pitch);
    await tts.setVolume(volume);
    lastInstruction = 'TTS ready';
    notifyListeners();
  } catch (e) {
    lastError = 'TTS error: $e';
    notifyListeners();
  }
}

  Future<void> processFrame(CameraImage image, int screenWidth, int screenHeight) async {
    final now = DateTime.now();
    if (now.difference(lastFrameTime).inMilliseconds < frameInterval) {
      return;
    }
    lastFrameTime = now;

    try {
      final inputImage = _convertCameraImage(image);
      final detections = await detector.processImage(inputImage);
      detectionCount = detections.length;
      lastError = '';

      if (detections.isEmpty) {
        noDetectionFrames++;
        if (noDetectionFrames >= noDetectionThreshold) {
          lastInstruction = 'No obstacles detected';
          noDetectionFrames = 0;
        }
      } else {
        noDetectionFrames = 0;
        lastInstruction = _analyzeDetections(detections, screenWidth, screenHeight);
      }

      _speakInstruction(lastInstruction);
      notifyListeners();
    } catch (e) {
      lastError = 'Error: $e';
      lastInstruction = 'Detection failed';
      notifyListeners();
    }
  }

  InputImage _convertCameraImage(CameraImage image) {
    try {
      // Handle YUV420 (common on Android)
      final int width = image.width;
      final int height = image.height;
      final Uint8List yBuffer = image.planes[0].bytes; // Y plane
      final Uint8List uBuffer = image.planes[1].bytes; // U plane
      final Uint8List vBuffer = image.planes[2].bytes; // V plane

      final int ySize = width * height;
      final int uvSize = ySize ~/ 4; // U and V are quarter size
      final Uint8List bytes = Uint8List(ySize + 2 * uvSize);

      // Copy Y plane
      bytes.setRange(0, ySize, yBuffer);

      // Interleave V and U (NV21 order: Y, then VU)
      for (int i = 0; i < uvSize; i++) {
        bytes[ySize + 2 * i] = vBuffer[i];
        bytes[ySize + 2 * i + 1] = uBuffer[i];
      }

      return InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(width.toDouble(), height.toDouble()),
          rotation: Platform.isAndroid ? InputImageRotation.rotation90deg : InputImageRotation.rotation0deg,
          format: InputImageFormat.nv21,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );
    } catch (e) {
      lastError = 'Conversion error: $e';
      notifyListeners();
      rethrow;
    }
  }

  String _analyzeDetections(List<DetectedObject> detections, int screenWidth, int screenHeight) {
    double leftArea = 0, rightArea = 0;
    final screenArea = screenWidth * screenHeight;
    final midpoint = screenWidth / 2;

    for (var detection in detections) {
      final rect = detection.boundingBox;
      final area = rect.width * rect.height;
      if (area / screenArea < smallAreaThreshold) {
        continue;
      }

      final xCenter = rect.left + (rect.width / 2);
      if (xCenter < midpoint) {
        leftArea += area;
      } else {
        rightArea += area;
      }
    }

    final leftPercentage = (leftArea / (screenArea / 2)) * 100;
    final rightPercentage = (rightArea / (screenArea / 2)) * 100;

    if (leftPercentage < 15 && rightPercentage > 40) {
      return 'Go left, right side blocked';
    } else if (rightPercentage < 15 && leftPercentage > 40) {
      return 'Go right, left side blocked';
    } else if (leftPercentage > 40 && rightPercentage > 40) {
      return 'Stop, path blocked';
    } else {
      return 'Clear path ahead';
    }
  }

  void _speakInstruction(String instruction) {
    final now = DateTime.now();
    if (now.difference(lastAlertTime).inSeconds >= alertCooldown) {
      tts.speak(instruction);
      lastAlertTime = now;

      if (_isHapticFeedback) {
        if (instruction == 'Stop, path blocked') {
          Vibration.vibrate(duration: 2250);
        } else if (instruction == 'Go right, left side blocked') {
          Vibration.vibrate(duration: 1500);
        } else if (instruction == 'Go left, right side blocked') {
          Vibration.vibrate(duration: 750);
        }
      }
    }
  }

  

  @override
  void dispose() {
    detector.close();
    tts.stop();
    super.dispose();
  }
}