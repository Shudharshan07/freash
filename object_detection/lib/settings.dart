import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive/hive.dart';
import 'main.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  SettingsScreenState createState() => SettingsScreenState();
}

class SettingsScreenState extends State<SettingsScreen> {
  double _speechRate = 0.5;
  double _pitch = 1.0;
  double _volume = 1.0;
  double _alertCooldown = 2.0;
  bool _isHapticFeedback = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    // Initialize with default values (since TTS getters are async or unavailable)
    final navigationLogic = Provider.of<NavigationLogic>(context, listen: false);
    _alertCooldown = navigationLogic.alertCooldown; // Use getter
  }

  Future<void> _saveSettings() async {
    final box = Hive.box('settings');
    await box.put('speechRate', _speechRate);
    await box.put('pitch', _pitch);
    await box.put('volume', _volume);
    await box.put('alertCooldown', _alertCooldown);
    await box.put('isHapticFeedback', _isHapticFeedback);
  }

  Future<void> _loadSettings() async {
  final box = Hive.box('settings');
  final speechRate = box.get('speechRate', defaultValue: 0.5) as double;
  final pitch = box.get('pitch', defaultValue: 1.0) as double;
  final volume = box.get('volume', defaultValue: 1.0) as double;
  final alertCooldown = box.get('alertCooldown', defaultValue: 2.0) as double;
  final isHapticFeedback = box.get('isHapticFeedback', defaultValue: true) as bool;
  print('SettingsScreen loaded: speechRate=$speechRate, pitch=$pitch, volume=$volume, alertCooldown=$alertCooldown, isHapticFeedback=$isHapticFeedback');
  setState(() {
    _speechRate = speechRate;
    _pitch = pitch;
    _volume = volume;
    _alertCooldown = alertCooldown;
    _isHapticFeedback = isHapticFeedback;
  });
  final navigationLogic = Provider.of<NavigationLogic>(context, listen: false);
  await navigationLogic.tts.setSpeechRate(_speechRate);
  await navigationLogic.tts.setPitch(_pitch);
  await navigationLogic.tts.setVolume(_volume);
  navigationLogic.alertCooldown = _alertCooldown;
}

  Future<void> _resetToDefault(NavigationLogic navigationLogic) async {
  setState(() {
    _speechRate = 0.5;
    _pitch = 1.0;
    _volume = 1.0;
    _alertCooldown = 2.0;
    _isHapticFeedback = true;
  });
  await navigationLogic.tts.setSpeechRate(_speechRate);
  await navigationLogic.tts.setPitch(_pitch);
  await navigationLogic.tts.setVolume(_volume);
  navigationLogic.alertCooldown = _alertCooldown;
  navigationLogic.notifyListeners();
  }

  Future<void> _updateTtsSettings(NavigationLogic navigationLogic) async {
    await navigationLogic.tts.setSpeechRate(_speechRate);
    await navigationLogic.tts.setPitch(_pitch);
    await navigationLogic.tts.setVolume(_volume);
    navigationLogic.alertCooldown = _alertCooldown; // Use setter
    navigationLogic.notifyListeners();
  }

  Widget _buildSlider({
    required String title,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
    required String label,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: 10,
          label: label,
          activeColor: Colors.blueAccent,
          inactiveColor: Colors.grey,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildToggle({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Switch(
          value: value,
          activeColor: Colors.blueAccent,
          onChanged: onChanged,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final navigationLogic = Provider.of<NavigationLogic>(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Settings',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            // TTS Speech Rate
            _buildSlider(
              title: 'Speech Rate',
              value: _speechRate,
              min: 0.1,
              max: 1.0,
              onChanged: (value) {
                setState(() {
                  _speechRate = value;
                });
                _updateTtsSettings(navigationLogic);
              },
              label: _speechRate.toStringAsFixed(1),
            ),
            const SizedBox(height: 20),
            // TTS Pitch
            _buildSlider(
              title: 'Pitch',
              value: _pitch,
              min: 0.5,
              max: 2.0,
              onChanged: (value) {
                setState(() {
                  _pitch = value;
                });
                _updateTtsSettings(navigationLogic);
              },
              label: _pitch.toStringAsFixed(1),
            ),
            const SizedBox(height: 20),
            // TTS Volume
            _buildSlider(
              title: 'Volume',
              value: _volume,
              min: 0.0,
              max: 1.0,
              onChanged: (value) {
                setState(() {
                  _volume = value;
                });
                _updateTtsSettings(navigationLogic);
              },
              label: _volume.toStringAsFixed(1),
            ),
            const SizedBox(height: 20),
            // Alert Cooldown
            _buildSlider(
              title: 'Alert Cooldown (seconds)',
              value: _alertCooldown,
              min: 1.0,
              max: 5.0,
              onChanged: (value) {
                setState(() {
                  _alertCooldown = value;
                });
                _updateTtsSettings(navigationLogic);
              },
              label: _alertCooldown.toStringAsFixed(1),
            ),
            const SizedBox(height: 20),
            // Haptic Feedback Toggle
            _buildToggle(
              title: 'Haptic Feedback',
              value: _isHapticFeedback,
              onChanged: (value) {
                setState(() {
                  _isHapticFeedback = value;
                });
                navigationLogic.isHapticFeedback = value; 
              },
            ),
            const SizedBox(height: 20),
            // Test TTS Button
            ElevatedButton(
              onPressed: () {
                navigationLogic.tts.speak('This is a test announcement.');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Test TTS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  _resetToDefault(navigationLogic);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent, // Distinct color for reset
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Reset to Default',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                _saveSettings();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Settings saved')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Save Settings',
                style: TextStyle(
                  color: Colors.black,
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