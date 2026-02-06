import 'package:flutter/material.dart';

import 'liveness_screen.dart';
import 'standalone_detection_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KycEngineExampleApp());
}

class KycEngineExampleApp extends StatelessWidget {
  const KycEngineExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KYC Engine Example',
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('KYC Engine Example')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 32),
            const Text(
              'Select a demo to see the kyc_engine plugin in action.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            FilledButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const LivenessScreen(),
                ),
              ),
              icon: const Icon(Icons.face),
              label: const Text('Full Liveness Flow'),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const StandaloneDetectionScreen(),
                ),
              ),
              icon: const Icon(Icons.search),
              label: const Text('Standalone Face Detection'),
            ),
          ],
        ),
      ),
    );
  }
}
