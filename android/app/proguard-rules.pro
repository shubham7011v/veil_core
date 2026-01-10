# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# WebRTC
-keep class org.webrtc.** { *; }
-dontwarn org.webrtc.**

# Prevent obfuscation of specialized classes
-keep class com.veil.bluff.models.** { *; }
