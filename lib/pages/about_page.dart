import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:math';

import 'package:future_series_chat/utils/custom_page_route.dart'; // Your animated route

class AboutPage extends StatefulWidget {
  const AboutPage({Key? key}) : super(key: key);

  static Route<void> route() {
    return SlideRightRoute(page: const AboutPage());
  }

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> with TickerProviderStateMixin {
  late final AnimationController _entryAnimationController;
  late final AnimationController _logoAnimationController;
  String _appVersion = 'Loading...';

  @override
  void initState() {
    super.initState();
    _entryAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();

    _logoAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(); // This animation will loop forever

    _getAppVersion();
  }

  @override
  void dispose() {
    _entryAnimationController.dispose();
    _logoAnimationController.dispose();
    super.dispose();
  }

  Future<void> _getAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _appVersion = packageInfo.version;
      });
    }
  }
  
  void _showLicenseDialog() {
    showDialog(
      context: context, 
      builder: (context) => AlertDialog(
        title: const Text('MIT License'),
        content: const SingleChildScrollView(
          child: Text(mitLicenseText), // We'll define this text below
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('About Future Series'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        children: [
          _AnimatedListItem(
            delay: 0.1,
            animationController: _entryAnimationController,
            child: _buildAnimatedLogo(theme),
          ),
          const SizedBox(height: 24),
          _AnimatedListItem(
            delay: 0.2,
            animationController: _entryAnimationController,
            child: Text(
              'Future Series',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 12),
          _AnimatedListItem(
            delay: 0.3,
            animationController: _entryAnimationController,
            child: Text(
              'Exploring the frontiers of science and technology, shaping the world of tomorrow.',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.7)),
            ),
          ),
          const SizedBox(height: 32),
          _AnimatedListItem(
            delay: 0.4,
            animationController: _entryAnimationController,
            child: const _SectionHeader(title: 'Our Mission'),
          ),
          const SizedBox(height: 8),
          _AnimatedListItem(
            delay: 0.5,
            animationController: _entryAnimationController,
            child: const Text(
                'We are a multidisciplinary research team dedicated to innovation in Physics, Chemistry, Biology, Computer Science, Mathematics, and Geology. Our goal is to establish a state-of-the-art research laboratory to accelerate discovery.',
                style: TextStyle(fontSize: 16, height: 1.5),
            ),
          ),
          const SizedBox(height: 32),
           _AnimatedListItem(
            delay: 0.6,
            animationController: _entryAnimationController,
            child: const _SectionHeader(title: 'Our Fields'),
          ),
          const SizedBox(height: 16),
          _AnimatedListItem(
            delay: 0.7,
            animationController: _entryAnimationController,
            child: _buildFieldsGrid(),
          ),
          const Divider(height: 48),
          _AnimatedListItem(
            delay: 0.8,
            animationController: _entryAnimationController,
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('App Version'),
              subtitle: Text(_appVersion),
            ),
          ),
           _AnimatedListItem(
            delay: 0.9,
            animationController: _entryAnimationController,
            child: ListTile(
              leading: const Icon(Icons.policy_outlined),
              title: const Text('License'),
              subtitle: const Text('MIT License'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: _showLicenseDialog,
            ),
          ),
          _AnimatedListItem(
            delay: 1.0,
            animationController: _entryAnimationController,
            child: ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('Founded'),
              subtitle: const Text('Established in 2025'),
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET BUILDER HELPERS ---

  Widget _buildAnimatedLogo(ThemeData theme) {
    return SizedBox(
      height: 150,
      width: 150,
      child: AnimatedBuilder(
        animation: _logoAnimationController,
        builder: (context, child) {
          return Transform.rotate(
            angle: _logoAnimationController.value * 2.0 * pi,
            child: Stack(
              alignment: Alignment.center,
              children: [
                _buildOrbitingDot(0, 70, theme.colorScheme.primary),
                _buildOrbitingDot(pi / 2, 50, theme.colorScheme.secondary),
                _buildOrbitingDot(pi, 70, theme.colorScheme.tertiary),
                child!,
              ],
            ),
          );
        },
        child: Text(
          'FS',
          style: TextStyle(
            fontSize: 60,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildOrbitingDot(double angleOffset, double radius, Color color) {
    return Transform.translate(
      offset: Offset(
        cos(_logoAnimationController.value * 2.0 * pi + angleOffset) * radius,
        sin(_logoAnimationController.value * 2.0 * pi + angleOffset) * radius,
      ),
      child: CircleAvatar(
        radius: 6,
        backgroundColor: color,
      ),
    );
  }
  
  Widget _buildFieldsGrid() {
    final fields = {
      'Physics': Icons.explore_outlined,
      'Chemistry': Icons.science_outlined,
      'Biology': Icons.biotech_outlined,
      'Computer Science': Icons.code,
      'Mathematics': Icons.calculate_outlined,
      'Geology': Icons.public_outlined,
    };

    return Wrap(
      spacing: 12.0,
      runSpacing: 12.0,
      children: fields.entries.map((entry) {
        return Chip(
          avatar: Icon(entry.value, color: Theme.of(context).colorScheme.primary),
          label: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w500)),
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        );
      }).toList(),
    );
  }
}

// --- ANIMATION & UI HELPER WIDGETS ---

class _AnimatedListItem extends StatelessWidget {
  final AnimationController animationController;
  final double delay;
  final Widget child;

  const _AnimatedListItem({
    required this.animationController,
    required this.delay,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final animation = CurvedAnimation(
      parent: animationController,
      curve: Interval(delay.clamp(0.0, 1.0), 1.0, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(animation),
        child: child,
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
        fontSize: 14,
      ),
    );
  }
}

// --- LICENSE TEXT CONSTANT ---
const mitLicenseText = """
MIT License

Copyright (c) 2025 Future Series

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
""";