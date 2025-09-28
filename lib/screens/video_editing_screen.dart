import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';
import '../utils/video_helper.dart';
import '../utils/toast_helper.dart';

class VideoEditingScreen extends StatefulWidget {
  final String videoPath;

  const VideoEditingScreen({super.key, required this.videoPath});

  @override
  State<VideoEditingScreen> createState() => _VideoEditingScreenState();
}

class _VideoEditingScreenState extends State<VideoEditingScreen> {
  late VideoPlayerController _controller;

  // Video editing parameters
  Duration _startTime = Duration.zero;
  Duration _endTime = Duration.zero;
  double _brightness = 0.0; // -50 to +50
  double _contrast = 1.0; // 0.5 to 2.0
  int _rotationAngle = 0; // 0, 90, 180, 270

  // Crop parameters
  Rect _cropRect =
      const Rect.fromLTWH(0.0, 0.0, 1.0, 1.0); // Normalized coordinates
  bool _isCropMode = false;
  bool _isDragging = false;
  String _dragHandle = '';

  // UI state
  bool _isLoading = true;
  bool _isPlaying = false;
  bool _isExporting = false;
  double _exportProgress = 0.0;

  // Video metadata
  bool _isProcessedVideo = false;
  String? _originalVideoPath;
  List<Map<String, dynamic>> _editHistory = [];

  @override
  void initState() {
    super.initState();
    _initializeVideo();
    _loadVideoMetadata();
  }

  Future<void> _initializeVideo() async {
    try {
      _controller = VideoPlayerController.file(File(widget.videoPath));
      await _controller.initialize();

      setState(() {
        _endTime = _controller.value.duration;
        _isLoading = false;
      });

      // Listen to video position changes
      _controller.addListener(() {
        if (mounted && _controller.value.isPlaying) {
          setState(() {});
        }
      });
    } catch (e) {
      if (mounted) {
        ToastHelper.showError('Failed to load video: $e');
        Navigator.pop(context);
      }
    }
  }

  Future<void> _loadVideoMetadata() async {
    try {
      final isProcessed = await VideoHelper.isProcessedVideo(widget.videoPath);
      final originalPath =
          await VideoHelper.getOriginalVideoPath(widget.videoPath);
      final history = await VideoHelper.getVideoEditHistory(widget.videoPath);

      setState(() {
        _isProcessedVideo = isProcessed;
        _originalVideoPath = originalPath;
        _editHistory = history;
      });

      debugPrint('📊 Video metadata loaded:');
      debugPrint('- Is processed: $isProcessed');
      debugPrint('- Original path: $originalPath');
      debugPrint('- Edit history: ${history.length} entries');
    } catch (e) {
      debugPrint('⚠️ Failed to load video metadata: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Format duration for display
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  // Play/Pause toggle
  void _togglePlayPause() {
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
        _isPlaying = false;
      } else {
        _controller.play();
        _isPlaying = true;
      }
    });
  }

  // Rotate video
  void _rotateVideo() {
    setState(() {
      _rotationAngle = (_rotationAngle + 90) % 360;
    });
  }

  // Toggle crop mode
  void _toggleCropMode() {
    setState(() {
      _isCropMode = !_isCropMode;
      if (!_isCropMode) {
        // Reset crop when exiting crop mode
        _cropRect = const Rect.fromLTWH(0.0, 0.0, 1.0, 1.0);
      }
    });
  }

  // Reset crop to full frame
  void _resetCrop() {
    setState(() {
      _cropRect = const Rect.fromLTWH(0.0, 0.0, 1.0, 1.0);
    });
  }

  // Handle crop area updates
  void _updateCropRect(Rect newRect) {
    // Ensure crop rect stays within bounds
    final left = newRect.left.clamp(0.0, 1.0);
    final top = newRect.top.clamp(0.0, 1.0);
    final right = newRect.right.clamp(0.0, 1.0);
    final bottom = newRect.bottom.clamp(0.0, 1.0);

    // Ensure minimum size
    const minSize = 0.1;
    final width = (right - left).clamp(minSize, 1.0 - left);
    final height = (bottom - top).clamp(minSize, 1.0 - top);

    setState(() {
      _cropRect = Rect.fromLTWH(left, top, width, height);
    });
  }

