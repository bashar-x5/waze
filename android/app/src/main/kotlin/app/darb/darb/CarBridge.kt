package app.darb.darb

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

data class CarRoutePoint(
    val lat: Double,
    val lon: Double
)

data class CarNavState(
    val isNavigating: Boolean = false,
    val instruction: String = "",
    val distanceText: String = "",
    val stepDistanceMeters: Double = 0.0,
    val remainingMeters: Double = 0.0,
    val remainingSeconds: Int = 0,
    val etaText: String = "",
    val remainingDistanceText: String = "",
    val roadName: String = "",
    val maneuverType: Int = 1, // Default straight
    val speedKmh: Int = 0,
    val heading: Float = 0f,
    val lat: Double = 33.3152, // Default Baghdad Center
    val lon: Double = 44.3661,
    val destName: String = "",
    val destLat: Double = 0.0,
    val destLon: Double = 0.0,
    val routePoints: List<CarRoutePoint> = emptyList(),
    val arabic: Boolean = true,
    val dark: Boolean = true,
    val satellite: Boolean = false,
    val hasTraffic: Boolean = false,
    val trafficDelayMin: Int = 0,
    val homeTitle: String = "",
    val homeLat: Double = 0.0,
    val homeLon: Double = 0.0,
    val workTitle: String = "",
    val workLat: Double = 0.0,
    val workLon: Double = 0.0,
    val parkedLat: Double = 0.0,
    val parkedLon: Double = 0.0
)

data class CarSavedPlace(
    val id: String,
    val title: String,
    val subtitle: String,
    val lat: Double,
    val lon: Double
)

data class CarSearchResult(
    val id: String,
    val title: String,
    val subtitle: String,
    val lat: Double,
    val lon: Double,
    val distanceText: String = ""
)

object CarBridge : MethodChannel.MethodCallHandler {
    private const val CHANNEL_NAME = "app.darb.darb/android_auto"
    private var channel: MethodChannel? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    var currentState = CarNavState()
        private set

    var savedPlaces = mutableListOf<CarSavedPlace>()
        private set

    var searchResults = mutableListOf<CarSearchResult>()
        private set

    private val stateListeners = mutableSetOf<StateListener>()

    var searchListener: SearchListener? = null

    val isRegistered: Boolean
        get() = channel != null

    interface StateListener {
        fun onStateChanged(state: CarNavState)
        fun onSavedPlacesChanged(places: List<CarSavedPlace>)
    }

    interface SearchListener {
        fun onSearchResultsChanged(results: List<CarSearchResult>)
        fun onSearchStatusChanged(status: String)
    }

    fun addStateListener(listener: StateListener) {
        stateListeners.add(listener)
        listener.onStateChanged(currentState)
        listener.onSavedPlacesChanged(savedPlaces)
    }

    fun removeStateListener(listener: StateListener) {
        stateListeners.remove(listener)
    }

