# Flutter ProGuard Rules for Nardeboun App
# این فایل قوانین ProGuard را برای بهینه‌سازی APK تعریف می‌کند

# Flutter Engine
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Flutter Downloader
-keep class vn.hunghd.flutterdownloader.** { *; }

# Google Play Core (for deferred components / split install)
-keep class com.google.android.play.core.** { *; }
-keep class com.google.android.play.core.splitcompat.** { *; }
-keep class com.google.android.play.core.splitinstall.** { *; }
-keep interface com.google.android.play.core.splitinstall.** { *; }
-dontwarn com.google.android.play.core.**

# PDF Reader
-keep class com.pdftron.** { *; }

# WebView
-keep class android.webkit.** { *; }

# Supabase
-keep class com.supabase.** { *; }

# Hive Database
-keep class hive.** { *; }
-keep class **$HiveFieldAdapter { *; }

# Provider
-keep class provider.** { *; }

# Keep all model classes
-keep class * extends java.io.Serializable { *; }

# Keep all enum classes
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep R class
-keep class **.R$* {
    public static <fields>;
}

# Remove debug information
-assumenosideeffects class android.util.Log {
    public static boolean isLoggable(java.lang.String, int);
    public static int v(...);
    public static int i(...);
    public static int w(...);
    public static int d(...);
    public static int e(...);
}

# Optimize
-optimizations !code/simplification/arithmetic,!code/simplification/cast,!field/*,!class/merging/*
-optimizationpasses 5
-allowaccessmodification
-dontpreverify
