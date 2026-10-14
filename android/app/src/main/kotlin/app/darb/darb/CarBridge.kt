package app.darb.darb

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

data class CarNavState(
    val isNavigating: Boolean = false,
    val instruction: String = "",
    val distanceText: String = "",
    val etaText: String = "",
    val remainingDistanceText: String = "",
    val roadName: String = "",
    val maneuverType: Int = 1 // Default straight
)

data class CarSavedPlace(
    val id: String,
    val title: String,
    val subtitle: String,
    val lat: Double,
    val lon: Double
)

object CarBridge : MethodChannel.MethodCallHandler {
    private const val CHANNEL_NAME = "app.darb.darb/android_auto"
    private var channel: MethodChannel? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    var currentState = CarNavState()
        private set

    var savedPlaces = mutableListOf<CarSavedPlace>()
        private set

    var stateListener: StateListener? = null
        set(value) {
            field = value
            value?.onStateChanged(currentState)
            value?.onSavedPlacesChanged(savedPlaces)
        }

    interface StateListener {
        fun onStateChanged(state: CarNavState)
        fun onSavedPlacesChanged(places: List<CarSavedPlace>)
    }

    fun registerWith(messenger: BinaryMessenger) {
        val ch = MethodChannel(messenger, CHANNEL_NAME)
        ch.setMethodCallHandler(this)
        channel = ch
    }

    fun unregister() {
        channel?.setMethodCallHandler(null)
        channel = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "updateNavState" -> {
                val args = call.arguments as? Map<*, *>
                val isNavigating = args?.get("isNavigating") as? Boolean ?: false
                val instruction = args?.get("instruction") as? String ?: ""
                val distanceText = args?.get("distanceText") as? String ?: ""
                val etaText = args?.get("etaText") as? String ?: ""
                val remainingDist = args?.get("remainingDistanceText") as? String ?: ""
                val roadName = args?.get("roadName") as? String ?: ""
                val maneuver = (args?.get("maneuverType") as? Number)?.toInt() ?: 1

                currentState = CarNavState(
                    isNavigating = isNavigating,
                    instruction = instruction,
                    distanceText = distanceText,
                    etaText = etaText,
                    remainingDistanceText = remainingDist,
                    roadName = roadName,
                    maneuverType = maneuver
                )

                mainHandler.post {
                    stateListener?.onStateChanged(currentState)
                }
                result.success(true)
            }
            "updateSavedPlaces" -> {
                val list = call.arguments as? List<*>
                val updated = mutableListOf<CarSavedPlace>()
                list?.forEach { item ->
                    if (item is Map<*, *>) {
                        val id = item["id"] as? String ?: ""
                        val title = item["title"] as? String ?: ""
                        val subtitle = item["subtitle"] as? String ?: ""
                        val lat = (item["lat"] as? Number)?.toDouble() ?: 0.0
                        val lon = (item["lon"] as? Number)?.toDouble() ?: 0.0
                        if (id.isNotEmpty() && (lat != 0.0 || lon != 0.0)) {
                            updated.add(CarSavedPlace(id, title, subtitle, lat, lon))
                        }
                    }
                }
                savedPlaces = updated
                mainHandler.post {
                    stateListener?.onSavedPlacesChanged(savedPlaces)
                }
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    fun notifyDestinationSelected(placeId: String, lat: Double, lon: Double) {
        mainHandler.post {
            channel?.invokeMethod(
                "onDestinationSelected",
                mapOf("id" to placeId, "lat" to lat, "lon" to lon)
            )
        }
    }

    fun notifyStopNavigation() {
        mainHandler.post {
            channel?.invokeMethod("onStopNavigation", null)
        }
    }
}
