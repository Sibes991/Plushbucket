# Extra R8 rules for the Plushbucket release build, added to the generated
# android/app/proguard-rules.pro by the "Android for Google Play" workflow.
# Capacitor and its plugins ship their own rules too; these are a safety net
# so nothing the web layer calls by name gets renamed or removed.

# Capacitor core and every plugin class (looked up by name from JavaScript)
-keep class com.getcapacitor.** { *; }
-keep public class * extends com.getcapacitor.Plugin { *; }
-keep @com.getcapacitor.annotation.CapacitorPlugin class * { *; }
-keepclassmembers class * {
    @com.getcapacitor.PluginMethod public <methods>;
    @com.getcapacitor.annotation.PermissionCallback <methods>;
    @com.getcapacitor.annotation.ActivityCallback <methods>;
}

# Anything exposed to the WebView through addJavascriptInterface
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# Keep annotations (Capacitor reads them at run time) and line numbers,
# so crash reports in Play Console still point at the right place
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod,SourceFile,LineNumberTable
