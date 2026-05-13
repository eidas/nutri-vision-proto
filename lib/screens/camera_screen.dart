import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../models/nutrition_data.dart';
import '../models/ocr_block.dart';
import '../parser/label_parser.dart';
import '../services/ocr_service.dart';
import '../widgets/scan_overlay_painter.dart';
import 'result_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key, required this.cameras});
  final List<CameraDescription> cameras;

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with TickerProviderStateMixin {
  CameraController? _controller;
  bool _isProcessing = false;
  bool _confirmed = false;
  List<OcrBlock> _lastBlocks = [];
  NutritionData? _bestResult;
  Timer? _scanTimer;

  late final AnimationController _bracketAnim =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
        ..repeat(reverse: true);

  // How often to send a frame for OCR (ms)
  static const _scanIntervalMs = 1200;

  // Minimum confidence to trigger auto-confirm
  static const _autoConfirmThreshold = 0.8;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    if (widget.cameras.isEmpty) return;

    // Prefer rear camera
    final camera = widget.cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => widget.cameras.first,
    );

    final controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    await controller.initialize();
    if (!mounted) return;

    setState(() => _controller = controller);
    _startScanLoop();
  }

  void _startScanLoop() {
    _scanTimer = Timer.periodic(
      const Duration(milliseconds: _scanIntervalMs),
      (_) => _scanFrame(),
    );
  }

  Future<void> _scanFrame() async {
    if (_isProcessing || _confirmed) return;
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    _isProcessing = true;
    try {
      final file = await controller.takePicture();
      final bytes = await file.readAsBytes();

      final blocks = await OcrService.instance.recognizeText(
        jpegBytes: bytes,
        rotation: _rotationDegrees(controller.description.sensorOrientation),
      );

      if (!mounted) return;

      final result = LabelParser.instance.parse(blocks);

      setState(() {
        _lastBlocks = blocks;
        // Keep the best result seen so far
        if (_bestResult == null ||
            result.confidence > (_bestResult?.confidence ?? 0)) {
          _bestResult = result;
        }
      });

      if (result.confidence >= _autoConfirmThreshold && !_confirmed) {
        _autoConfirm(result);
      }
    } catch (_) {
      // OCR errors are non-fatal; next tick will retry
    } finally {
      _isProcessing = false;
    }
  }

  void _autoConfirm(NutritionData data) {
    if (_confirmed) return;
    setState(() => _confirmed = true);
    _scanTimer?.cancel();

    // Brief delay so the user sees the "detected" banner
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      _navigateToResult(data);
    });
  }

  void _manualCapture() {
    final result = _bestResult;
    if (result == null) return;
    _scanTimer?.cancel();
    _navigateToResult(result);
  }

  Future<void> _navigateToResult(NutritionData data) async {
    // Await pop so OCR does not run while the result screen is visible,
    // and auto-confirm cannot fire a second push in the background.
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ResultScreen(data: data)),
    );
    if (!mounted) return;
    // Reset and resume only after the user returns to this screen.
    setState(() {
      _confirmed = false;
      _bestResult = null;
      _lastBlocks = [];
    });
    _startScanLoop();
  }

  int _rotationDegrees(int sensorOrientation) {
    // Android ML Kit needs the rotation; iOS Vision handles it internally.
    return sensorOrientation;
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    _bracketAnim.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final confidence = _bestResult?.confidence ?? 0.0;
    final format = _bestResult?.format;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Camera preview ──────────────────────────────────────────────
          CameraPreview(controller),

          // ── Scan overlay ────────────────────────────────────────────────
          AnimatedBuilder(
            animation: _bracketAnim,
            builder: (_, __) => CustomPaint(
              painter: ScanOverlayPainter(
                blocks: _lastBlocks,
                confidence: confidence,
                animValue: _bracketAnim.value,
              ),
            ),
          ),

          // ── Top bar ──────────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const BackButton(color: Colors.white),
                  const Spacer(),
                  if (format != null)
                    _FormatBadge(format: format),
                ],
              ),
            ),
          ),

          // ── Progress + instruction ───────────────────────────────────────
          Positioned(
            bottom: 140,
            left: 24,
            right: 24,
            child: Column(
              children: [
                if (_confirmed)
                  const _DetectedBanner()
                else
                  _ProgressIndicator(confidence: confidence),
              ],
            ),
          ),

          // ── Manual capture button ────────────────────────────────────────
          if (!_confirmed)
            Positioned(
              bottom: 48,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: _manualCapture,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                    ),
                    child: Container(
                      margin: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _FormatBadge extends StatelessWidget {
  const _FormatBadge({required this.format});
  final LabelFormat format;

  @override
  Widget build(BuildContext context) {
    final label = switch (format) {
      LabelFormat.jp      => '日本',
      LabelFormat.fda     => 'FDA',
      LabelFormat.eu      => 'EU',
      LabelFormat.unknown => '?',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white30),
      ),
      child: Text(label,
          style: const TextStyle(color: Colors.white, fontSize: 12)),
    );
  }
}

class _ProgressIndicator extends StatelessWidget {
  const _ProgressIndicator({required this.confidence});
  final double confidence;

  @override
  Widget build(BuildContext context) {
    final pct = (confidence * 100).toInt();
    return Column(
      children: [
        Text(
          confidence == 0
              ? '栄養成分表示にカメラを向けてください'
              : '読み取り中… $pct%',
          style: const TextStyle(color: Colors.white, fontSize: 14),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: confidence,
          backgroundColor: Colors.white24,
          valueColor:
              AlwaysStoppedAnimation(Color.lerp(Colors.orange, Colors.greenAccent, confidence)!),
          minHeight: 4,
          borderRadius: BorderRadius.circular(2),
        ),
      ],
    );
  }
}

class _DetectedBanner extends StatelessWidget {
  const _DetectedBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.greenAccent.withOpacity(0.9),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, color: Colors.black87),
          SizedBox(width: 8),
          Text('栄養成分表を検出',
              style: TextStyle(
                  color: Colors.black87, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
