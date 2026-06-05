# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Supabase
-keep class io.supabase.** { *; }
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# Kotlin
-keep class kotlin.** { *; }
-keep class kotlinx.** { *; }

# Gson
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class com.google.gson.** { *; }

# Lottie
-keep class com.airbnb.lottie.** { *; }

# Notifications
-keep class com.dexterous.** { *; }

# Play Core — referenced by Flutter's deferred-components embedding but not
# bundled unless deferred components are used. Silence R8 and keep the classes.
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }
