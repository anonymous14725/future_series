import 'dart:async';
import 'dart:ui';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@pragma('vm:entry-point')
Future<void> onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  await Supabase.initialize(
    url: 'https://zgcnrtkmammvindhuikt.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpnY25ydGttYW1tdmluZGh1aWt0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTMxMTU5MTEsImV4cCI6MjA2ODY5MTkxMX0.IgLDs8oLqw38ib5fgRg31-WYii148U3pHesJaEwdubw',
  );
  // ===================================================================

  final supabase = Supabase.instance.client;
  StreamSubscription? messagesSubscription;
  String? currentUserId;
  bool isFirstBatch = true; 

  service.on('set_user').listen((event) {
    if (event != null && event['userId'] != null) {
      currentUserId = event['userId'];
      isFirstBatch = true; 

      messagesSubscription?.cancel();
      
      messagesSubscription = supabase
          .from('messages')
          .stream(primaryKey: ['id'])
          .listen((List<Map<String, dynamic>> data) {
        
        if (isFirstBatch) {
          isFirstBatch = false;
          return;
        }

        if (data.isNotEmpty) {
          final newMessage = data.last;
          final senderId = newMessage['profile_id'];
          
          if (senderId != currentUserId) {
            AwesomeNotifications().createNotification(
              content: NotificationContent(
                id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
                channelKey: 'chat_channel',
                title: 'New Message',
                body: newMessage['content'] ?? 'You have a new message',
                notificationLayout: NotificationLayout.Default,
              ),
              
            );
          }
        }
      });
    }
  });

  service.on('stop').listen((event) {
    messagesSubscription?.cancel();
    service.stopSelf();
  });
}