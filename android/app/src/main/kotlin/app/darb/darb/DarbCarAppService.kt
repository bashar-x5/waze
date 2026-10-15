package app.darb.darb

import androidx.car.app.CarAppService
import androidx.car.app.Session
import androidx.car.app.validation.HostValidator
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor

class DarbCarAppService : CarAppService() {
    override fun createHostValidator(): HostValidator {
        // Allows connection from Android Auto head units, wireless dongles, and the Desktop Head Unit (DHU)
        return HostValidator.ALLOW_ALL_HOSTS_VALIDATOR
    }

    override fun onCreateSession(): Session {
        ensureFlutterEngine()
        return DarbCarSession()
    }

    private fun ensureFlutterEngine() {
        if (!CarBridge.isRegistered) {
            val engine = FlutterEngineCache.getInstance().get("darb_engine") ?: run {
                val newEngine = FlutterEngine(applicationContext)
                newEngine.dartExecutor.executeDartEntrypoint(
                    DartExecutor.DartEntrypoint.createDefault()
                )
                FlutterEngineCache.getInstance().put("darb_engine", newEngine)
                newEngine
            }
            CarBridge.registerWith(engine.dartExecutor.binaryMessenger)
        }
    }
}
