# Keep all AndroidX Car App library classes, binders, and parcelables
-keep class androidx.car.app.** { *; }
-keep interface androidx.car.app.** { *; }

# Keep Darb Car App components
-keep class app.darb.darb.DarbCarAppService { *; }
-keep class app.darb.darb.DarbCarSession { *; }
-keep class app.darb.darb.DarbCarScreen { *; }
-keep class app.darb.darb.CarBridge { *; }
