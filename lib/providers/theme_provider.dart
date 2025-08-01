import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// An enum to represent our different animation styles
enum BubbleAnimationType { none, fade, slide, scale }

class ThemeProvider extends ChangeNotifier {
  // --- KEYS for saving data ---
  static const String _themeModeKey = 'themeMode';
  static const String _accentColorKey = 'accentColor';
  static const String _animationTypeKey = 'animationType';
  
  // --- Default values ---
  ThemeMode _themeMode = ThemeMode.system;
  MaterialColor _accentColor = Colors.blue;
  BubbleAnimationType _animationType = BubbleAnimationType.slide;

  // --- Public getters ---
  ThemeMode get themeMode => _themeMode;
  MaterialColor get accentColor => _accentColor;
  BubbleAnimationType get animationType => _animationType;

  // A list of custom colors for the picker
  static final List<MaterialColor> customColors = [
    Colors.blue, Colors.teal, Colors.green, Colors.orange, Colors.pink, Colors.indigo,
  ];
  
  // The constructor is now empty. We will load preferences manually from main.dart.
  ThemeProvider();
  
  // --- Setters now save the choice to storage ---
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeModeKey, mode.index);
    notifyListeners();
  }

  Future<void> setAccentColor(MaterialColor color) async {
    _accentColor = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_accentColorKey, color.value);
    notifyListeners();
  }

  Future<void> setAnimationType(BubbleAnimationType type) async {
    _animationType = type;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_animationTypeKey, type.index);
    notifyListeners();
  }
  
  // ============== THIS IS THE CORRECTED, PUBLIC FUNCTION ==============
  /// Loads the saved preferences from storage.
  /// This must be called from main.dart BEFORE runApp.
  Future<void> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load Theme Mode
    final themeIndex = prefs.getInt(_themeModeKey) ?? ThemeMode.system.index;
    _themeMode = ThemeMode.values[themeIndex];
    
    // Load Accent Color
    final colorValue = prefs.getInt(_accentColorKey) ?? Colors.blue.value;
    _accentColor = customColors.firstWhere((c) => c.value == colorValue, orElse: () => Colors.blue);
    
    // Load Animation Type
    final animationIndex = prefs.getInt(_animationTypeKey) ?? BubbleAnimationType.slide.index;
    _animationType = BubbleAnimationType.values[animationIndex];
    
    // We don't need to call notifyListeners() here, because the UI hasn't been built yet.
    // It will be built for the first time with these correct, loaded values.
  }
}