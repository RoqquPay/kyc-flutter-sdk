import 'package:flutter/material.dart';
import 'package:roqqu_kyc/roqqu_kyc.dart';

class KycVerificationFlow extends StatefulWidget {
  final KycConfig config;
  final KycDelegate delegate;
  final KycApiClient? apiClient;
  final KycSession? session;

  const KycVerificationFlow({
    super.key,
    required this.config,
    required this.delegate,
    this.apiClient,
    this.session,
  });

  @override
  State<KycVerificationFlow> createState() => _KycVerificationFlowState();
}

class _KycVerificationFlowState extends State<KycVerificationFlow> {
  KycSession? _session;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.session != null) {
      _session = widget.session;
    } else {
      _createSession();
    }
  }

  Future<void> _createSession() async {
    if (widget.apiClient == null) {
      if (mounted) setState(() => _error = "No API Client provided");
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // In real app, userId/email would come from config or separate params
      final session = await widget.apiClient!.createSession(
        email: 'sdk_auto@roqqu.com',
        userId: 'sdk_user',
      );
      if (mounted) {
        setState(() {
          _session = session;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Verification Error')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(_error!),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _createSession,
                child: const Text('Retry'),
              ),
              TextButton(
                onPressed: () => widget.delegate.onError(_error!),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoading || _session == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return _SdkLivenessPage(
      session: _session!,
      delegate: widget.delegate,
      config: widget.config,
    );
  }
}

// Internal Liveness Page (Based on Example App implementation)
class _SdkLivenessPage extends StatefulWidget {
  final KycSession session;
  final KycDelegate delegate;
  final KycConfig config;

  const _SdkLivenessPage({
    required this.session,
    required this.delegate,
    required this.config,
  });

  @override
  State<_SdkLivenessPage> createState() => _SdkLivenessPageState();
}

class _SdkLivenessPageState extends State<_SdkLivenessPage> {
  late LivenessCheckService _service;
  KycDetectedFace _simulatedFace = KycDetectedFace.initial();
  bool _showDebugControls = false;

  @override
  void initState() {
    super.initState();
    _service = LivenessCheckService();
    _service.start();
    // Enable debug controls if config says so
    _showDebugControls = widget.config.debugMode;
  }

  void _processFrame() async {
    // Burst simulation for robustness
    for (int i = 0; i < 5; i++) {
      if (!mounted) return;
      setState(() {
        _service.process(_simulatedFace, false);
      });
      if (_service.currentStage == KycFaceRecognitionStage.done) {
        widget.delegate.onVerified(widget.session);
        return;
      }
      await Future.delayed(const Duration(milliseconds: 30));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera Placeholder (Real camera integration would go here)
          Center(
            child: Icon(
              Icons.face,
              size: 100,
              color: Colors.white.withValues(alpha: 0.1),
            ),
          ),

          // Instructions (Top)
          Align(
            alignment: Alignment.topCenter,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.only(top: 40, left: 24, right: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _service.currentStage.label.toUpperCase().replaceAll(
                        '_',
                        ' ',
                      ),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: _service.currentStage.progress,
                      color: const Color(0xFF6C5CE7),
                      backgroundColor: Colors.white24,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Debug Controls
          if (_showDebugControls)
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                color: Colors.black87,
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _btn('Reset', KycDetectedFace.initial()),
                    _btn(
                      'Smile',
                      KycDetectedFace.initial().copyWith(isSmiling: true),
                    ),
                    _btn(
                      'Left',
                      KycDetectedFace.initial().copyWith(turnedLeft: true),
                    ),
                    _btn(
                      'Right',
                      KycDetectedFace.initial().copyWith(turnedRight: true),
                    ),
                    _btn(
                      'Open Mouth',
                      KycDetectedFace.initial().copyWith(isMouthOpen: true),
                    ),
                  ],
                ),
              ),
            ),

          // Close Button
          Positioned(
            top: 40,
            right: 16,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => widget.delegate.onPending('User cancelled'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _btn(String label, KycDetectedFace face) {
    return GestureDetector(
      onTap: () {
        setState(() => _simulatedFace = face);
        _processFrame();
      },
      child: Chip(label: Text(label)),
    );
  }
}
