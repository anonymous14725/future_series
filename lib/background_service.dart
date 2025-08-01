import 'dart:async';
import 'dart:ui';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@pragma('vm:entry-point')
Future<void> onStart(ServiceInstance service) async {

  DartPluginRegistrant.ensureInitialized();

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

  // راه‌اندازی Supabase
  await Supabase.initialize(
    url: 'https://zgcnrtkmammvindhuikt.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpnY25ydGttYW1tdmluZGh1aWt0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTMxMTU5MTEsImV4cCI6MjA2ODY5MTkxMX0.IgLDs8oLqw38ib5fgRg31-WYii148U3pHesJaEwdubw',
  );

  final supabase = Supabase.instance.client;
  StreamSubscription? messagesSubscription;
  String? currentUserId;
  bool isFirstBatch = true; 

  service.on('set_user').listen((event) {
    if (event != null && event['userId'] != null) {
      print('--- [BackgroundService] Received user ID: ${event['userId']}. Starting to listen for messages. ---');
      currentUserId = event['userId'];
      isFirstBatch = true; 

      messagesSubscription?.cancel();
      
      messagesSubscription = supabase
          .from('messages')
          .stream(primaryKey: ['id'])
          .listen((List<Map<String, dynamic>> data) async {
        
        if (isFirstBatch) {
          isFirstBatch = false;
          return;
        }

        if (data.isNotEmpty) {
          final newMessage = data.last;
          final senderId = newMessage['profile_id'];
          
          if (senderId != null && senderId != currentUserId) {
            
            String senderUsername = 'Someone'; 
            String? senderAvatarUrl; 
            print('--- [BackgroundService] New message received from another user! Preparing notification...'); 
            
            try {
              final profileResponse = await supabase
                  .from('profiles')
                  .select('username, avatar_url')
                  .eq('id', senderId)
                  .single();
              
              if (profileResponse.isNotEmpty) {
                senderUsername = profileResponse['username'];
                senderAvatarUrl = profileResponse['avatar_url'];
              }
            } catch (e) {
              print('Error fetching sender profile for notification: $e');
            }
            
            String notificationBody;
            final messageType = newMessage['message_type'] ?? 'text';
            final content = newMessage['content'] ?? '';
            final metadata = newMessage['metadata'];

            switch (messageType) {
              case 'image':
                notificationBody = '📷 Sent you an image.';
                break;
              case 'file':
                final fileName = metadata?['fileName'] ?? 'a file';
                notificationBody = '📎 Sent: $fileName';
                break;
              case 'text':
              default:
                notificationBody = content;
                break;
            }
            
            AwesomeNotifications().createNotification(
              content: NotificationContent(
                id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
                channelKey: 'chat_channel',
                title: senderUsername,
                body: notificationBody,
                notificationLayout: messageType == 'image' ? NotificationLayout.BigPicture : NotificationLayout.Default,
                
                // 2. آیکون بزرگ نوتیفیکیشن، آواتار فرستنده است
                largeIcon: senderAvatarUrl,

                // اگر پیام تصویر بود، خود تصویر را به عنوان bigPicture قرار بده
                bigPicture: messageType == 'image' ? content : null,

                // این داده‌ها برای استفاده در اکشن Reply به نوتیفیکیشن الصاق می‌شوند
                payload: {
                  'senderId': senderId,
                  'originalMessage': messageType == 'text' ? (content.length > 40 ? '${content.substring(0, 40)}...' : content) : 'an attachment'
                },
              ),
              
              // 3. افزودن اکشن Reply به نوتیفیکیشن
              actionButtons: [
                NotificationActionButton(
                  key: 'REPLY', // کلید یکتا برای شناسایی این اکشن
                  label: 'Reply',
                  requireInputText: true, // این خط فیلد متنی را فعال می‌کند
                ),
              ]
            );
          }
        }
      });
    }
  });

  // دستور توقف سرویس
  service.on('stop').listen((event) {
    print('--- [BackgroundService] Stop command received. Stopping listener. ---');
    messagesSubscription?.cancel();
    service.stopSelf();
  });
}