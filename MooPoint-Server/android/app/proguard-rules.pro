# Keep OkHttp classes for image_cropper
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-dontwarn okhttp3.**

# Keep UCrop classes
-keep class com.yalantis.ucrop.** { *; }
-keep interface com.yalantis.ucrop.** { *; }

# Keep any other classes that might be needed
-keep class com.bumptech.glide.** { *; }
-keep interface com.bumptech.glide.** { *; }

# Keep model classes
-keep class android.support.v7.** { *; }
-keep class androidx.** { *; }

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep custom views
-keep public class * extends android.view.View {
    public <init>(android.content.Context);
    public <init>(android.content.Context, android.util.AttributeSet);
    public <init>(android.content.Context, android.util.AttributeSet, int);
    public void set*(...);
}

# Keep classes that might be dynamically loaded
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}
