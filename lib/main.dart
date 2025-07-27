import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Import provider
import 'package:supabase_flutter/supabase_flutter.dart';

import './pages/splash_page.dart';
import './providers/theme_provider.dart'; // Import our new theme provider

// Keep these as they are correct
import './background_service.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await AwesomeNotifications().initialize(
    'resource://mipmap/ic_launcher',
    [
      NotificationChannel(
        channelKey: 'chat_channel',
        channelName: 'Chat Messages',
        channelDescription: 'Notifications for new chat messages.',
        importance: NotificationImportance.Max,
        playSound: true,
        enableVibration: true,
        defaultRingtoneType: DefaultRingtoneType.Notification,
      )
    ],
    debug: true,
  );
  
  await Supabase.initialize(
    url: 'https://zgcnrtkmammvindhuikt.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpnY25ydGttYW1tdmluZGh1aWt0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTMxMTU5MTEsImV4cCI6MjA2ODY5MTkxMX0.IgLDs8oLqw38ib5fgRg31-WYii148U3pHesJaEwdubw',
  );

  await initializeBackgroundService();
  
  runApp(// Wrap the entire app with our ThemeProvider
    ChangeNotifierProvider(
      create: (context) => ThemeProvider(),
      child: const MyApp(),
    ));
}

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      isForegroundMode: true,
      autoStart: true,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  
  @override
  Widget build(BuildContext context) {
    // Use a Consumer to listen to theme changes
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Future Series Chat',
          
          // Use the provider to set the theme
          themeMode: themeProvider.themeMode,
          
          // Define the light theme using the accent color
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: themeProvider.accentColor,
              brightness: Brightness.light, 
            ),
          ),
          
          // Define the dark theme using the accent color
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: themeProvider.accentColor,
              brightness: Brightness.dark, 
            ),
          ),
          
          home: const SplashPage(),
        );
      },
    );
  }
}