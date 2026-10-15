package app.darb.darb

import android.content.Context
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val DEVICE_CHANNEL = "app.darb.darb/device"

    override fun provideFlutterEngine(context: Context): FlutterEngine? {
        return FlutterEngineCache.getInstance().get("darb_engine")
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        FlutterEngineCache.getInstance().put("darb_engine", flutterEngine)
        CarBridge.registerWith(flutterEngine.dartExecutor.binaryMessenger)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEVICE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getHardwareId" -> {
                    try {
                        val androidId = Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID)
                        result.success(androidId ?: "")
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "getDeviceInfo" -> {
                    try {
                        val androidId = Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID) ?: ""
                        val manufacturer = Build.MANUFACTURER ?: ""
                        val model = Build.MODEL ?: ""
                        val brand = Build.BRAND ?: ""
                        val fullModel = if (model.startsWith(manufacturer, ignoreCase = true)) {
                            model
                        } else {
                            "$manufacturer $model".trim()
                        }
                        
                        var userDeviceName = ""
                        try {
                            userDeviceName = Settings.Global.getString(contentResolver, "device_name") ?: ""
                            if (userDeviceName.isEmpty()) {
                                userDeviceName = Settings.Secure.getString(contentResolver, "bluetooth_name") ?: ""
                            }
                        } catch (_: Exception) {}

                        if (userDeviceName.isEmpty()) {
                            userDeviceName = fullModel
                        }

                        val osVersion = "Android ${Build.VERSION.RELEASE} (API ${Build.VERSION.SDK_INT})"

                        result.success(mapOf(
                            "androidId" to androidId,
                            "deviceModel" to fullModel,
                            "deviceName" to userDeviceName,
                            "osVersion" to osVersion,
                            "brand" to brand
                        ))
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        CarBridge.unregister()
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
