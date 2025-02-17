# Keep Jackson classes
-keep class com.fasterxml.jackson.** { *; }
-dontwarn com.fasterxml.jackson.databind.**

# Keep Java beans
-keep class java.beans.** { *; }
-dontwarn java.beans.**

# Keep DOM classes
-keep class org.w3c.dom.** { *; }
-dontwarn org.w3c.dom.**

# Keep constructor properties
-keepclassmembers class * {
    @java.beans.ConstructorProperties *;
}

# Keep transient annotation
-keepclassmembers class * {
    @java.beans.Transient *;
}

# Keep DOM implementation registry
-keep class org.w3c.dom.bootstrap.** { *; }
-dontwarn org.w3c.dom.bootstrap.** 