import 'package:flutter/material.dart';

// An enum to represent our different animation styles
enum BubbleAnimationType { none, fade, slide, scale }

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  MaterialColor _accentColor = Colors.blue;
  // --- ADD THIS LINE for animations ---
  BubbleAnimationType _animationType = BubbleAnimationType.slide; // Default animation

  ThemeMode get themeMode => _themeMode;
  MaterialColor get accentColor => _accentColor;
  // --- ADD THIS GETTER ---
  BubbleAnimationType get animationType => _animationType;

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }

  void setAccentColor(MaterialColor color) {
    _accentColor = color;
    notifyListeners();
  }
  
  // --- ADD THIS SETTER ---
  void setAnimationType(BubbleAnimationType type) {
    _animationType = type;
    notifyListeners();
  }

  static List<MaterialColor> get customColors => [
    Colors.blue, Colors.teal, Colors.green, Colors.orange, Colors.pink, Colors.indigo,
  ];
}