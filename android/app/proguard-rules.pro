# TensorFlow Lite
-keep class org.tensorflow.** { *; }
-dontwarn org.tensorflow.**

# For GPU delegates (fixes your exact error)
-keep class org.tensorflow.lite.gpu.** { *; }
-dontwarn org.tensorflow.lite.gpu.**

# MLKit (if used)
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**
