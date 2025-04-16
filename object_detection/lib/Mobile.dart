import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'main.dart';
import 'widget.dart';

class MobileScreen extends StatefulWidget {
  final CameraDescription camera;
  const MobileScreen({super.key, required this.camera});

  @override
  MobileScreenState createState() => MobileScreenState();
}

class MobileScreenState extends State<MobileScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  bool _isDetecting = false;

  @override
  void initState() {
    super.initState();
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.low,
      enableAudio: false,
    );
    _initializeControllerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleDetection(NavigationLogic navigationLogic) async {
    try {
      if (!_isDetecting) {
        await _initializeControllerFuture;
        await _controller.startImageStream((image) {
          navigationLogic.processFrame(
              image,
              _controller.value.previewSize!.width.toInt(),
              _controller.value.previewSize!.height.toInt());
        });
        setState(() {
          _isDetecting = true;
        });
      } else {
        await _controller.stopImageStream();
        setState(() {
          _isDetecting = false;
        });
      }
    } catch (e) {
      navigationLogic.lastError = 'Toggle error: $e';
      navigationLogic.notifyListeners();
    }
  }

  Widget _buildStatusCard({
    required String title,
    required String status,
    required String details,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.grey[900]!, Colors.black],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.blueAccent,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            status,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            details,
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final navigationLogic = Provider.of<NavigationLogic>(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        foregroundColor: Colors.white,
        backgroundColor: Colors.black,
        centerTitle: true,
        title: const Text(
          "V I S I O N - M A X",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      drawer: drawer(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            _buildStatusCard(
              title: "Camera Status",
              status: _isDetecting ? "Active" : "Inactive",
              details: _isDetecting
                  ? "Using ${widget.camera.name}"
                  : "Tap to start",
            ),
            const SizedBox(height: 20),
            // Detection Card
            _buildStatusCard(
              title: "Detection",
              status: navigationLogic.lastInstruction.isEmpty
                  ? "No objects"
                  : navigationLogic.lastInstruction,
              details: navigationLogic.lastError.isNotEmpty
                  ? navigationLogic.lastError
                  : _isDetecting
                      ? "Processing..."
                      : "Ready",
            ),
            const SizedBox(height: 20),
            // Action Button
            ElevatedButton(
              onPressed: () => _toggleDetection(navigationLogic),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _isDetecting
                  ? const Text(
                      "Stop Scanning",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : const Text(
                      "Start Scanning",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}