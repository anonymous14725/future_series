import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_settings/app_settings.dart'; // For opening notification settings

import '../providers/theme_provider.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  static Route<void> route() {
    return MaterialPageRoute(
      builder: (context) => const SettingsPage(),
    );
  }

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> with TickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Consumer listens for changes in ThemeProvider
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final theme = Theme.of(context);
        final subtitleColor = theme.colorScheme.onSurface.withOpacity(0.7);
        return Scaffold(
          appBar: AppBar(
            title: const Text('Settings'),
          ),
          body: ListView(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            children: [
              // -- Appearance Section --
              _AnimatedSettingsItem(
                animationController: _animationController,
                delay: 0.1,
                child: const _SettingsHeader(title: 'Appearance'),
              ),
              _AnimatedSettingsItem(
                animationController: _animationController,
                delay: 0.2,
                child: SwitchListTile(
                  title: const Text('Dark Mode'),
                  subtitle: Text(
                    'Enable or disable dark theme',
                    style: TextStyle(color: subtitleColor)
                    ),
                  secondary: const Icon(Icons.dark_mode_outlined),
                  value: themeProvider.themeMode == ThemeMode.dark,
                  onChanged: (value) {
                    themeProvider.setThemeMode(value ? ThemeMode.dark : ThemeMode.light);
                  },
                ),
              ),
              _AnimatedSettingsItem(
                animationController: _animationController,
                delay: 0.3,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Accent Color', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 12),
                      _ColorPicker(),
                    ],
                  ),
                ),
              ),
              const Divider(height: 40),
          _AnimatedSettingsItem(
            animationController: _animationController,
            delay: 0.6,
            child: const _SettingsHeader(title: 'Chat Settings'),
          ),
          _AnimatedSettingsItem(
            animationController: _animationController,
            delay: 0.7,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 0),
              child: DropdownButtonFormField<BubbleAnimationType>(
                decoration: const InputDecoration(
                  labelText: 'Bubble Animation',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.animation),
                ),
                value: themeProvider.animationType,
                items: BubbleAnimationType.values.map((type) {
                  // Capitalize first letter for display
                  String text = type.name[0].toUpperCase() + type.name.substring(1);
                  return DropdownMenuItem(value: type, child: Text(text));
                }).toList(),
                onChanged: (type) {
                  if (type != null) {
                    themeProvider.setAnimationType(type);
                  }
                },
              ),
            ),
          ),

              // -- Notifications Section --
              const Divider(height: 40),
              _AnimatedSettingsItem(
                animationController: _animationController,
                delay: 0.4,
                child: const _SettingsHeader(title: 'Notifications'),
              ),
              _AnimatedSettingsItem(
                animationController: _animationController,
                delay: 0.5,
                child: ListTile(
                  title: const Text('Manage Notifications'),
                  subtitle: Text('Sound, vibration, and priority',
                  style: TextStyle(color: subtitleColor)
                  ),
                  leading: const Icon(Icons.notifications_active_outlined),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    // This opens the app's notification settings in the phone's OS.
                    // This is the best practice.
                    AppSettings.openAppSettings(type: AppSettingsType.notification);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Helper widget for section headers
class _SettingsHeader extends StatelessWidget {
  final String title;
  const _SettingsHeader({Key? key, required this.title}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// Helper widget for the animated color circles
class _ColorPicker extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final availableColors = ThemeProvider.customColors;

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: availableColors.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final color = availableColors[index];
          final bool isSelected = color == themeProvider.accentColor;
          return InkWell(
            onTap: () => themeProvider.setAccentColor(color),
            borderRadius: BorderRadius.circular(20),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: color,
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white)
                  : null,
            ),
          );
        },
      ),
    );
  }
}

// Helper widget to create the staggered animation effect
class _AnimatedSettingsItem extends StatelessWidget {
  final AnimationController animationController;
  final double delay;
  final Widget child;

  const _AnimatedSettingsItem({
    required this.animationController,
    required this.delay,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final animation = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: animationController,
        curve: Interval(delay, 1.0, curve: Curves.easeOut),
      ),
    );

    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.2), end: Offset.zero).animate(animation),
        child: child,
      ),
    );
  }
}