import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Full-screen viewer for photos and videos.
/// Supports swiping between multiple media items.
class MediaViewer extends StatefulWidget {
  const MediaViewer({
    super.key,
    required this.mediaUrls,
    this.initialIndex = 0,
  });

  final List<String> mediaUrls;
  final int initialIndex;

  /// Shows the media viewer as a full-screen page.
  static Future<void> show({
    required BuildContext context,
    required List<String> mediaUrls,
    int initialIndex = 0,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => MediaViewer(
          mediaUrls: mediaUrls,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  @override
  State<MediaViewer> createState() => _MediaViewerState();
}

class _MediaViewerState extends State<MediaViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool _isVideo(String url) {
    final lower = url.toLowerCase();
    return lower.contains('.mp4') || lower.contains('.mov') || lower.contains('video');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: widget.mediaUrls.length > 1
            ? Text('${_currentIndex + 1} / ${widget.mediaUrls.length}')
            : null,
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.mediaUrls.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemBuilder: (context, index) {
          final url = widget.mediaUrls[index];
          if (_isVideo(url)) {
            return _VideoViewer(url: url);
          }
          return _ImageViewer(url: url);
        },
      ),
    );
  }
}

/// Zoomable image viewer with loading indicator.
class _ImageViewer extends StatelessWidget {
  const _ImageViewer({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 4.0,
      child: Center(
        child: Image.network(
          url,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
                color: Colors.white,
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.broken_image, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Failed to load image',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Video player with controls.
class _VideoViewer extends StatefulWidget {
  const _VideoViewer({required this.url});

  final String url;

  @override
  State<_VideoViewer> createState() => _VideoViewerState();
}

class _VideoViewerState extends State<_VideoViewer> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    try {
      await _controller.initialize();
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
      } else {
        _controller.play();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Failed to load video',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (!_isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return GestureDetector(
      onTap: _togglePlayPause,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(
            aspectRatio: _controller.value.aspectRatio,
            child: VideoPlayer(_controller),
          ),
          // Play/pause overlay
          AnimatedOpacity(
            opacity: _controller.value.isPlaying ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow,
                size: 48,
                color: Colors.white,
              ),
            ),
          ),
          // Progress bar at bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: VideoProgressIndicator(
              _controller,
              allowScrubbing: true,
              colors: const VideoProgressColors(
                playedColor: Colors.white,
                bufferedColor: Colors.white24,
                backgroundColor: Colors.white12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
