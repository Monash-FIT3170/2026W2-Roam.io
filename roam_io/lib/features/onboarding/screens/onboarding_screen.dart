import 'dart:async';

import 'package:flutter/material.dart';

import '../../../theme/app_colours.dart';
import '../widgets/onboarding_scene.dart';
import '../../../theme/app_accessibility.dart';

/// A self-contained introduction. Its caller owns routing and completion state.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onComplete});

  final FutureOr<void> Function() onComplete;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;
  bool _completed = false;
  bool _saving = false;
  String? _completionError;

  static const _chapters = [
    (
      topic: 'EXPLORATION',
      title: 'A world waiting\nto be uncovered.',
      description:
          'Head somewhere new and watch the clouds clear. As you explore, you unlock map tiles and reveal more of the world around you.',
      hint: 'Open the Map tab and start exploring',
      icon: Icons.layers_outlined,
    ),
    (
      topic: 'JOURNEYS',
      title: 'Your everyday.\nAn adventure.',
      description:
          'Start a Journey, choose how you’re travelling, and watch your route unfold. End it to save the places you’ve been.',
      hint: 'Find Start Journey on the Map tab',
      icon: Icons.route_rounded,
    ),
    (
      topic: 'LOCATIONS',
      title: 'Turn nearby\ninto been there.',
      description:
          'Tap a location on the map. Get within 100 metres to mark your visit, add a memory, and make it part of your story.',
      hint: 'Look for the in-range ring on the map',
      icon: Icons.place_outlined,
    ),
    (
      topic: 'SIDEQUESTS',
      title: 'Take a little\nside adventure.',
      description:
          'Pick a Sidequest, follow its challenge, and submit what it asks for. Complete it to earn XP and find something new.',
      hint: 'Find your next challenge in Side Quests',
      icon: Icons.explore_outlined,
    ),
    (
      topic: 'SOCIAL',
      title: 'Good stories.\nBetter together.',
      description:
          'Find and follow other explorers, share your adventures, and see how you stack up on the leaderboard.',
      hint: 'Meet your people in the Social tab',
      icon: Icons.people_outline_rounded,
    ),
    (
      topic: 'PROGRESSION',
      title: 'Small steps.\nBig discoveries.',
      description:
          'Journeys, visits, and Sidequests earn XP. Level up, reach milestones, and unlock new ways to show your explorer spirit.',
      hint: 'See your progress in the You tab',
      icon: Icons.auto_awesome_outlined,
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_completed || _saving) return;
    setState(() {
      _saving = true;
      _completionError = null;
    });
    try {
      await widget.onComplete();
      _completed = true;
    } catch (_) {
      if (mounted) {
        setState(() {
          _completionError = 'Couldn’t save your progress. Please try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _goTo(int page) {
    if (context.reduceMotion) {
      _controller.jumpToPage(page);
    } else {
      _controller.animateToPage(
        page,
        duration: const Duration(milliseconds: 480),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Android can publish an empty viewport during startup and hot restart.
    if (MediaQuery.sizeOf(context).isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final accent = dark ? AppColors.lightSage : AppColors.sage;
    final muted = scheme.onSurface.withValues(alpha: .7);
    final last = _page == _chapters.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(26, 12, 18, 0),
                  child: Row(
                    children: [
                      ClipOval(
                        child: Image.asset(
                          'assets/logos/roam_io_logo.png',
                          height: 34,
                          width: 34,
                          excludeFromSemantics: true,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          'roam.io',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1,
                          ),
                        ),
                      ),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 116),
                        child: TextButton(
                          onPressed: _saving || _completed ? null : _finish,
                          style: TextButton.styleFrom(foregroundColor: muted),
                          child: const Text(
                            'Skip tour',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    key: const ValueKey('onboarding-pages'),
                    controller: _controller,
                    itemCount: _chapters.length,
                    onPageChanged: (page) => setState(() => _page = page),
                    itemBuilder: (context, index) {
                      final chapter = _chapters[index];
                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final sceneHeight = (constraints.maxHeight * .52)
                              .clamp(220.0, 360.0);
                          return SingleChildScrollView(
                            key: PageStorageKey('onboarding-chapter-$index'),
                            padding: const EdgeInsets.fromLTRB(28, 4, 28, 16),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: (constraints.maxHeight - 20).clamp(
                                  0,
                                  double.infinity,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    height: sceneHeight,
                                    width: double.infinity,
                                    child: OnboardingScene(
                                      chapter: index,
                                      active: _page == index,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    '0${index + 1}  /  ${chapter.topic}',
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
                                          color: accent,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 2.2,
                                        ),
                                  ),
                                  const SizedBox(height: 12),
                                  Semantics(
                                    header: true,
                                    child: Text(
                                      chapter.title,
                                      style: theme.textTheme.headlineLarge
                                          ?.copyWith(
                                            fontSize: constraints.maxWidth < 360
                                                ? 34
                                                : 40,
                                            height: 1.08,
                                            letterSpacing: -1.6,
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    chapter.description,
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      color: muted,
                                      fontSize: 16,
                                      height: 1.55,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        chapter.icon,
                                        size: 18,
                                        color: accent,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          chapter.hint,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: accent,
                                                height: 1.4,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 12, 28, 20),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Semantics(
                              liveRegion: true,
                              label:
                                  'Page ${_page + 1} of ${_chapters.length}, ${_chapters[_page].topic.toLowerCase()}',
                              child: ExcludeSemantics(
                                child: Row(
                                  children: List.generate(
                                    _chapters.length,
                                    (index) => AnimatedContainer(
                                      duration: context.reduceMotion
                                          ? Duration.zero
                                          : const Duration(milliseconds: 250),
                                      height: 5,
                                      width: index == _page ? 28 : 8,
                                      margin: const EdgeInsets.only(right: 6),
                                      decoration: BoxDecoration(
                                        color: index == _page
                                            ? accent
                                            : accent.withValues(alpha: .2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Text(
                            '${_page + 1} / ${_chapters.length}',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: muted,
                            ),
                          ),
                        ],
                      ),
                      if (_completionError != null) ...[
                        const SizedBox(height: 12),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            _completionError!,
                            style: TextStyle(color: scheme.error),
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          if (_page > 0) ...[
                            IconButton.outlined(
                              onPressed: () => _goTo(_page - 1),
                              tooltip: 'Previous chapter',
                              style: IconButton.styleFrom(
                                minimumSize: const Size(56, 56),
                                side: BorderSide(
                                  color: accent.withValues(alpha: .3),
                                ),
                              ),
                              icon: const Icon(Icons.arrow_back_rounded),
                            ),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            child: FilledButton(
                              onPressed: _saving || _completed
                                  ? null
                                  : last
                                  ? _finish
                                  : () => _goTo(_page + 1),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.sage,
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(56),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 16,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Flexible(
                                    child: Text(
                                      _saving
                                          ? 'Saving…'
                                          : last
                                          ? 'Let’s roam'
                                          : 'Next chapter',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