  // Save edited video
  Future<void> _saveEditedVideo() async {
    if (_isExporting) return;

    setState(() {
      _isExporting = true;
      _exportProgress = 0.0;
    });

    try {
      // Show progress
      _simulateProgress();

      // Apply crop only if in crop mode and not full frame
      final cropToApply = _isCropMode &&
              (_cropRect.left > 0.01 ||
                  _cropRect.top > 0.01 ||
                  _cropRect.width < 0.99 ||
                  _cropRect.height < 0.99)
          ? _cropRect
          : null;

      final success = await VideoHelper.saveEditedVideo(
        inputPath: widget.videoPath,
        startTime: _startTime,
        endTime: _endTime,
        brightness: _brightness,
        contrast: _contrast,
        rotationAngle: _rotationAngle,
        cropRect: cropToApply,
      );

      if (success) {
        ToastHelper.showSuccess('Video saved successfully!');
        if (mounted) {
          Navigator.pop(context, true); // Return true to indicate success
        }
      } else {
        ToastHelper.showError('Failed to save video');
      }
    } catch (e) {
      ToastHelper.showError('Error saving video: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
          _exportProgress = 0.0;
        });
      }
    }
  }

  // Simulate export progress
  void _simulateProgress() {
    const totalSteps = 20;
    int currentStep = 0;

    void updateProgress() {
      if (currentStep < totalSteps && _isExporting) {
        setState(() {
          _exportProgress = currentStep / totalSteps;
        });
        currentStep++;
        Future.delayed(const Duration(milliseconds: 150), updateProgress);
      } else if (_isExporting) {
        setState(() {
          _exportProgress = 1.0;
        });
      }
    }

    updateProgress();
  }

  // Show video information dialog
  void _showVideoInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Row(
          children: [
            Icon(
              _isProcessedVideo ? Icons.edit : Icons.videocam,
              color: _isProcessedVideo ? Colors.blue : Colors.green,
            ),
            const SizedBox(width: 8),
            Text(
              _isProcessedVideo ? 'Edited Video' : 'Original Video',
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isProcessedVideo) ...[
              const Text(
                'This video has been edited:',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 12),
              if (_originalVideoPath != null) ...[
                const Text(
                  '📹 Original Source:',
                  style: TextStyle(
                      color: Colors.blue, fontWeight: FontWeight.bold),
                ),
                Text(
                  _originalVideoPath!.split('/').last,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 12),
              ],
              if (_editHistory.isNotEmpty) ...[
                const Text(
                  '✨ Applied Edits:',
                  style: TextStyle(
                      color: Colors.blue, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ..._buildEditHistoryWidgets(),
              ],
            ] else ...[
              const Text(
                'This is an original video file. You can apply edits like crop, rotation, brightness, and contrast.',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildEditHistoryWidgets() {
    List<Widget> widgets = [];

    for (final edit in _editHistory) {
      if (edit['cropRect'] != null) {
        widgets.add(
          const Row(
            children: [
              Icon(Icons.crop, color: Colors.green, size: 16),
              SizedBox(width: 8),
              Text('Cropped', style: TextStyle(color: Colors.white70)),
            ],
          ),
        );
      }

      if (edit['rotationAngle'] != 0) {
        widgets.add(
          Row(
            children: [
              const Icon(Icons.rotate_90_degrees_ccw,
                  color: Colors.orange, size: 16),
              const SizedBox(width: 8),
              Text(
                'Rotated ${edit['rotationAngle']}°',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        );
      }

      if (edit['brightness'] != 0.0) {
        widgets.add(
          Row(
            children: [
              const Icon(Icons.brightness_6, color: Colors.yellow, size: 16),
              const SizedBox(width: 8),
              Text(
                'Brightness ${edit['brightness'] > 0 ? '+' : ''}${edit['brightness'].toStringAsFixed(1)}',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        );
      }

      if (edit['contrast'] != 1.0) {
        widgets.add(
          Row(
            children: [
              const Icon(Icons.contrast, color: Colors.purple, size: 16),
              const SizedBox(width: 8),
              Text(
                'Contrast ${edit['contrast'].toStringAsFixed(1)}',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        );
      }
    }

    return widgets
        .map((w) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: w,
            ))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          iconTheme: const IconThemeData(color: Colors.white),
          title:
              const Text('Loading...', style: TextStyle(color: Colors.white)),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Colors.blue),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          _isCropMode ? 'Crop Video' : 'Edit Video',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          // Show video info button
          IconButton(
            onPressed: _showVideoInfo,
            icon: Icon(
              _isProcessedVideo ? Icons.history : Icons.info_outline,
              color: _isProcessedVideo ? Colors.blue : Colors.white,
            ),
          ),
          if (_isCropMode)
            TextButton(
              onPressed: _resetCrop,
              child: const Text('Reset', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: Column(
        children: [
          // Video preview area
          Expanded(
            child: Container(
              width: double.infinity,
              color: Colors.black,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Video player
                  Transform.rotate(
                    angle: _rotationAngle * (3.14159 / 180),
                    child: ColorFiltered(
                      colorFilter: ColorFilter.matrix(_getColorMatrix()),
                      child: AspectRatio(
                        aspectRatio: _controller.value.aspectRatio,
                        child: VideoPlayer(_controller),
                      ),
                    ),
                  ),

                  // Crop overlay
                  if (_isCropMode)
                    Positioned.fill(
                      child: CropOverlay(
                        cropRect: _cropRect,
                        onCropUpdate: _updateCropRect,
                      ),
                    ),

                  // Play/Pause button
                  if (!_isCropMode)
                    Center(
                      child: GestureDetector(
                        onTap: _togglePlayPause,
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: Icon(
                            _isPlaying ? Icons.pause : Icons.play_arrow,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                      ),
                    ),

                  // Export progress overlay
                  if (_isExporting)
                    Container(
                      color: Colors.black87,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: _exportProgress,
                              color: Colors.blue,
                              strokeWidth: 6,
                            ),
                            const SizedBox(height: 20),
                            Text(
                              '${(_exportProgress * 100).round()}% Complete',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 16),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Processing video...',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Controls area
          Container(
            color: Colors.grey[900],
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Crop info (when in crop mode)
                if (_isCropMode)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          '🔲 Crop Area',
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Text(
                              'X: ${(_cropRect.left * 100).round()}%',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12),
                            ),
                            Text(
                              'Y: ${(_cropRect.top * 100).round()}%',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12),
                            ),
                            Text(
                              'W: ${(_cropRect.width * 100).round()}%',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12),
                            ),
                            Text(
                              'H: ${(_cropRect.height * 100).round()}%',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Drag corners to resize • Drag center to move',
                          style: TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                      ],
                    ),
                  ),

                // Main control buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Crop button
                    _buildControlButton(
                      icon: Icons.crop,
                      label: _isCropMode ? 'Apply' : 'Crop',
                      onPressed: _toggleCropMode,
                      isActive: _isCropMode,
                    ),

                    // Rotate button
                    if (!_isCropMode)
                      _buildControlButton(
                        icon: Icons.rotate_90_degrees_ccw,
                        label: 'Rotate',
                        onPressed: _rotateVideo,
                      ),

                    // Save button
                    _buildControlButton(
                      icon: Icons.save,
                      label: 'Save',
                      onPressed: _isExporting ? null : _saveEditedVideo,
                      isPrimary: true,
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Editing controls (when not in crop mode)
                if (!_isCropMode) ...[
                  // Timeline
                  _buildTimeline(),

                  const SizedBox(height: 20),

                  // Brightness slider
                  _buildSlider(
                    'Brightness',
                    _brightness,
                    -50.0,
                    50.0,
                    (value) => setState(() => _brightness = value),
                    Icons.brightness_6,
                  ),

                  const SizedBox(height: 16),

                  // Contrast slider
                  _buildSlider(
                    'Contrast',
                    _contrast,
                    0.5,
                    2.0,
                    (value) => setState(() => _contrast = value),
                    Icons.contrast,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    bool isActive = false,
    bool isPrimary = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: isActive
                ? Colors.blue
                : isPrimary
                    ? Colors.green
                    : Colors.grey[700],
            foregroundColor: Colors.white,
            padding: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Icon(icon, size: 24),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.blue : Colors.white70,
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildTimeline() {
    final duration = _controller.value.duration;
    final position = _controller.value.position;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_formatDuration(_startTime),
                style: const TextStyle(color: Colors.white70)),
            Text(_formatDuration(position),
                style: const TextStyle(color: Colors.white)),
            Text(_formatDuration(_endTime),
                style: const TextStyle(color: Colors.white70)),
          ],
        ),
        const SizedBox(height: 8),
        Stack(
          children: [
            // Background track
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Active portion
            FractionallySizedBox(
              widthFactor:
                  (_endTime.inMilliseconds - _startTime.inMilliseconds) /
                      duration.inMilliseconds,
              alignment: Alignment.centerLeft,
              child: Container(
                height: 4,
                margin: EdgeInsets.only(
                  left: (_startTime.inMilliseconds / duration.inMilliseconds) *
                      MediaQuery.of(context).size.width *
                      0.9,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Progress indicator
            FractionallySizedBox(
              widthFactor: position.inMilliseconds / duration.inMilliseconds,
              alignment: Alignment.centerLeft,
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSlider(
    String label,
    double value,
    double min,
    double max,
    Function(double) onChanged,
    IconData icon,
  ) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white70, size: 20),
            const SizedBox(width: 12),
            Text(
              '$label: ${value.toStringAsFixed(1)}',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: 20,
          activeColor: Colors.blue,
          inactiveColor: Colors.grey[700],
          onChanged: onChanged,
        ),
      ],
    );
  }

  // Get color matrix for brightness and contrast
  List<double> _getColorMatrix() {
    final brightness = _brightness / 100.0;
    final contrast = _contrast;

    return [
      contrast,
      0,
      0,
      0,
      brightness * 255,
      0,
      contrast,
      0,
      0,
      brightness * 255,
      0,
      0,
      contrast,
      0,
      brightness * 255,
      0,
      0,
      0,
      1,
      0,
    ];
  }
}

// Crop overlay widget
class CropOverlay extends StatefulWidget {
  final Rect cropRect;
  final Function(Rect) onCropUpdate;

  const CropOverlay({
    super.key,
    required this.cropRect,
    required this.onCropUpdate,
  });

  @override
  State<CropOverlay> createState() => _CropOverlayState();
}

class _CropOverlayState extends State<CropOverlay> {
  String _dragHandle = '';
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (details) {
        final localPosition = details.localPosition;
        final size = context.size!;
        final normalizedPos = Offset(
          localPosition.dx / size.width,
          localPosition.dy / size.height,
        );

        _dragHandle = _getHandleAt(normalizedPos);
        _isDragging = _dragHandle.isNotEmpty;
      },
      onPanUpdate: (details) {
        if (!_isDragging) return;

        final size = context.size!;
        final delta = Offset(
          details.delta.dx / size.width,
          details.delta.dy / size.height,
        );

        final newRect =
            _updateRectWithHandle(_dragHandle, widget.cropRect, delta);
        widget.onCropUpdate(newRect);
      },
      onPanEnd: (details) {
        _isDragging = false;
        _dragHandle = '';
      },
      child: CustomPaint(
        painter: CropPainter(widget.cropRect),
        size: Size.infinite,
      ),
    );
  }

  String _getHandleAt(Offset position) {
    const handleSize = 0.03; // 3% of screen
    final rect = widget.cropRect;

    // Check corners first
    if (_isNear(position, Offset(rect.left, rect.top), handleSize))
      return 'topLeft';
    if (_isNear(position, Offset(rect.right, rect.top), handleSize))
      return 'topRight';
    if (_isNear(position, Offset(rect.left, rect.bottom), handleSize))
      return 'bottomLeft';
    if (_isNear(position, Offset(rect.right, rect.bottom), handleSize))
      return 'bottomRight';

    // Check edges
    if (_isNear(position, Offset(rect.center.dx, rect.top), handleSize))
      return 'top';
    if (_isNear(position, Offset(rect.center.dx, rect.bottom), handleSize))
      return 'bottom';
    if (_isNear(position, Offset(rect.left, rect.center.dy), handleSize))
      return 'left';
    if (_isNear(position, Offset(rect.right, rect.center.dy), handleSize))
      return 'right';

    // Check center
    if (_isNear(position, rect.center, handleSize * 2)) return 'center';

    return '';
  }

  bool _isNear(Offset a, Offset b, double threshold) {
    return (a - b).distance < threshold;
  }

  Rect _updateRectWithHandle(String handle, Rect rect, Offset delta) {
    switch (handle) {
      case 'topLeft':
        return Rect.fromLTRB(
          rect.left + delta.dx,
          rect.top + delta.dy,
          rect.right,
          rect.bottom,
        );
      case 'topRight':
        return Rect.fromLTRB(
          rect.left,
          rect.top + delta.dy,
          rect.right + delta.dx,
          rect.bottom,
        );
      case 'bottomLeft':
        return Rect.fromLTRB(
          rect.left + delta.dx,
          rect.top,
          rect.right,
          rect.bottom + delta.dy,
        );
      case 'bottomRight':
        return Rect.fromLTRB(
          rect.left,
          rect.top,
          rect.right + delta.dx,
          rect.bottom + delta.dy,
        );
      case 'top':
        return Rect.fromLTRB(
          rect.left,
          rect.top + delta.dy,
          rect.right,
          rect.bottom,
        );
      case 'bottom':
        return Rect.fromLTRB(
          rect.left,
          rect.top,
          rect.right,
          rect.bottom + delta.dy,
        );
      case 'left':
        return Rect.fromLTRB(
          rect.left + delta.dx,
          rect.top,
          rect.right,
          rect.bottom,
        );
      case 'right':
        return Rect.fromLTRB(
          rect.left,
          rect.top,
          rect.right + delta.dx,
          rect.bottom,
        );
      case 'center':
        return rect.translate(delta.dx, delta.dy);
      default:
        return rect;
    }
  }
}

// Custom painter for crop overlay
class CropPainter extends CustomPainter {
  final Rect cropRect;

  CropPainter(this.cropRect);

  @override
  void paint(Canvas canvas, Size size) {
    // Convert normalized coordinates to screen coordinates
    final screenRect = Rect.fromLTWH(
      cropRect.left * size.width,
      cropRect.top * size.height,
      cropRect.width * size.width,
      cropRect.height * size.height,
    );

    // Draw semi-transparent overlay
    final overlayPaint = Paint()..color = Colors.black.withOpacity(0.5);

    // Draw the mask (everything except crop area)
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRect(screenRect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, overlayPaint);

    // Draw crop border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawRect(screenRect, borderPaint);

    // Draw corner handles
    final handlePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    const handleSize = 8.0;

    // Corner handles
    _drawHandle(canvas, handlePaint, screenRect.topLeft, handleSize);
    _drawHandle(canvas, handlePaint, screenRect.topRight, handleSize);
    _drawHandle(canvas, handlePaint, screenRect.bottomLeft, handleSize);
    _drawHandle(canvas, handlePaint, screenRect.bottomRight, handleSize);

    // Edge handles
    _drawHandle(canvas, handlePaint,
        Offset(screenRect.center.dx, screenRect.top), handleSize);
    _drawHandle(canvas, handlePaint,
        Offset(screenRect.center.dx, screenRect.bottom), handleSize);
    _drawHandle(canvas, handlePaint,
        Offset(screenRect.left, screenRect.center.dy), handleSize);
    _drawHandle(canvas, handlePaint,
        Offset(screenRect.right, screenRect.center.dy), handleSize);

    // Center move handle
    final centerPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;

    canvas.drawCircle(screenRect.center, 12, centerPaint);

    // Draw move icon
    final iconPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    const iconSize = 6.0;
    final center = screenRect.center;

    // Draw cross arrows for move handle
    canvas.drawLine(
      Offset(center.dx - iconSize, center.dy),
      Offset(center.dx + iconSize, center.dy),
      iconPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - iconSize),
      Offset(center.dx, center.dy + iconSize),
      iconPaint,
    );

    // Draw rule of thirds grid
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Vertical lines
    final thirdWidth = screenRect.width / 3;
    canvas.drawLine(
      Offset(screenRect.left + thirdWidth, screenRect.top),
      Offset(screenRect.left + thirdWidth, screenRect.bottom),
      gridPaint,
    );
    canvas.drawLine(
      Offset(screenRect.left + thirdWidth * 2, screenRect.top),
      Offset(screenRect.left + thirdWidth * 2, screenRect.bottom),
      gridPaint,
    );

    // Horizontal lines
    final thirdHeight = screenRect.height / 3;
    canvas.drawLine(
      Offset(screenRect.left, screenRect.top + thirdHeight),
      Offset(screenRect.right, screenRect.top + thirdHeight),
      gridPaint,
    );
    canvas.drawLine(
      Offset(screenRect.left, screenRect.top + thirdHeight * 2),
      Offset(screenRect.right, screenRect.top + thirdHeight * 2),
      gridPaint,
    );
  }

  void _drawHandle(Canvas canvas, Paint paint, Offset position, double size) {
    canvas.drawRect(
      Rect.fromCenter(center: position, width: size, height: size),
      paint,
    );

    // Draw black border for better visibility
    final borderPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawRect(
      Rect.fromCenter(center: position, width: size, height: size),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(CropPainter oldDelegate) {
    return oldDelegate.cropRect != cropRect;
  }
}
