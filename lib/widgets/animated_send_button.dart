import 'dart:math';
import 'package:flutter/material.dart';
import './paper_plane_painter.dart'; // نقاش سفارشی شما که در مراحل قبل ساختیم

// این یک کنترلر بسیار سبک است که فقط وظیفه شروع انیمیشن را بر عهده دارد
class SendAnimationController extends ValueNotifier<bool> {
  SendAnimationController() : super(false);
  void trigger() => value = true;
}

// ویجت اصلی که به عنوان دکمه ارسال استفاده می‌شود
class AnimatedSendButton extends StatefulWidget {
  final SendAnimationController controller;
  final VoidCallback onPressed;

  const AnimatedSendButton({
    Key? key,
    required this.controller,
    required this.onPressed,
  }) : super(key: key);

  @override
  State<AnimatedSendButton> createState() => _AnimatedSendButtonState();
}

class _AnimatedSendButtonState extends State<AnimatedSendButton> {
  @override
  Widget build(BuildContext context) {
    // این ویجت به کنترلر گوش می‌دهد تا بداند کدام حالت را نمایش دهد
    return ValueListenableBuilder<bool>(
      valueListenable: widget.controller,
      builder: (context, isAnimating, child) {
        // اگر کنترلر در حالت "انیمیشن" بود، ویجت انیمیشنی را نشان بده
        if (isAnimating) {
          return _AnimatingIcon(onAnimationComplete: () {
            // وقتی انیمیشن تمام شد، این callback اجرا شده و کنترلر را ریست می‌کند
            widget.controller.value = false;
          });
        }
        // در غیر این صورت، دکمه ثابت و قابل کلیک را نشان بده
        return _StaticIcon(onPressed: () {
          widget.onPressed();      // 1. ابتدا تابع ارسال پیام را اجرا کن
          widget.controller.trigger(); // 2. سپس انیمیشن را فعال کن
        });
      },
    );
  }
}

// یک ویجت ساده و stateless برای نمایش آیکون در حالت ثابت
class _StaticIcon extends StatelessWidget {
  final VoidCallback onPressed;
  const _StaticIcon({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: CustomPaint(
        painter: PaperPlanePainter(color: Theme.of(context).colorScheme.primary),
        size: const Size(24, 24),
      ),
      onPressed: onPressed,
      splashRadius: 24,
    );
  }
}

// یک ویجت stateful که مسئولیت اجرای کامل انیمیشن را بر عهده دارد
class _AnimatingIcon extends StatefulWidget {
  final VoidCallback onAnimationComplete; // یک callback برای خبر دادن پایان انیمیشن
  const _AnimatingIcon({required this.onAnimationComplete});

  @override
  State<_AnimatingIcon> createState() => _AnimatingIconState();
}

class _AnimatingIconState extends State<_AnimatingIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..addStatusListener((status) {
        // به محض اتمام انیمیشن، تابع callback را صدا می‌زنیم
        if (status == AnimationStatus.completed) {
          widget.onAnimationComplete();
        }
      });
      
    // انیمیشن را بلافاصله پس از ساخته شدن ویجت، شروع می‌کنیم
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        // انیمیشن‌های زیبا و ترکیبی برای یک افکت حرفه‌ای
        final angle = _animationController.value * -3 * pi; // چرخش سریع
        final offset = Offset(0.0, -_animationController.value * 30); // پرواز کوتاه به بالا
        final scale = 1.0 - _animationController.value; // کوچک شدن و محو شدن

        return Transform.translate(
          offset: offset,
          child: Transform.scale(
            scale: scale,
            child: Transform.rotate(
              angle: angle,
              child: child,
            ),
          ),
        );
      },
      child: CustomPaint(
        painter: PaperPlanePainter(color: Theme.of(context).colorScheme.primary),
        size: const Size(24, 24),
      ),
    );
  }
}