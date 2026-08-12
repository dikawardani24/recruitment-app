import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../controllers/intro_controller.dart';
import '../providers.dart';
import '../theme/app_theme.dart';
import '../widgets/deferred_page.dart';

class IntroScreen extends StatelessWidget {
  const IntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DeferredPage(child: _IntroContent());
  }
}

class _IntroSlide {
  final IconData icon;
  final String title;
  final String subtitle;

  const _IntroSlide({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}

const _slides = [
  _IntroSlide(
    icon: Icons.work_outline,
    title: 'Manage Jobs',
    subtitle: 'Create job postings and keep every opening organised in one place.',
  ),
  _IntroSlide(
    icon: Icons.auto_awesome_outlined,
    title: 'AI-Powered Rankings',
    subtitle: 'Rank candidates against any job with clear reasoning behind every score.',
  ),
  _IntroSlide(
    icon: Icons.search,
    title: 'Search Everything',
    subtitle: 'Find jobs and candidates fast with unified search across your pipeline.',
  ),
  _IntroSlide(
    icon: Icons.support_agent,
    title: 'Recruiter Copilot',
    subtitle: 'Ask the built-in AI assistant to help shortlist, compare, and decide.',
  ),
];

class _IntroContent extends ConsumerStatefulWidget {
  const _IntroContent();

  @override
  ConsumerState<_IntroContent> createState() => _IntroContentState();
}

class _IntroContentState extends ConsumerState<_IntroContent> {
  final _pageController = PageController();
  int _current = 0;

  bool get _isLast => _current == _slides.length - 1;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await ref.read(introControllerProvider.notifier).complete();
    if (!mounted) return;
    ref.read(navigatorProvider).goToJobs();
  }

  void _next() {
    if (_isLast) {
      _finish();
    } else {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 8, top: 4),
                child: TextButton(
                  onPressed: _finish,
                  child: const Text('Skip'),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (index) => setState(() => _current = index),
                itemBuilder: (context, index) => _SlideView(
                  slide: _slides[index],
                  index: index,
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _slides.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _current ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _current
                          ? scheme.primary
                          : scheme.outlineVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _next,
                  icon: Icon(_isLast ? Icons.check : Icons.arrow_forward),
                  label: Text(_isLast ? 'Get Started' : 'Next'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  final _IntroSlide slide;
  final int index;

  const _SlideView({required this.slide, required this.index});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Icon(
              slide.icon,
              size: 72,
              color: scheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: kSeedColor,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            slide.subtitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
