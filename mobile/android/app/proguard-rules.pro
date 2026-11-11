# Firebase discovers its components by reflection (ComponentRegistrar no-arg
# constructors). R8 full mode strips them, which breaks Crashlytics and
# Installations in release builds ("Firebase could not start").
-keep class * implements com.google.firebase.components.ComponentRegistrar { <init>(); }
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
