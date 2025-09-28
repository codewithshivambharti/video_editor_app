import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import '../utils/video_helper.dart';
import '../utils/toast_helper.dart';
import '../screens/saved_video_screen.dart';

class CreationsTab extends StatefulWidget {
  const CreationsTab({super.key});

  @override
  State<CreationsTab> createState() => _CreationsTabState();
}

class _CreationsTabState extends State<CreationsTab> {
  List<File> _savedVideos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedVideos();
  }

  Future<void> _loadSavedVideos() async {
    final videos = await VideoHelper.getSavedVideos();
    setState(() {
      _savedVideos = videos;
      _isLoading = false;
    });
  }

  Future<void> _deleteVideo(File video) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Video'),
        content: const Text('Are you sure you want to delete this video?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await VideoHelper.deleteVideo(video.path);
      if (success) {
        ToastHelper.showSuccess('Video deleted');
        _loadSavedVideos();
      } else {
        ToastHelper.showError('Failed to delete video');
      }
    }
  }

  Future<void> _shareVideo(File video) async {
    try {
      await Share.shareXFiles([XFile(video.path)]);
    } catch (e) {
      ToastHelper.showError('Failed to share video');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(24.0),
              child: Text(
                'My Creations',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748),
                ),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _savedVideos.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.video_library_outlined,
                                size: 80,
                                color: Color(0xFF718096),
                              ),
                              SizedBox(height: 16),
                              Text(
                                'No videos yet',
                                style: TextStyle(
                                  fontSize: 20,
                                  color: Color(0xFF718096),
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Start editing videos to see them here',
                                style: TextStyle(
                                  color: Color(0xFF718096),
                                ),
                              ),
                            ],
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 16 / 9,
                          ),
                          itemCount: _savedVideos.length,
                          itemBuilder: (context, index) {
                            final video = _savedVideos[index];
                            return _buildVideoCard(video);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoCard(File video) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SavedVideoScreen(videoPath: video.path),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(12)),
                  gradient: LinearGradient(
                    colors: [
                      Colors.blue.withOpacity(0.3),
                      Colors.purple.withOpacity(0.3)
                    ],
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.play_circle_fill,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.path.split('/').last,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        VideoHelper.getVideoSize(video),
                        style: const TextStyle(
                          color: Color(0xFF718096),
                          fontSize: 10,
                        ),
                      ),
                      Row(
                        children: [
                          InkWell(
                            onTap: () => _shareVideo(video),
                            child: const Icon(Icons.share, size: 16),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () => _deleteVideo(video),
                            child: const Icon(Icons.delete,
                                size: 16, color: Colors.red),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
