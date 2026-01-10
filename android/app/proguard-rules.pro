# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-keep class io.flutter.embedding.** { *; }

# Google Play Services / Play Core (Fixes R8 missing classes)
-dontwarn com.google.android.play.core.**
-dontwarn com.google.android.gms.**
-dontwarn io.flutter.embedding.android.FlutterPlayStoreSplitApplication

# Firebase
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# WebRTC
-keep class org.webrtc.** { *; }
-dontwarn org.webrtc.**

# Firebase Messaging (Notifications)
-keep class com.google.firebase.messaging.** { *; }
-keep class com.google.firebase.iid.** { *; }
-dontwarn com.google.firebase.messaging.**

# Audio Players (Native audio playback)
-keep class xyz.luan.audioplayers.** { *; }
-dontwarn xyz.luan.audioplayers.**

# Gson (Used by many plugins for JSON serialization)
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# Prevent obfuscation of specialized classes
-keep class com.veil.bluff.models.** { *; }

# Fix for potential "fta" error (often related to obfuscated core exceptions)
-keep class java.lang.Exception { *; }
-keep class java.util.** { *; }
-keepattributes Signature,SourceFile,LineNumberTable
