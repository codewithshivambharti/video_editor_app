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
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isExporting = false;
  double _exportProgress = 0.0;

  // Video editing parameters
  Duration _startTime = Duration.zero;
  Duration _endTime = Duration.zero;
  double _brightness = 0.0;
  double _contrast = 1.0;
  int _rotationAngle = 0;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      _controller = VideoPlayerController.file(File(widget.videoPath));
      await _controller.initialize();

      setState(() {
        _isInitialized = true;
        _endTime = _controller.value.duration;
      });

      _controller.addListener(() {
        if (mounted) {
          setState(() {
            _isPlaying = _controller.value.isPlaying;
          });
        }
      });
    } catch (e) {
      ToastHelper.showError('Failed to initialize video: $e');
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveVideo() async {
    if (!_isInitialized) return;

    setState(() {
      _isExporting = true;
      _exportProgress = 0.0;
    });

    try {
      // Simulate export progress
      for (int i = 0; i <= 100; i += 10) {
        await Future.delayed(const Duration(milliseconds: 200));
        setState(() {
          _exportProgress = i / 100;
        });
      }

      // Save the video with current settings
      final success = await VideoHelper.saveEditedVideo(
        inputPath: widget.videoPath,
        startTime: _startTime,
        endTime: _endTime,
        brightness: _brightness,
        contrast: _contrast,
        rotationAngle: _rotationAngle,
      );

      if (success) {
        ToastHelper.showSuccess('Video Saved Successfully');
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else {
        ToastHelper.showError('Failed to save video');
      }
    } catch (e) {
      ToastHelper.showError('Error saving video: $e');
    } finally {
      setState(() {
        _isExporting = false;
      });
    }
  }

  void _playPause() {
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
      } else {
        _controller.play();
      }
    });
  }

  void _rotateVideo() {
    setState(() {
      _rotationAngle = (_rotationAngle + 90) % 360;
    });
  }

  void _seekToPosition(Duration position) {
    _controller.seekTo(position);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Edit Video', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_isExporting)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            )
          else
            IconButton(
              onPressed: _saveVideo,
              icon: const Icon(Icons.save, color: Colors.white),
            ),
        ],
      ),
      body: !_isInitialized
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Video Preview
                Expanded(
                  flex: 3,
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Transform.rotate(
                        angle: _rotationAngle * 3.14159 / 180,
                        child: ColorFiltered(
                          colorFilter: ColorFilter.matrix([
                            _contrast + _brightness,
                            0,
                            0,
                            0,
                            0,
                            0,
                            _contrast + _brightness,
                            0,
                            0,
                            0,
                            0,
                            0,
                            _contrast + _brightness,
                            0,
                            0,
                            0,
                            0,
                            0,
                            1,
                            0,
                          ]),
                          child: AspectRatio(
                            aspectRatio: _controller.value.aspectRatio,
                            child: VideoPlayer(_controller),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Video Timeline
                Container(
                  height: 100,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      // Timeline Slider
                      Container(
                        height: 60,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.grey[800],
                        ),
                        child: Stack(
                          children: [
                            // Video thumbnail timeline (simplified)
                            Container(
                              height: 60,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.blue.withOpacity(0.3),
                                    Colors.purple.withOpacity(0.3)
                                  ],
                                ),
                              ),
                            ),
                            // Trim handles
                            Positioned.fill(
                              child: Row(
                                children: [
                                  // Start handle
                                  GestureDetector(
                                    onPanUpdate: (details) {
                                      final RenderBox box = context
                                          .findRenderObject() as RenderBox;
                                      final localPosition = box.globalToLocal(
                                          details.globalPosition);
                                      final progress =
                                          localPosition.dx / box.size.width;
                                      final newStart =
                                          _controller.value.duration *
                                              progress.clamp(0.0, 1.0);
                                      if (newStart < _endTime) {
                                        setState(() {
                                          _startTime = newStart;
                                        });
                                      }
                                    },
                                    child: Container(
                                      width: 20,
                                      decoration: BoxDecoration(
                                        color: Colors.blue,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Icon(Icons.drag_handle,
                                          color: Colors.white, size: 16),
                                    ),
                                  ),
                                  const Spacer(),
                                  // End handle
                                  GestureDetector(
                                    onPanUpdate: (details) {
                                      final RenderBox box = context
                                          .findRenderObject() as RenderBox;
                                      final localPosition = box.globalToLocal(
                                          details.globalPosition);
                                      final progress =
                                          localPosition.dx / box.size.width;
                                      final newEnd =
                                          _controller.value.duration *
                                              progress.clamp(0.0, 1.0);
                                      if (newEnd > _startTime) {
                                        setState(() {
                                          _endTime = newEnd;
                                        });
                                      }
                                    },
                                    child: Container(
                                      width: 20,
                                      decoration: BoxDecoration(
                                        color: Colors.blue,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Icon(Icons.drag_handle,
                                          color: Colors.white, size: 16),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Time labels
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${_startTime.inMinutes}:${(_startTime.inSeconds % 60).toString().padLeft(2, '0')}',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12),
                          ),
                          Text(
                            '${_endTime.inMinutes}:${(_endTime.inSeconds % 60).toString().padLeft(2, '0')}',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Control Buttons
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildControlButton(
                        icon: _isPlaying ? Icons.pause : Icons.play_arrow,
                        label: _isPlaying ? 'Pause' : 'Play',
                        onPressed: _playPause,
                      ),
                      _buildControlButton(
                        icon: Icons.rotate_right,
                        label: 'Rotate',
                        onPressed: _rotateVideo,
                      ),
                      _buildControlButton(
                        icon: Icons.skip_previous,
                        label: 'Start',
                        onPressed: () => _seekToPosition(_startTime),
                      ),
                      _buildControlButton(
                        icon: Icons.skip_next,
                        label: 'End',
                        onPressed: () => _seekToPosition(_endTime),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Filter Controls
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      // Brightness
                      Row(
                        children: [
                          const Icon(Icons.brightness_6, color: Colors.white),
                          const SizedBox(width: 8),
                          const Text('Brightness',
                              style: TextStyle(color: Colors.white)),
                          const Spacer(),
                          Expanded(
                            flex: 2,
                            child: Slider(
                              value: _brightness,
                              min: -0.5,
                              max: 0.5,
                              onChanged: (value) {
                                setState(() {
                                  _brightness = value;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      // Contrast
                      Row(
                        children: [
                          const Icon(Icons.contrast, color: Colors.white),
                          const SizedBox(width: 8),
                          const Text('Contrast',
                              style: TextStyle(color: Colors.white)),
                          const Spacer(),
                          Expanded(
                            flex: 2,
                            child: Slider(
                              value: _contrast,
                              min: 0.5,
                              max: 2.0,
                              onChanged: (value) {
                                setState(() {
                                  _contrast = value;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Export Progress
                if (_isExporting)
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        LinearProgressIndicator(
                          value: _exportProgress,
                          backgroundColor: Colors.grey[800],
                          valueColor:
                              const AlwaysStoppedAnimation<Color>(Colors.blue),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Saving video... ${(_exportProgress * 100).toInt()}%',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 16),
              ],
            ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onPressed,
          icon: Icon(icon, color: Colors.white, size: 28),
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withOpacity(0.1),
            padding: const EdgeInsets.all(12),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
