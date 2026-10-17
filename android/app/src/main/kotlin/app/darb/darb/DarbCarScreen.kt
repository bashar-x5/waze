package app.darb.darb

import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.Rect
import android.view.Surface
import androidx.car.app.AppManager
import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.SurfaceCallback
import androidx.car.app.SurfaceContainer
import androidx.car.app.model.Action
import androidx.car.app.model.ActionStrip
import androidx.car.app.model.Distance
import androidx.car.app.model.Template
import androidx.car.app.navigation.NavigationManager
import androidx.car.app.navigation.NavigationManagerCallback
import androidx.car.app.navigation.model.Maneuver
import androidx.car.app.navigation.model.NavigationTemplate
import androidx.car.app.navigation.model.RoutingInfo
import androidx.car.app.navigation.model.Step
import androidx.car.app.navigation.model.TravelEstimate
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import java.time.ZonedDateTime
import java.util.concurrent.Executors

class DarbCarScreen(carContext: CarContext) : Screen(carContext),
    CarBridge.StateListener, SurfaceCallback {

    private val navManager: NavigationManager? = try {
        carContext.getCarService(NavigationManager::class.java)
    } catch (_: Exception) {
        null
    }

    private val appManager: AppManager? = try {
        carContext.getCarService(AppManager::class.java)
    } catch (_: Exception) {
        null
    }

    private val tileManager = CarTileManager(carContext)
    private var isNavigatingRegistered = false

    @Volatile
    private var currentSurface: Surface? = null
    private var surfaceWidth: Int = 1280
    private var surfaceHeight: Int = 720
    private var visibleArea: Rect? = null
    private val renderExecutor = Executors.newSingleThreadExecutor()

    init {
        CarBridge.addStateListener(this)

        try {
            appManager?.setSurfaceCallback(this)
        } catch (_: Exception) {}

        try {
            navManager?.setNavigationManagerCallback(object : NavigationManagerCallback {
                override fun onStopNavigation() {
                    CarBridge.notifyStopNavigation()
                }
                override fun onAutoDriveEnabled() {}
            })
        } catch (_: Exception) {}

        lifecycle.addObserver(LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_DESTROY) {
                CarBridge.removeStateListener(this)
                try {
                    appManager?.setSurfaceCallback(null)
                } catch (_: Exception) {}
                try {
                    navManager?.clearNavigationManagerCallback()
                } catch (_: Exception) {}
                currentSurface = null
                tileManager.clear()
                renderExecutor.shutdown()
            }
        })
    }

    // ---------------------------------------------------------
    // SurfaceCallback Lifecycle & Gestures
    // ---------------------------------------------------------

    override fun onSurfaceAvailable(surfaceContainer: SurfaceContainer) {
        synchronized(this) {
            currentSurface = surfaceContainer.surface
            surfaceWidth = surfaceContainer.width.coerceAtLeast(320)
            surfaceHeight = surfaceContainer.height.coerceAtLeast(240)
        }
        renderSurface()
    }

    override fun onSurfaceDestroyed(surfaceContainer: SurfaceContainer) {
        synchronized(this) {
            currentSurface = null
        }
    }

    override fun onVisibleAreaChanged(visibleArea: Rect) {
        this.visibleArea = visibleArea
        renderSurface()
    }

    override fun onStableAreaChanged(stableArea: Rect) {
        renderSurface()
    }

    override fun onScroll(distanceX: Float, distanceY: Float) {}
    override fun onFling(velocityX: Float, velocityY: Float) {}
    override fun onScale(focusX: Float, focusY: Float, scaleFactor: Float) {}
    override fun onClick(x: Float, y: Float) {}

    // ---------------------------------------------------------
    // CarBridge State Listener
    // ---------------------------------------------------------

    override fun onStateChanged(state: CarNavState) {
        try {
            if (state.isNavigating && !isNavigatingRegistered) {
                navManager?.navigationStarted()
                isNavigatingRegistered = true
            } else if (!state.isNavigating && isNavigatingRegistered) {
                navManager?.navigationEnded()
                isNavigatingRegistered = false
            }
        } catch (_: Exception) {}

        renderSurface()
        invalidate()
    }

    override fun onSavedPlacesChanged(places: List<CarSavedPlace>) {
        renderSurface()
        invalidate()
    }

    // ---------------------------------------------------------
    // Template Construction (CarPlay & Android Auto Standard)
    // ---------------------------------------------------------

    override fun onGetTemplate(): Template {
        val state = CarBridge.currentState
        return if (state.isNavigating) {
            buildNavigatingTemplate(state)
        } else {
            buildIdleTemplate(state)
        }
    }

    private fun buildNavigatingTemplate(state: CarNavState): Template {
        try {
            val voiceAction = Action.Builder()
                .setTitle(if (state.arabic) "🎤 بحث صوتي" else "🎤 Voice")
                .setOnClickListener {
                    screenManager.push(DarbCarSearchScreen(carContext))
                }
                .build()

            val stopAction = Action.Builder()
                .setTitle(if (state.arabic) "🛑 إنهاء" else "🛑 End")
                .setOnClickListener {
                    CarBridge.notifyStopNavigation()
                }
                .build()

            val actionStrip = ActionStrip.Builder()
                .addAction(voiceAction)
                .addAction(stopAction)
                .build()

            val maneuverType = when (state.maneuverType) {
                2 -> Maneuver.TYPE_TURN_SLIGHT_LEFT
                3 -> Maneuver.TYPE_TURN_NORMAL_LEFT
                4 -> Maneuver.TYPE_TURN_SHARP_LEFT
                5 -> Maneuver.TYPE_TURN_SLIGHT_RIGHT
                6 -> Maneuver.TYPE_TURN_NORMAL_RIGHT
                7 -> Maneuver.TYPE_TURN_SHARP_RIGHT
                8 -> Maneuver.TYPE_U_TURN_LEFT
                9 -> Maneuver.TYPE_DESTINATION
                else -> Maneuver.TYPE_STRAIGHT
            }

            val maneuver = Maneuver.Builder(maneuverType).build()

            val step = Step.Builder()
                .setManeuver(maneuver)
                .setRoad(state.roadName.ifBlank { state.instruction.ifBlank { "طريق الرحلة" } })
                .build()

            val distKm = if (state.stepDistanceMeters > 0) {
                (state.stepDistanceMeters / 1000.0).coerceAtLeast(0.05)
            } else {
                0.1
            }
            val distance = Distance.create(distKm, Distance.UNIT_KILOMETERS)

            val routingInfo = RoutingInfo.Builder()
                .setCurrentStep(step, distance)
                .build()

            val navBuilder = NavigationTemplate.Builder()
                .setActionStrip(actionStrip)
                .setNavigationInfo(routingInfo)

            try {
                val remDistKm = if (state.remainingMeters > 0) {
                    (state.remainingMeters / 1000.0).coerceAtLeast(0.1)
                } else distKm
                val remDistance = Distance.create(remDistKm, Distance.UNIT_KILOMETERS)
                val arrivalSec = state.remainingSeconds.toLong().coerceAtLeast(60L)
                val arrivalTime = ZonedDateTime.now().plusSeconds(arrivalSec)
                val travelEstimate = TravelEstimate.Builder(remDistance, arrivalTime)
                    .setRemainingTimeSeconds(arrivalSec)
                    .build()
                navBuilder.setDestinationTravelEstimate(travelEstimate)
            } catch (_: Exception) {}

            return navBuilder.build()
        } catch (_: Exception) {
            return buildIdleTemplate(state)
        }
    }

    private fun buildIdleTemplate(state: CarNavState): Template {
        try {
            val actions = ActionStrip.Builder()

            // 1. Voice Search Action
            actions.addAction(
                Action.Builder()
                    .setTitle(if (state.arabic) "🎤 بحث صوتي" else "🎤 Voice Search")
                    .setOnClickListener {
                        screenManager.push(DarbCarSearchScreen(carContext))
                    }
                    .build()
            )

            // 2. Home Quick Action (if available)
            if (state.homeLat != 0.0 && state.homeLon != 0.0) {
                actions.addAction(
                    Action.Builder()
                        .setTitle(if (state.arabic) "🏠 المنزل" else "🏠 Home")
                        .setOnClickListener {
                            CarBridge.notifyDestinationSelected("home", state.homeLat, state.homeLon)
                        }
                        .build()
                )
            }

            // 3. Work Quick Action (if available)
            if (state.workLat != 0.0 && state.workLon != 0.0) {
                actions.addAction(
                    Action.Builder()
                        .setTitle(if (state.arabic) "💼 العمل" else "💼 Work")
                        .setOnClickListener {
                            CarBridge.notifyDestinationSelected("work", state.workLat, state.workLon)
                        }
                        .build()
                )
            }

            // 4. Parked Car Action (if saved)
            if (state.parkedLat != 0.0 && state.parkedLon != 0.0) {
                actions.addAction(
                    Action.Builder()
                        .setTitle(if (state.arabic) "🅿️ سيارتي" else "🅿️ Parked Car")
                        .setOnClickListener {
                            CarBridge.notifyDestinationSelected("parked-car", state.parkedLat, state.parkedLon)
                        }
                        .build()
                )
            }

            // 5. Saved Places
            actions.addAction(
                Action.Builder()
                    .setTitle(if (state.arabic) "⭐ المفضلة" else "⭐ Saved")
                    .setOnClickListener {
                        screenManager.push(DarbCarSavedPlacesScreen(carContext))
                    }
                    .build()
            )

            return NavigationTemplate.Builder()
                .setActionStrip(actions.build())
                .build()
        } catch (_: Exception) {
            return NavigationTemplate.Builder().build()
        }
    }

    // ---------------------------------------------------------
    // High-Performance Map Surface Canvas Renderer (Matching Phone)
    // ---------------------------------------------------------

    private fun renderSurface() {
        renderExecutor.execute {
            val s = currentSurface ?: return@execute
            if (!s.isValid) return@execute

            val canvas = try {
                s.lockCanvas(null)
            } catch (_: Exception) {
                null
            } ?: return@execute

            try {
                drawNavigationMap(canvas)
            } catch (e: Exception) {
                e.printStackTrace()
            } finally {
                try {
                    s.unlockCanvasAndPost(canvas)
                } catch (_: Exception) {}
            }
        }
    }

    private fun drawNavigationMap(canvas: Canvas) {
        val w = canvas.width.toFloat().coerceAtLeast(640f)
        val h = canvas.height.toFloat().coerceAtLeast(400f)
        val state = CarBridge.currentState
        val dark = state.dark
        val isSatellite = state.satellite

        // 1. Canvas Base Background
        val bgColor = if (isSatellite) {
            Color.parseColor("#06090E")
        } else if (dark) {
            Color.parseColor("#0F1722")
        } else {
            Color.parseColor("#E8EEF3")
        }
        canvas.drawColor(bgColor)

        // 2. Web Mercator Projection Setup (Zoom 16 for rich urban street details)
        val zoom = 16
        val worldSize = (1 shl zoom) * 256.0
        val latClamped = state.lat.coerceIn(-85.05112878, 85.05112878)
        val worldX = ((state.lon + 180.0) / 360.0) * worldSize
        val latRad = Math.toRadians(latClamped)
        val worldY = ((1.0 - Math.log(Math.tan(latRad) + 1.0 / Math.cos(latRad)) / Math.PI) / 2.0) * worldSize

        val carX = w * 0.5f
        val carY = if (state.isNavigating) h * 0.62f else h * 0.5f

        canvas.save()
        canvas.translate(carX, carY)
        if (state.isNavigating) {
            canvas.rotate(-state.heading)
        }

        // 3. Render Real Vector/Raster Map Tiles
        val radius = Math.hypot(w.toDouble(), h.toDouble()).toFloat() * 0.65f
        val minWorldX = worldX - radius
        val maxWorldX = worldX + radius
        val minWorldY = worldY - radius
        val maxWorldY = worldY + radius

        val minTileX = (minWorldX / 256.0).toInt().coerceAtLeast(0)
        val maxTileX = (maxWorldX / 256.0).toInt().coerceAtMost((1 shl zoom) - 1)
        val minTileY = (minWorldY / 256.0).toInt().coerceAtLeast(0)
        val maxTileY = (maxWorldY / 256.0).toInt().coerceAtMost((1 shl zoom) - 1)

        val placeholderPaint = Paint().apply {
            color = if (dark) Color.parseColor("#152238") else Color.parseColor("#D5DEE5")
            style = Paint.Style.STROKE
            strokeWidth = 1f
        }

        for (tx in minTileX..maxTileX) {
            for (ty in minTileY..maxTileY) {
                val tileBmp = tileManager.getTile(zoom, tx, ty, isSatellite, dark) {
                    renderSurface()
                }
                val drawX = (tx * 256.0 - worldX).toFloat()
                val drawY = (ty * 256.0 - worldY).toFloat()

                if (tileBmp != null && !tileBmp.isRecycled) {
                    canvas.drawBitmap(tileBmp, drawX, drawY, null)
                } else {
                    canvas.drawRect(drawX, drawY, drawX + 256f, drawY + 256f, placeholderPaint)
                }
            }
        }

        // 4. Render Active Route Polyline Along Real Streets
        if (state.isNavigating && state.routePoints.isNotEmpty()) {
            val routeGlow = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = if (state.hasTraffic && state.trafficDelayMin > 3) {
                    Color.parseColor("#55EF4444")
                } else if (state.hasTraffic) {
                    Color.parseColor("#55F59E0B")
                } else {
                    Color.parseColor("#4400D2FF")
                }
                style = Paint.Style.STROKE
                strokeWidth = 26f
                strokeCap = Paint.Cap.ROUND
                strokeJoin = Paint.Join.ROUND
            }
            val routeMain = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = if (state.hasTraffic && state.trafficDelayMin > 3) {
                    Color.parseColor("#EF4444") // Heavy traffic
                } else if (state.hasTraffic) {
                    Color.parseColor("#F59E0B") // Moderate traffic
                } else {
                    Color.parseColor("#00D2FF") // Fast flow / Darb Cyan
                }
                style = Paint.Style.STROKE
                strokeWidth = 13f
                strokeCap = Paint.Cap.ROUND
                strokeJoin = Paint.Join.ROUND
            }
            val routeCore = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.WHITE
                style = Paint.Style.STROKE
                strokeWidth = 3f
                strokeCap = Paint.Cap.ROUND
                strokeJoin = Paint.Join.ROUND
            }

            val routePath = Path()
            var hasFirst = false

            for (pt in state.routePoints) {
                val ptLatClamped = pt.lat.coerceIn(-85.05112878, 85.05112878)
                val ptWorldX = ((pt.lon + 180.0) / 360.0) * worldSize - worldX
                val ptLatRad = Math.toRadians(ptLatClamped)
                val ptWorldY = ((1.0 - Math.log(Math.tan(ptLatRad) + 1.0 / Math.cos(ptLatRad)) / Math.PI) / 2.0) * worldSize - worldY

                if (!hasFirst) {
                    routePath.moveTo(ptWorldX.toFloat(), ptWorldY.toFloat())
                    hasFirst = true
                } else {
                    routePath.lineTo(ptWorldX.toFloat(), ptWorldY.toFloat())
                }
            }

            canvas.drawPath(routePath, routeGlow)
            canvas.drawPath(routePath, routeMain)
            canvas.drawPath(routePath, routeCore)

            // Destination Marker Pin
            if (state.destLat != 0.0 && state.destLon != 0.0) {
                val destLatClamped = state.destLat.coerceIn(-85.05112878, 85.05112878)
                val destWorldX = (((state.destLon + 180.0) / 360.0) * worldSize - worldX).toFloat()
                val destLatRad = Math.toRadians(destLatClamped)
                val destWorldY = (((1.0 - Math.log(Math.tan(destLatRad) + 1.0 / Math.cos(destLatRad)) / Math.PI) / 2.0) * worldSize - worldY).toFloat()

                val pinShadow = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = Color.parseColor("#50000000")
                    style = Paint.Style.FILL
                }
                val pinPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = Color.parseColor("#EF4444")
                    style = Paint.Style.FILL
                }
                val pinBorder = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = Color.WHITE
                    style = Paint.Style.STROKE
                    strokeWidth = 4f
                }
                canvas.drawCircle(destWorldX, destWorldY + 3f, 20f, pinShadow)
                canvas.drawCircle(destWorldX, destWorldY, 18f, pinPaint)
                canvas.drawCircle(destWorldX, destWorldY, 18f, pinBorder)

                // White inner dot
                val pinDot = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = Color.WHITE
                    style = Paint.Style.FILL
                }
                canvas.drawCircle(destWorldX, destWorldY, 6f, pinDot)
            }
        }

        // Restore canvas from world coordinates to screen pixel coordinates
        canvas.restore()

        // -------------------------------------------------------------
        // 5. Draw Car Puck (Chevron matching Phone exactly)
        // -------------------------------------------------------------
        val puckAngle = if (state.isNavigating) 0f else state.heading

        // Pulse Halo Ring
        val haloPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#3500D2FF")
            style = Paint.Style.FILL
        }
        canvas.drawCircle(carX, carY, 36f, haloPaint)

        // Shadow
        val puckShadow = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#45000000")
            style = Paint.Style.FILL
        }
        canvas.drawCircle(carX, carY + 3f, 22f, puckShadow)

        // White base circle
        val puckBase = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
            style = Paint.Style.FILL
        }
        canvas.drawCircle(carX, carY, 20f, puckBase)

        // Cyan inner circle
        val puckInner = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#00D2FF")
            style = Paint.Style.FILL
        }
        canvas.drawCircle(carX, carY, 16f, puckInner)

        // Navigation Chevron Triangle pointing in heading direction
        canvas.save()
        canvas.rotate(puckAngle, carX, carY)
        val chevronPath = Path().apply {
            moveTo(carX, carY - 10f)
            lineTo(carX - 7f, carY + 7f)
            lineTo(carX, carY + 3f)
            lineTo(carX + 7f, carY + 7f)
            close()
        }
        val chevronPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
            style = Paint.Style.FILL
        }
        canvas.drawPath(chevronPath, chevronPaint)
        canvas.restore()

        // -------------------------------------------------------------
        // 6. UI Overlays (Matching Phone Landscape Layout)
        // -------------------------------------------------------------

        // Speedometer (Waze Circular Glass Badge)
        val spCenter = w - 62f
        val spY = h - 62f
        val spRadius = 38f

        val spBg = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#E60F172A")
            style = Paint.Style.FILL
        }
        val spRing = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#00D2FF")
            style = Paint.Style.STROKE
            strokeWidth = 3f
        }
        canvas.drawCircle(spCenter, spY, spRadius, spBg)
        canvas.drawCircle(spCenter, spY, spRadius, spRing)

        val spNumText = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
            textSize = 28f
            textAlign = Paint.Align.CENTER
            isFakeBoldText = true
        }
        val spUnitText = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#38BDF8")
            textSize = 10f
            textAlign = Paint.Align.CENTER
            isFakeBoldText = true
        }
        canvas.drawText("${state.speedKmh}", spCenter, spY + 4f, spNumText)
        canvas.drawText(if (state.arabic) "كم/س" else "km/h", spCenter, spY + 20f, spUnitText)

        // Orange Report Button
        val repCenter = w - 148f
        val repY = h - 62f
        val repRadius = 26f
        val repBg = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#FF6D00")
            style = Paint.Style.FILL
        }
        val repShadow = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#40000000")
            style = Paint.Style.FILL
        }
        canvas.drawCircle(repCenter, repY + 2f, repRadius, repShadow)
        canvas.drawCircle(repCenter, repY, repRadius, repBg)
        val repIconText = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
            textSize = 22f
            textAlign = Paint.Align.CENTER
        }
        canvas.drawText("📢", repCenter, repY + 8f, repIconText)

        // App Status Branding Badge (Top Right)
        val brandBox = android.graphics.RectF(w - 170f, 16f, w - 16f, 52f)
        val brandBg = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#D90F172A")
            style = Paint.Style.FILL
        }
        val brandBorder = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#00D2FF")
            style = Paint.Style.STROKE
            strokeWidth = 1.5f
        }
        canvas.drawRoundRect(brandBox, 12f, 12f, brandBg)
        canvas.drawRoundRect(brandBox, 12f, 12f, brandBorder)

        val brandDot = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#00E676")
            style = Paint.Style.FILL
        }
        canvas.drawCircle(brandBox.left + 16f, brandBox.centerY(), 5f, brandDot)

        val brandText = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
            textSize = 13f
            isFakeBoldText = true
        }
        val brandLabel = if (state.isNavigating) {
            if (state.arabic) "درب • ملاحة مباشرة" else "Darb • Navigating"
        } else {
            if (state.arabic) "درب • متصل بالسيارة" else "Darb • Connected"
        }
        canvas.drawText(brandLabel, brandBox.left + 30f, brandBox.centerY() + 5f, brandText)
    }
}
