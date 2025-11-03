import 'package:flutter/material.dart';
import '../../services/config/config_service.dart';

/// ScrollPhysics سفارشی برای اسکرول خیلی روان و خلاص
class SmoothScrollPhysics extends BouncingScrollPhysics {
  final double scrollSpeed;

  const SmoothScrollPhysics({super.parent, this.scrollSpeed = 1.0});

  @override
  SmoothScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return SmoothScrollPhysics(
      parent: buildParent(ancestor),
      scrollSpeed: scrollSpeed,
    );
  }

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    // ضرب کردن offset در scrollSpeed برای افزایش سرعت
    return super.applyPhysicsToUserOffset(position, offset * scrollSpeed);
  }

  @override
  double carriedMomentum(double existingVelocity) {
    // کاهش momentum برای bounce کمتر
    return super.carriedMomentum(existingVelocity) *
        scrollSpeed *
        1.5; // کاهش از 5.0 به 1.5 برای bounce ملایم‌تر
  }

  @override
  double get minFlingVelocity => 10.0; // خیلی حساس (پیش‌فرض: 50)

  @override
  double get maxFlingVelocity => 12000.0; // کاهش برای bounce ملایم‌تر (پیش‌فرض: 8000)

  @override
  SpringDescription get spring => SpringDescription.withDampingRatio(
    mass: 0.2, // خیلی سبک برای واکنش فوری (پیش‌فرض: 1.0)
    stiffness: 80.0, // کاهش stiffness برای نرم‌تر بودن
    ratio: 0.8, // افزایش damping برای bounce کمتر (پیش‌فرض: 1.0)
  );
}

/// ScrollPhysics ملایم برای Chapter Screen - bounce کم
class GentleScrollPhysics extends BouncingScrollPhysics {
  const GentleScrollPhysics({super.parent});

  @override
  GentleScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return GentleScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  double carriedMomentum(double existingVelocity) {
    // کاهش شدید momentum برای bounce خیلی کم
    return super.carriedMomentum(existingVelocity) * 0.3;
  }

  @override
  double get minFlingVelocity => 50.0; // کمتر حساس

  @override
  double get maxFlingVelocity => 8000.0; // سرعت عادی

  @override
  SpringDescription get spring => SpringDescription.withDampingRatio(
    mass: 1.0, // وزن عادی
    stiffness: 100.0, // سختی بیشتر
    ratio: 1.2, // damping زیاد برای bounce کم
  );
}

/// Helper برای گرفتن SmoothScrollPhysics با سرعت از config
class AppScrollPhysics {
  static SmoothScrollPhysics get smooth {
    final speed = ConfigService.instance.pdfScrollSpeed;
    return SmoothScrollPhysics(scrollSpeed: speed);
  }

  /// ScrollPhysics ملایم برای Chapter Screen
  static const GentleScrollPhysics gentle = GentleScrollPhysics();
}
