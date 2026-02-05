import 'package:flutter/material.dart';
import 'package:roqqu_kyc/roqqu_kyc.dart';
import 'mock_api_client.dart';

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
      home: const IntroPage(),
    );
  }
}

class IntroPage extends StatelessWidget {
  const IntroPage({super.key});

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
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const SessionCreationPage(),
                    ),
                  );
                },
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

class SessionCreationPage extends StatefulWidget {
  const SessionCreationPage({super.key});

  @override
  State<SessionCreationPage> createState() => _SessionCreationPageState();
}

class _SessionCreationPageState extends State<SessionCreationPage> {
  final KycApiClient _apiClient = MockKycApiClient();
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _createSession();
  }

  Future<void> _createSession() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final session = await _apiClient.createSession(
        email: 'demo@roqqu.com',
        userId: 'demo_user_123',
      );

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => LivenessCheckPage(session: session),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to create session. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Initializing...')),
      body: Center(
        child: _isLoading
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Creating Secure Session...'),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 16),
                  Text(_error ?? 'Unknown Error'),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _createSession,
                    child: const Text('Retry'),
                  ),
                ],
              ),
      ),
    );
  }
}

class LivenessCheckPage extends StatefulWidget {
  final KycSession session;
  const LivenessCheckPage({super.key, required this.session});

  @override
  State<LivenessCheckPage> createState() => _LivenessCheckPageState();
}

class _LivenessCheckPageState extends State<LivenessCheckPage> {
  late LivenessCheckService _service;
  KycDetectedFace _simulatedFace = KycDetectedFace.initial();

  bool _showDebugControls = true;

  @override
  void initState() {
    super.initState();
    _service = LivenessCheckService();
    _service.start();
  }

  void _processFrame() async {
    for (int i = 0; i < 5; i++) {
      if (!mounted) return;

      setState(() {
        _service.process(_simulatedFace, false);
      });

      if (_service.currentStage == KycFaceRecognitionStage.done) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => ResultPage(session: widget.session),
            ),
          );
        });
        return;
      }

      await Future.delayed(const Duration(milliseconds: 30));
    }
  }

  String _getStageLabel(KycFaceRecognitionStage stage) {
    switch (stage) {
      case KycFaceRecognitionStage.initial:
        return 'FACE WITHIN';
      case KycFaceRecognitionStage.detectFace:
        return 'DETECTING FACE';
      case KycFaceRecognitionStage.tiltLeft:
        return 'MOVE FACE LEFT';
      case KycFaceRecognitionStage.tiltRight:
        return 'MOVE FACE RIGHT';
      case KycFaceRecognitionStage.smile:
        return 'NOW SMILE';
      case KycFaceRecognitionStage.mouthOpen:
        return 'OPEN MOUTH';
      case KycFaceRecognitionStage.stayStill:
        return 'STAY STILL';
      case KycFaceRecognitionStage.done:
        return 'DONE';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: Icon(
              Icons.face,
              size: 150,
              color: Colors.white.withOpacity(0.1),
            ),
          ),

          if (_showDebugControls)
            Positioned(
              top: 50,
              left: 20,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SIMULATED FACE STATE:',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                    _statusRow('Found', _simulatedFace.faceFound),
                    _statusRow('Smiling', _simulatedFace.isSmiling),
                    _statusRow('Mouth Open', _simulatedFace.isMouthOpen),
                    _statusRow('Left', _simulatedFace.turnedLeft),
                    _statusRow('Right', _simulatedFace.turnedRight),
                  ],
                ),
              ),
            ),

          Align(
            alignment: Alignment.topCenter,
            child: SafeArea(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.only(
                  top: 60,
                  left: 24,
                  right: 24,
                  bottom: 24,
                ),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black87, Colors.transparent],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _getStageLabel(_service.currentStage),
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Step ${_service.currentStage.step} of ${KycFaceRecognitionStage.values.length - 1}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 16),
                    LinearProgressIndicator(
                      value: _service.currentStage.progress,
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF6C5CE7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (_showDebugControls)
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                margin: const EdgeInsets.only(bottom: 20, left: 16, right: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SIMULATION CONTROLS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _simBtn('Reset', KycDetectedFace.initial()),
                        _simBtn('Smile', _mockFace(isSmiling: true)),
                        _simBtn('Mouth Open', _mockFace(isMouthOpen: true)),
                        _simBtn('Left', _mockFace(turnedLeft: true)),
                        _simBtn('Right', _mockFace(turnedRight: true)),
                        _simBtn('Neutral', _mockFace(isWellPositioned: true)),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              actions: [
                IconButton(
                  icon: Icon(
                    _showDebugControls
                        ? Icons.bug_report
                        : Icons.bug_report_outlined,
                  ),
                  onPressed: () =>
                      setState(() => _showDebugControls = !_showDebugControls),
                  tooltip: 'Toggle Debug Controls',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusRow(String label, bool active) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            active ? Icons.circle : Icons.circle_outlined,
            size: 8,
            color: active ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : Colors.white54,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _simBtn(String label, KycDetectedFace face) {
    bool isActive = _simulatedFace == face;
    return GestureDetector(
      onTap: () {
        setState(() => _simulatedFace = face);
        _processFrame();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF6C5CE7) : Colors.white10,
          borderRadius: BorderRadius.circular(20),
          border: isActive ? Border.all(color: Colors.white30) : null,
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  KycDetectedFace _mockFace({
    bool isSmiling = false,
    bool turnedLeft = false,
    bool turnedRight = false,
    bool isMouthOpen = false,
    bool isWellPositioned = false,
  }) {
    return KycDetectedFace(
      face: null,
      faceIsWellPositioned: isWellPositioned,
      isSmiling: isSmiling,
      isFrowning: false,
      turnedLeft: turnedLeft,
      turnedRight: turnedRight,
      lookingAway: false,
      isBlinking: false,
      isMouthOpen: isMouthOpen,
      isNodding: false,
      isFaceCloseEnough: true,
      feedback: KycFeedback.none,
    );
  }
}

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
