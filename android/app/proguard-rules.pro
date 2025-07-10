# TensorFlow Lite
-keep class org.tensorflow.lite.** { *; }
-keep class org.tensorflow.lite.gpu.** { *; }
-keep class org.tensorflow.lite.nnapi.** { *; }
-keep class org.tensorflow.lite.support.** { *; }

# Keep GPU delegate classes
-keep class org.tensorflow.lite.gpu.GpuDelegate { *; }
-keep class org.tensorflow.lite.gpu.GpuDelegateFactory { *; }
-keep class org.tensorflow.lite.gpu.GpuDelegateFactory$Options { *; }

# Keep all native methods
-keepclassmembers class * {
    native <methods>;
}

# Flutter specific rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Camera plugin
-keep class io.flutter.plugins.camera.** { *; }

# Permission handler
-keep class com.baseflow.permissionhandler.** { *; }
