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

  // Liveness Check Service
  final LivenessCheckService _livenessCheckService = LivenessCheckService();

  // Current stage simulation (driven by manager)
  KycFaceRecognitionStage get _currentStage =>
      _livenessCheckService.currentStage;

  @override
  void initState() {
    super.initState();
    _livenessCheckService.start();
  }

  // Selected document type
  KycAllowedId _selectedDoc = KycAllowedId.internationalPassport;

  void _processFrame() {
    setState(() {
      _livenessCheckService.process(_simulatedFace, false);
    });
  }

  void _reset() {
    setState(() {
      _livenessCheckService.start();
      _simulatedFace = KycDetectedFace.initial();
    });
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
            // Face Recognition Stage - Live View Simulation
            Container(
              height: 300,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Stack(
                children: [
                  // Mock Camera Feed/Placeholder
                  Center(
                    child: Icon(
                      Icons.face,
                      size: 100,
                      color: Colors.white.withOpacity(0.3),
                    ),
                  ),

                  // Instruction Overlay
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.transparent, Colors.black87],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.vertical(
                          bottom: Radius.circular(16),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _currentStage.label.toUpperCase().replaceAll(
                              '_',
                              ' ',
                            ),
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Step ${_currentStage.step} of ${KycFaceRecognitionStage.values.length - 1}',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 16),
                          LinearProgressIndicator(
                            value: _currentStage.progress,
                            backgroundColor: Colors.white24,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF6C5CE7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Reset Button (Top Right)
                  Positioned(
                    top: 16,
                    right: 16,
                    child: IconButton.filledTonal(
                      onPressed: _reset,
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Reset Flow',
                    ),
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

            const SizedBox(height: 24),

            // Face Detection Simulation
            _buildSection(
              'Face Detection Simulation (Mock)',
              child: Column(
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildSimButton('No Face', KycDetectedFace.initial()),
                      _buildSimButton(
                        'Smiling',
                        _createMockFace(isSmiling: true),
                      ),
                      _buildSimButton(
                        'Turn Left',
                        _createMockFace(turnedLeft: true),
                      ),
                      _buildSimButton(
                        'Turn Right',
                        _createMockFace(turnedRight: true),
                      ),
                      _buildSimButton(
                        'Blinking',
                        _createMockFace(isBlinking: true),
                      ),
                      _buildSimButton(
                        'Good Face',
                        _createMockFace(isWellPositioned: true),
                      ),
                    ],
                  ),
                  const Divider(),
                  const Text('Detected Attributes:'),
                  const SizedBox(height: 8),
                  _buildAttributeRow('Face Found', _simulatedFace.faceFound),
                  _buildAttributeRow(
                    'Well Positioned',
                    _simulatedFace.faceIsWellPositioned,
                  ),
                  _buildAttributeRow('Smiling', _simulatedFace.isSmiling),
                  _buildAttributeRow('Turned Left', _simulatedFace.turnedLeft),
                  _buildAttributeRow(
                    'Turned Right',
                    _simulatedFace.turnedRight,
                  ),
                  _buildAttributeRow('Blinking', _simulatedFace.isBlinking),
                  _buildAttributeRow('Mouth Open', _simulatedFace.isMouthOpen),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Simulation State
  KycDetectedFace _simulatedFace = KycDetectedFace.initial();

  KycDetectedFace _createMockFace({
    bool isSmiling = false,
    bool turnedLeft = false,
    bool turnedRight = false,
    bool isBlinking = false,
    bool isWellPositioned = false,
  }) {
    // We can't easily instantiate a real 'Face' object here without ml_kit dependency directly
    // but KycDetectedFace takes a Face? which can be null for mock visualization
    // IF we trust the flags.
    // However, KycDetectedFace.initial() sets face=null.
    // Our service sets these boolean flags based on the Face.
    // For simulation, we just want to create a KycDetectedFace with specific flags.
    // But KycDetectedFace constructor requires all fields.
    return KycDetectedFace(
      face: null, // Mock doesn't have a real Face object
      faceIsWellPositioned: isWellPositioned,
      isSmiling: isSmiling,
      isFrowning: false,
      turnedLeft: turnedLeft,
      turnedRight: turnedRight,
      lookingAway: false,
      isBlinking: isBlinking,
      isMouthOpen: false,
      isNodding: false,
      isFaceCloseEnough: true,
    );
  }

  Widget _buildSimButton(String label, KycDetectedFace face) {
    return ActionChip(
      label: Text(label),
      onPressed: () {
        setState(() => _simulatedFace = face);
        _processFrame();
      },
      backgroundColor: _simulatedFace == face
          ? Theme.of(context).colorScheme.primaryContainer
          : null,
    );
  }

  Widget _buildAttributeRow(String label, bool value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            value ? Icons.check_circle : Icons.cancel,
            color: value ? Colors.green : Colors.grey,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: value
                  ? Theme.of(context).colorScheme.onSurface
                  : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              fontWeight: value ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
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
