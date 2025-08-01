import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationController {

  /// این تابع زمانی فراخوانی می‌شود که کاربر روی یک اکشن (مثل Reply) کلیک می‌کند
  /// و باید بتواند به صورت کاملاً مستقل در پس‌زمینه اجرا شود.
  @pragma("vm:entry-point")
  static Future<void> onActionReceivedMethod(ReceivedAction receivedAction) async {
    print('--- [Notification Action] اکشن دریافت شد! کلید: ${receivedAction.buttonKeyPressed} ---');

    // فقط اگر اکشن از نوع REPLY است و کاربر متنی وارد کرده، ادامه بده
    if (receivedAction.buttonKeyPressed == 'REPLY' && 
        (receivedAction.buttonKeyInput?.isNotEmpty ?? false)) {
      
      print('--- [Notification Action] در حال پردازش Reply...');

      // --- این بخش کلیدی برای حل مشکل است ---
      // ما باید Supabase را در داخل این Isolate جداگانه نیز راه‌اندازی کنیم
      // تا بتوانیم به دیتابیس دسترسی داشته باشیم و کاربر را بشناسیم.
      await Supabase.initialize(
        url: 'https://zgcnrtkmammvindhuikt.supabase.co',
        anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpnY25ydGttYW1tdmluZGh1aWt0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTMxMTU5MTEsImV4cCI6MjA2ODY5MTkxMX0.IgLDs8oLqw38ib5fgRg31-WYii148U3pHesJaEwdubw',
      );
      // ------------------------------------

      final supabase = Supabase.instance.client;
      // پس از راه‌اندازی، Supabase به طور خودکار جلسه کاربر را بازگردانی می‌کند
      final myUserId = supabase.auth.currentUser?.id;

      if (myUserId == null) {
        print('--- [Notification Action] خطا: کاربر پیدا نشد. ارسال پاسخ لغو شد.');
        return;
      }
      print('--- [Notification Action] کاربر با ID پیدا شد: $myUserId');

      // اطلاعات پیام اصلی را از payload نوتیفیکیشن استخراج می‌کنیم
      final originalMessageContent = receivedAction.payload?['originalMessage'] ?? '';
      
      final replyText = receivedAction.buttonKeyInput!;
      // می‌توانید ساختار بهتری برای نمایش پاسخ‌ها طراحی کنید
      final fullReplyContent = "Replying to \"$originalMessageContent\":\n$replyText";

      try {
        print('--- [Notification Action] در حال ارسال پاسخ به Supabase...');
        await supabase.from('messages').insert({
          'profile_id': myUserId,
          'content': fullReplyContent,
          'message_type': 'text',
        });
        print('✅ [Notification Action] پاسخ با موفقیت ارسال شد!');

      } catch (e) {
        print('--- [Notification Action] خطا در ارسال پاسخ به Supabase: $e');
      }
    }
  }
}