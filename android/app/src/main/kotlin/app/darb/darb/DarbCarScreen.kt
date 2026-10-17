package app.darb.darb

import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.Rect
import android.graphics.RectF
import android.view.Surface
import androidx.car.app.AppManager
import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.SurfaceCallback
import androidx.car.app.SurfaceContainer
import androidx.car.app.model.Action
import androidx.car.app.model.ActionStrip
import androidx.car.app.model.Distance
import androidx.car.app.model.ItemList
import androidx.car.app.model.ListTemplate
import androidx.car.app.model.Row
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
import kotlin.math.cos
import kotlin.math.sin

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
    // Template Construction
    // ---------------------------------------------------------

    override fun onGetTemplate(): Template {
        val state = CarBridge.currentState
        return if (state.isNavigating) {
            buildNavigatingTemplate(state)
        } else {
            buildIdleTemplate()
        }
    }

    private fun buildNavigatingTemplate(state: CarNavState): Template {
        try {
            val voiceAction = Action.Builder()
                .setTitle("صوتي / Voice")
                .setOnClickListener {
                    screenManager.push(DarbCarSearchScreen(carContext))
                }
                .build()

            val stopAction = Action.Builder()
                .setTitle("إنهاء / Stop")
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
                .setRoad(state.roadName.ifBlank { "طريق الرحلة" })
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
            return buildIdleTemplate()
        }
    }

    private fun buildIdleTemplate(): Template {
        try {
            val voiceAction = Action.Builder()
                .setTitle("🎤 بحث صوتي / Voice")
                .setOnClickListener {
                    screenManager.push(DarbCarSearchScreen(carContext))
                }
                .build()

            val savedAction = Action.Builder()
                .setTitle("⭐ المحفوظة / Saved")
                .setOnClickListener {
                    screenManager.push(DarbCarSavedPlacesScreen(carContext))
                }
                .build()

            val refreshAction = Action.Builder()
                .setTitle("🔄 تمركز / Center")
                .setOnClickListener {
                    renderSurface()
                    invalidate()
                }
                .build()

            val actionStrip = ActionStrip.Builder()
                .addAction(voiceAction)
                .addAction(savedAction)
                .addAction(refreshAction)
                .build()

            return NavigationTemplate.Builder()
                .setActionStrip(actionStrip)
                .build()
        } catch (_: Exception) {
            // Graceful fallback to ListTemplate if host enforces it
            val listBuilder = ItemList.Builder()
            listBuilder.addItem(
                Row.Builder()
                    .setTitle("🎤 بحث صوتي / Voice Navigation")
                    .addText("قل: 'اريد الذهاب لساحة الفردوس'")
                    .setOnClickListener {
                        screenManager.push(DarbCarSearchScreen(carContext))
                    }
                    .build()
            )
            for (p in CarBridge.savedPlaces.take(4)) {
                listBuilder.addItem(
                    Row.Builder()
                        .setTitle(p.title)
                        .addText(p.subtitle)
                        .setOnClickListener {
                            CarBridge.notifyDestinationSelected(p.id, p.lat, p.lon)
                        }
                        .build()
                )
            }
            return ListTemplate.Builder()
                .setTitle("درب - Darb")
                .setHeaderAction(Action.APP_ICON)
                .setSingleList(listBuilder.build())
                .build()
        }
    }

    // ---------------------------------------------------------
    // High-Performance Map Surface Canvas Renderer
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

        // 1. Deep Midnight Slate Canvas Background
        canvas.drawColor(Color.parseColor("#090E17"))

        // 2. City Blocks & Baghdad Urban Texture
        val blockPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#0F1726")
            style = Paint.Style.FILL
        }
        val blockBorder = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#152238")
            style = Paint.Style.STROKE
            strokeWidth = 2f
        }

        val blockSize = 140f
        var bx = 10f
        while (bx < w) {
            var by = 10f
            while (by < h) {
                val rect = RectF(bx, by, bx + blockSize - 20f, by + blockSize - 20f)
                canvas.drawRoundRect(rect, 12f, 12f, blockPaint)
                canvas.drawRoundRect(rect, 12f, 12f, blockBorder)
                by += blockSize
            }
            bx += blockSize
        }

        // 3. Tigris River Curve Across Baghdad
        val riverPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#0C2C3D")
            style = Paint.Style.STROKE
            strokeWidth = 55f
            strokeCap = Paint.Cap.ROUND
            strokeJoin = Paint.Join.ROUND
        }
        val riverPath = Path().apply {
            moveTo(w * 0.15f, -20f)
            cubicTo(w * 0.35f, h * 0.3f, w * 0.25f, h * 0.65f, w * 0.45f, h + 30f)
        }
        canvas.drawPath(riverPath, riverPaint)

        // 4. Major Baghdad Expressways & Arterials
        val roadOutlinePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#1D2D45")
            style = Paint.Style.STROKE
            strokeWidth = 22f
            strokeCap = Paint.Cap.ROUND
            strokeJoin = Paint.Join.ROUND
        }
        val roadSurfacePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#263B59")
            style = Paint.Style.STROKE
            strokeWidth = 14f
            strokeCap = Paint.Cap.ROUND
            strokeJoin = Paint.Join.ROUND
        }

        // Arterial corridor 1: Mohammed Al-Qassim Expressway
        val expresswayPath = Path().apply {
            moveTo(-20f, h * 0.35f)
            lineTo(w * 0.5f, h * 0.42f)
            lineTo(w + 30f, h * 0.48f)
        }
        canvas.drawPath(expresswayPath, roadOutlinePaint)
        canvas.drawPath(expresswayPath, roadSurfacePaint)

        // Arterial corridor 2: 14th of July / Airport Highway
        val highwayPath = Path().apply {
            moveTo(w * 0.52f, -20f)
            lineTo(w * 0.48f, h + 30f)
        }
        canvas.drawPath(highwayPath, roadOutlinePaint)
        canvas.drawPath(highwayPath, roadSurfacePaint)

        // 5. Vehicle Position & Projection
        val carX = w * 0.5f
        val carY = if (state.isNavigating) h * 0.65f else h * 0.5f
        val headingRad = Math.toRadians(-state.heading.toDouble())
        val cosH = cos(headingRad)
        val sinH = sin(headingRad)

        // 6. Active Navigation Route Polyline
        if (state.isNavigating) {
            val routeGlow = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.parseColor("#3500D2FF")
                style = Paint.Style.STROKE
                strokeWidth = 28f
                strokeCap = Paint.Cap.ROUND
                strokeJoin = Paint.Join.ROUND
            }
            val routeMain = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.parseColor("#00D2FF")
                style = Paint.Style.STROKE
                strokeWidth = 14f
                strokeCap = Paint.Cap.ROUND
                strokeJoin = Paint.Join.ROUND
            }
            val routeCore = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.parseColor("#E0F7FA")
                style = Paint.Style.STROKE
                strokeWidth = 4f
                strokeCap = Paint.Cap.ROUND
                strokeJoin = Paint.Join.ROUND
            }

            val routePath = Path()

            if (state.routePoints.isNotEmpty()) {
                val metersPerPx = 1.6
                var hasFirst = false
                for (pt in state.routePoints) {
                    val dLatMeters = (pt.lat - state.lat) * 111320.0
                    val dLonMeters = (pt.lon - state.lon) * (111320.0 * cos(Math.toRadians(state.lat)))
                    val rx = (dLonMeters * cosH - dLatMeters * sinH) / metersPerPx
                    val ry = (dLonMeters * sinH + dLatMeters * cosH) / metersPerPx
                    val sx = (carX + rx).toFloat()
                    val sy = (carY - ry).toFloat()

                    if (!hasFirst) {
                        routePath.moveTo(sx, sy)
                        hasFirst = true
                    } else {
                        routePath.lineTo(sx, sy)
                    }
                }
            } else {
                // Dynamic projected route curve based on current maneuver
                routePath.moveTo(carX, carY)
                when (state.maneuverType) {
                    2 -> routePath.cubicTo(carX, carY - 80f, carX - 60f, carY - 180f, carX - 120f, carY - 260f)
                    3, 4 -> routePath.cubicTo(carX, carY - 60f, carX - 80f, carY - 120f, carX - 220f, carY - 130f)
                    5 -> routePath.cubicTo(carX, carY - 80f, carX + 60f, carY - 180f, carX + 120f, carY - 260f)
                    6, 7 -> routePath.cubicTo(carX, carY - 60f, carX + 80f, carY - 120f, carX + 220f, carY - 130f)
                    8 -> routePath.cubicTo(carX, carY - 80f, carX - 120f, carY - 80f, carX - 120f, carY + 100f)
                    else -> routePath.lineTo(carX, carY - 320f)
                }
            }

            canvas.drawPath(routePath, routeGlow)
            canvas.drawPath(routePath, routeMain)
            canvas.drawPath(routePath, routeCore)

            // Destination Marker Pin
            if (state.destName.isNotBlank()) {
                val pinX = carX
                val pinY = carY - 280f
                val pinPulse = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = Color.parseColor("#4DF43F5E")
                    style = Paint.Style.FILL
                }
                val pinCore = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = Color.parseColor("#F43F5E")
                    style = Paint.Style.FILL
                }
                canvas.drawCircle(pinX, pinY, 20f, pinPulse)
                canvas.drawCircle(pinX, pinY, 10f, pinCore)

                val tagPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = Color.parseColor("#E60F172A")
                    style = Paint.Style.FILL
                }
                val tagText = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = Color.WHITE
                    textSize = 18f
                    textAlign = Paint.Align.CENTER
                    isFakeBoldText = true
                }
                val tagRect = RectF(pinX - 110f, pinY - 50f, pinX + 110f, pinY - 14f)
                canvas.drawRoundRect(tagRect, 8f, 8f, tagPaint)
                canvas.drawText(state.destName.take(18), pinX, pinY - 24f, tagText)
            }
        }

        // 7. 3D Aerodynamic Vehicle Navigation Puck (Chevron)
        val shadowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#66000000")
            style = Paint.Style.FILL
        }
        canvas.drawCircle(carX, carY + 4f, 24f, shadowPaint)

        val haloPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#3300E5FF")
            style = Paint.Style.FILL
        }
        canvas.drawCircle(carX, carY, 32f, haloPaint)

        canvas.save()
        // If navigating, forward is straight up (0 degrees); if idle, point according to heading
        val puckAngle = if (state.isNavigating) 0f else state.heading
        canvas.rotate(puckAngle, carX, carY)

        val leftWing = Path().apply {
            moveTo(carX, carY - 22f)
            lineTo(carX - 16f, carY + 16f)
            lineTo(carX, carY + 8f)
            close()
        }
        val leftPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#38BDF8")
            style = Paint.Style.FILL
        }
        canvas.drawPath(leftWing, leftPaint)

        val rightWing = Path().apply {
            moveTo(carX, carY - 22f)
            lineTo(carX + 16f, carY + 16f)
            lineTo(carX, carY + 8f)
            close()
        }
        val rightPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#0284C7")
            style = Paint.Style.FILL
        }
        canvas.drawPath(rightWing, rightPaint)

        val spinePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
            style = Paint.Style.STROKE
            strokeWidth = 2.5f
            strokeCap = Paint.Cap.ROUND
        }
        canvas.drawLine(carX, carY - 22f, carX, carY + 8f, spinePaint)
        canvas.restore()

        // 8. Top-Right HUD: Digital Speedometer
        val speedBox = RectF(w - 150f, 20f, w - 24f, 95f)
        val hudBg = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#D90A101D")
            style = Paint.Style.FILL
        }
        val hudBorder = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#22334F")
            style = Paint.Style.STROKE
            strokeWidth = 2f
        }
        canvas.drawRoundRect(speedBox, 16f, 16f, hudBg)
        canvas.drawRoundRect(speedBox, 16f, 16f, hudBorder)

        val speedNum = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
            textSize = 34f
            textAlign = Paint.Align.CENTER
            isFakeBoldText = true
        }
        val speedUnit = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#38BDF8")
            textSize = 12f
            textAlign = Paint.Align.CENTER
            isFakeBoldText = true
        }
        canvas.drawText("${state.speedKmh}", speedBox.centerX(), speedBox.top + 42f, speedNum)
        canvas.drawText("كم/س • KM/H", speedBox.centerX(), speedBox.top + 64f, speedUnit)

        // 9. Bottom-Right HUD: Live Darb Navigation Status Badge
        val statusX = w - 170f
        val statusY = h - 28f
        val statusDot = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#10B981")
            style = Paint.Style.FILL
        }
        canvas.drawCircle(statusX - 12f, statusY - 5f, 6f, statusDot)

        val statusText = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#E2E8F0")
            textSize = 14f
            isFakeBoldText = true
        }
        canvas.drawText(if (state.isNavigating) "درب • ملاحة نشطة" else "درب • متصل ومستعد", statusX, statusY, statusText)

        // 10. Top-Left HUD: Compass Rose Dial
        val compassX = 54f
        val compassY = 56f
        canvas.drawCircle(compassX, compassY, 26f, hudBg)
        canvas.drawCircle(compassX, compassY, 26f, hudBorder)

        canvas.save()
        canvas.rotate(-state.heading, compassX, compassY)
        val northNeedle = Path().apply {
            moveTo(compassX, compassY - 18f)
            lineTo(compassX - 5f, compassY)
            lineTo(compassX + 5f, compassY)
            close()
        }
        val northPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#EF4444")
            style = Paint.Style.FILL
        }
        canvas.drawPath(northNeedle, northPaint)

        val southNeedle = Path().apply {
            moveTo(compassX, compassY + 18f)
            lineTo(compassX - 5f, compassY)
            lineTo(compassX + 5f, compassY)
            close()
        }
        val southPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#94A3B8")
            style = Paint.Style.FILL
        }
        canvas.drawPath(southNeedle, southPaint)
        canvas.restore()
    }
}