    var stateListener: StateListener?
        get() = stateListeners.firstOrNull()
        set(value) {
            stateListeners.clear()
            if (value != null) {
                addStateListener(value)
            }
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
                val stepDistanceMeters = (args?.get("stepDistanceMeters") as? Number)?.toDouble() ?: 0.0
                val remainingMeters = (args?.get("remainingMeters") as? Number)?.toDouble() ?: 0.0
                val remainingSeconds = (args?.get("remainingSeconds") as? Number)?.toInt() ?: 0
                val etaText = args?.get("etaText") as? String ?: ""
                val remainingDist = args?.get("remainingDistanceText") as? String ?: ""
                val roadName = args?.get("roadName") as? String ?: ""
                val maneuver = (args?.get("maneuverType") as? Number)?.toInt() ?: 1
                val speedKmh = (args?.get("speedKmh") as? Number)?.toInt() ?: 0
                val heading = (args?.get("heading") as? Number)?.toFloat() ?: 0f
                val lat = (args?.get("lat") as? Number)?.toDouble() ?: 33.3152
                val lon = (args?.get("lon") as? Number)?.toDouble() ?: 44.3661
                val destName = args?.get("destName") as? String ?: ""
                val destLat = (args?.get("destLat") as? Number)?.toDouble() ?: 0.0
                val destLon = (args?.get("destLon") as? Number)?.toDouble() ?: 0.0

                val routePointsList = mutableListOf<CarRoutePoint>()
                (args?.get("routePoints") as? List<*>)?.forEach { pt ->
                    if (pt is Map<*, *>) {
                        val pLat = (pt["lat"] as? Number)?.toDouble() ?: 0.0
                        val pLon = (pt["lon"] as? Number)?.toDouble() ?: 0.0
                        if (pLat != 0.0 || pLon != 0.0) {
                            routePointsList.add(CarRoutePoint(pLat, pLon))
                        }
                    }
                }

                val arabic = args?.get("arabic") as? Boolean ?: true
                val dark = args?.get("dark") as? Boolean ?: true
                val satellite = args?.get("satellite") as? Boolean ?: false
                val hasTraffic = args?.get("hasTraffic") as? Boolean ?: false
                val trafficDelayMin = (args?.get("trafficDelayMin") as? Number)?.toInt() ?: 0
                val homeTitle = args?.get("homeTitle") as? String ?: ""
                val homeLat = (args?.get("homeLat") as? Number)?.toDouble() ?: 0.0
                val homeLon = (args?.get("homeLon") as? Number)?.toDouble() ?: 0.0
                val workTitle = args?.get("workTitle") as? String ?: ""
                val workLat = (args?.get("workLat") as? Number)?.toDouble() ?: 0.0
                val workLon = (args?.get("workLon") as? Number)?.toDouble() ?: 0.0
                val parkedLat = (args?.get("parkedLat") as? Number)?.toDouble() ?: 0.0
                val parkedLon = (args?.get("parkedLon") as? Number)?.toDouble() ?: 0.0

                currentState = CarNavState(
                    isNavigating = isNavigating,
                    instruction = instruction,
                    distanceText = distanceText,
                    stepDistanceMeters = stepDistanceMeters,
                    remainingMeters = remainingMeters,
                    remainingSeconds = remainingSeconds,
                    etaText = etaText,
                    remainingDistanceText = remainingDist,
                    roadName = roadName,
                    maneuverType = maneuver,
                    speedKmh = speedKmh,
                    heading = heading,
                    lat = lat,
                    lon = lon,
                    destName = destName,
                    destLat = destLat,
                    destLon = destLon,
                    routePoints = routePointsList,
                    arabic = arabic,
                    dark = dark,
                    satellite = satellite,
                    hasTraffic = hasTraffic,
                    trafficDelayMin = trafficDelayMin,
                    homeTitle = homeTitle,
                    homeLat = homeLat,
                    homeLon = homeLon,
                    workTitle = workTitle,
                    workLat = workLat,
                    workLon = workLon,
                    parkedLat = parkedLat,
                    parkedLon = parkedLon
                )

                mainHandler.post {
                    stateListeners.forEach { it.onStateChanged(currentState) }
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
                    stateListeners.forEach { it.onSavedPlacesChanged(savedPlaces) }
                }
                result.success(true)
            }
            "updateSearchResults" -> {
                val list = call.arguments as? List<*>
                val updated = mutableListOf<CarSearchResult>()
                list?.forEach { item ->
                    if (item is Map<*, *>) {
                        val id = item["id"] as? String ?: ""
                        val title = item["title"] as? String ?: ""
                        val subtitle = item["subtitle"] as? String ?: ""
                        val lat = (item["lat"] as? Number)?.toDouble() ?: 0.0
                        val lon = (item["lon"] as? Number)?.toDouble() ?: 0.0
                        val dist = item["distanceText"] as? String ?: ""
                        if (id.isNotEmpty()) {
                            updated.add(CarSearchResult(id, title, subtitle, lat, lon, dist))
                        }
                    }
                }
                searchResults = updated
                mainHandler.post {
                    searchListener?.onSearchResultsChanged(searchResults)
                }
                result.success(true)
            }
            "setSearchStatus" -> {
                val status = call.arguments as? String ?: ""
                mainHandler.post {
                    searchListener?.onSearchStatusChanged(status)
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

    fun notifyVoiceSearchSubmitted(query: String) {
        mainHandler.post {
            channel?.invokeMethod(
                "onVoiceSearchSubmitted",
                mapOf("query" to query)
            )
        }
    }

    fun notifySearchTextChanged(query: String) {
        mainHandler.post {
            channel?.invokeMethod(
                "onSearchQueryChanged",
                mapOf("query" to query)
            )
        }
    }
}
