import 'package:flutter/material.dart';
import 'package:roqqu_kyc/roqqu_kyc.dart';
import 'mock_api_client.dart';
import 'kyc_flow.dart';

void main() {
  // Initialize SDK with Mock Client for Demo
  final config = KycConfig(
    clearnessThreshold: 750,
    clearnessLowerThreshold: 450,
    livenessThreshold: 0.2,
    enableAntispoofing: true,
    maxFrameCount: 3,
    framePassPercentage: 0.6,
    debugMode: true, // Enable debug controls for demo
    kycTestEmails: [],
  );

  RoqquKycSdk().initialize(config: config, apiClient: MockKycApiClient());

  runApp(const KycExampleApp());
}

class KycExampleApp extends StatelessWidget {
  const KycExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Roqqu KYC SDK Example',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C5CE7),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const IntroPage(),
    );
  }
}

// -----------------------------------------------------------------------------
// 1. Intro Page & Delegate Implementation
// -----------------------------------------------------------------------------
class IntroPage extends StatefulWidget {
  const IntroPage({super.key});

  @override
  State<IntroPage> createState() => _IntroPageState();
}

class _IntroPageState extends State<IntroPage> implements KycDelegate {
  void _startVerification() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => KycVerificationFlow(
          config: RoqquKycSdk().config,
          apiClient: RoqquKycSdk().apiClient,
          delegate: this,
        ),
      ),
    );
  }

  // --- Delegate Callbacks ---

  @override
  void onVerified(KycSession session) {
    // SDK Flow finished successfully
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => ResultPage(session: session)),
    );
  }

  @override
  void onError(Object error) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Verification Error: $error')));
  }

  @override
  void onPending(String message) {
    Navigator.of(context).pop(); // Close SDK flow
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Verification Pending/Cancelled: $message')),
    );
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.verified_user,
                size: 80,
                color: Color(0xFF6C5CE7),
              ),
              const SizedBox(height: 24),
              Text(
                'KYC SDK',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Identity Verification Demo',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 48),
              FilledButton.icon(
                onPressed: _startVerification,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start Verification'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 2. Result Page (Application Side)
// -----------------------------------------------------------------------------
class ResultPage extends StatelessWidget {
  final KycSession session;
  const ResultPage({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verification Result')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Spacer(),
            const Icon(Icons.check_circle, size: 100, color: Colors.green),
            const SizedBox(height: 24),
            Text(
              'Verification Successful!',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Your liveness check is complete.',
              style: TextStyle(color: Colors.white70),
            ),
            const Spacer(),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _row('Session ID', session.sessionId),
                    const Divider(),
                    _row('Token', session.token), // Just show beginning
                    const Divider(),
                    _row(
                      'Expires',
                      session.expiry
                          .toIso8601String()
                          .split('T')
                          .last
                          .split('.')
                          .first,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const IntroPage()),
                    (route) => false,
                  );
                },
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
