import 'package:flutter/material.dart';
import 'package:roqqu_kyc/roqqu_kyc.dart';

void main() {
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
      home: const KycDemoScreen(),
    );
  }
}

class KycDemoScreen extends StatefulWidget {
  const KycDemoScreen({super.key});

  @override
  State<KycDemoScreen> createState() => _KycDemoScreenState();
}

class _KycDemoScreenState extends State<KycDemoScreen> {
  // SDK Configuration
  KycConfig _config = KycConfig(
    clearnessThreshold: 750,
    clearnessLowerThreshold: 450,
    livenessThreshold: 0.2,
    enableAntispoofing: true,
    maxFrameCount: 3,
    framePassPercentage: 0.6,
    debugMode: false,
    kycTestEmails: [],
  );

  // Current stage simulation
  KycFaceRecognitionStage _currentStage = KycFaceRecognitionStage.initial;

  // Selected document type
  KycAllowedId _selectedDoc = KycAllowedId.internationalPassport;

  void _nextStage() {
    final next = KycFaceRecognitionStage.getNextStep(_currentStage.step);
    if (next != null) {
      setState(() => _currentStage = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Roqqu KYC SDK Demo'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Config Section
            _buildSection(
              'SDK Configuration',
              child: Column(
                children: [
                  _buildConfigRow(
                    'Clearness Threshold',
                    '${_config.clearnessThreshold}',
                  ),
                  _buildConfigRow(
                    'Clearness Lower',
                    '${_config.clearnessLowerThreshold}',
                  ),
                  _buildConfigRow(
                    'Liveness Threshold',
                    '${_config.livenessThreshold}',
                  ),
                  _buildConfigRow(
                    'Anti-Spoofing',
                    _config.isAntispoofingEnabled ? 'Enabled' : 'Disabled',
                  ),
                  _buildConfigRow(
                    'Debug Mode',
                    _config.debugMode ? 'On' : 'Off',
                  ),
                  _buildConfigRow(
                    'Can Test KYC',
                    _config.canTestKyc ? 'Yes' : 'No',
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _config = _config.copyWith(
                          debugMode: !_config.debugMode,
                        );
                      });
                    },
                    icon: const Icon(Icons.settings),
                    label: const Text('Toggle Debug Mode'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Face Recognition Stage
            _buildSection(
              'Face Recognition Stage',
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _currentStage.label.toUpperCase().replaceAll(
                            '_',
                            ' ',
                          ),
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: _currentStage.progress,
                          backgroundColor: Colors.white24,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Step ${_currentStage.step} of ${KycFaceRecognitionStage.values.length - 1}',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(
                              () => _currentStage =
                                  KycFaceRecognitionStage.initial,
                            );
                          },
                          child: const Text('Reset'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed:
                              _currentStage != KycFaceRecognitionStage.done
                              ? _nextStage
                              : null,
                          child: const Text('Next Stage'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Document Types
            _buildSection(
              'Allowed Document Types',
              child: Column(
                children: KycAllowedId.values.map((doc) {
                  return RadioListTile<KycAllowedId>(
                    title: Text(doc.title),
                    subtitle: Text('Key: ${doc.key}'),
                    value: doc,
                    groupValue: _selectedDoc,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedDoc = value);
                      }
                    },
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 24),

            // Verification States
            _buildSection(
              'Verification States',
              child: Column(
                children: KycVerificationState.values.map((state) {
                  return ListTile(
                    leading: CircleAvatar(child: Text('${state.step}')),
                    title: Text(state.label.replaceAll('_', ' ').toUpperCase()),
                    dense: true,
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, {required Widget child}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Divider(),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildConfigRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
