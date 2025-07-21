import 'package:flutter/material.dart';
import './utils/constants.dart';
import './pages/splash_page.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://zgcnrtkmammvindhuikt.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpnY25ydGttYW1tdmluZGh1aWt0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTMxMTU5MTEsImV4cCI6MjA2ODY5MTkxMX0.IgLDs8oLqw38ib5fgRg31-WYii148U3pHesJaEwdubw',
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Future Series Chat',
      theme: appTheme,
      home: const SplashPage(),
    );
  }
}