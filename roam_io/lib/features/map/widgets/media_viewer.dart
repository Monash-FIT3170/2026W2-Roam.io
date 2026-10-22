import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Full-screen viewer for photos and videos.
/// Supports swiping between multiple media items.
class MediaViewer extends StatefulWidget {
  const MediaViewer({
    super.key,
    required this.mediaUrls,
    this.isVideoFlags,
    this.initialIndex = 0,
  });

  final List<String> mediaUrls;
  final List<bool>? isVideoFlags;
  final int initialIndex;

  /// Shows the media viewer as a full-screen page.
  static Future<void> show({
    required BuildContext context,
    required List<String> mediaUrls,
    List<bool>? isVideoFlags,
    int initialIndex = 0,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => MediaViewer(
          mediaUrls: mediaUrls,
          isVideoFlags: isVideoFlags,
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

  bool _isVideo(int index, String url) {
    if (widget.isVideoFlags != null &&
        index >= 0 &&
        index < widget.isVideoFlags!.length) {
      return widget.isVideoFlags![index];
    }
    final lower = url.toLowerCase();
    String decoded;
    try {
      decoded = Uri.decodeFull(url).toLowerCase();
    } catch (_) {
      decoded = lower;
    }
    const videoPatterns = [
      '.mp4',
      '.mov',
      '.m4v',
      '.webm',
      '.mkv',
      '.3gp',
      'video/',
      'video',
    ];
    for (final pattern in videoPatterns) {
      if (lower.contains(pattern) || decoded.contains(pattern)) {
        return true;
      }
    }
    return false;
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
          if (_isVideo(index, url)) {
            return _VideoViewer(url: url, isActive: index == _currentIndex);
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
  const _VideoViewer({required this.url, this.isActive = true});

  final String url;
  final bool isActive;

  @override
  State<_VideoViewer> createState() => _VideoViewerState();
}

class _VideoViewerState extends State<_VideoViewer>
    with AutomaticKeepAliveClientMixin<_VideoViewer> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  @override
  void didUpdateWidget(covariant _VideoViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isActive && oldWidget.isActive && _isInitialized) {
      _controller?.pause();
    }
  }

  Future<void> _initializeVideo() async {
    final uri = Uri.tryParse(widget.url);
    if (uri == null) {
      if (mounted) setState(() => _hasError = true);
      return;
    }
    final controller = VideoPlayerController.networkUrl(uri);
    _controller = controller;
    controller.addListener(_onControllerUpdate);
    try {
      await controller.initialize();
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e, st) {
      debugPrint(
        '[MediaViewer] Failed to initialize video player for ${widget.url}: $e\n$st',
      );
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  void _onControllerUpdate() {
    if (!mounted) return;
    final controller = _controller;
    if (controller != null && controller.value.hasError && !_hasError) {
      setState(() {
        _hasError = true;
      });
      return;
    }
    setState(() {});
  }

  @override
  void dispose() {
    final controller = _controller;
    if (controller != null) {
      controller.removeListener(_onControllerUpdate);
      controller.dispose();
    }
    super.dispose();
  }

  void _togglePlayPause() {
    final controller = _controller;
    if (controller == null || !_isInitialized) return;
    setState(() {
      if (controller.value.isPlaying) {
        controller.pause();
      } else {
        if (controller.value.duration > Duration.zero &&
            controller.value.position >= controller.value.duration) {
          controller.seekTo(Duration.zero);
        }
        controller.play();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Failed to load video',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _hasError = false;
                  _isInitialized = false;
                });
                _initializeVideo();
              },
              icon: const Icon(Icons.refresh, color: Colors.white),
              label: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    final controller = _controller;
    if (!_isInitialized || controller == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    final isPlaying = controller.value.isPlaying;
    final isEnded =
        controller.value.duration > Duration.zero &&
        controller.value.position >= controller.value.duration;

    return GestureDetector(
      onTap: _togglePlayPause,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio > 0
                  ? controller.value.aspectRatio
                  : 16 / 9,
              child: VideoPlayer(controller),
            ),
          ),
          // Play/pause overlay
          AnimatedOpacity(
            opacity: isPlaying ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isEnded ? Icons.replay : Icons.play_arrow,
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
              controller,
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
