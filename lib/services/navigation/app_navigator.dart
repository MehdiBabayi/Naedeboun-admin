import 'package:flutter/widgets.dart';

/// Global navigator key to allow showing dialogs from contexts
/// that are not under a Navigator (e.g., MaterialApp.builder overlay widgets).
class AppNavigator {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
}


