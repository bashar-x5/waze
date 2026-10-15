package app.darb.darb

import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.model.Action
import androidx.car.app.model.ActionStrip
import androidx.car.app.model.Distance
import androidx.car.app.model.ItemList
import androidx.car.app.model.PlaceListMapTemplate
import androidx.car.app.model.Row
import androidx.car.app.model.Template
import androidx.car.app.navigation.model.Maneuver
import androidx.car.app.navigation.model.NavigationTemplate
import androidx.car.app.navigation.model.RoutingInfo
import androidx.car.app.navigation.model.Step
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver

class DarbCarScreen(carContext: CarContext) : Screen(carContext), CarBridge.StateListener {

    init {
        CarBridge.addStateListener(this)

        lifecycle.addObserver(LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_DESTROY) {
                CarBridge.removeStateListener(this)
            }
        })
    }

    override fun onStateChanged(state: CarNavState) {
        invalidate()
    }

    override fun onSavedPlacesChanged(places: List<CarSavedPlace>) {
        invalidate()
    }

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

            val stepBuilder = Step.Builder()
                .setManeuver(maneuver)
                .setRoad(state.roadName.ifBlank { "طريق الرحلة" })

            val step = stepBuilder.build()

            // Dynamic distance calculation based on remaining step meters
            val distKm = if (state.stepDistanceMeters > 0) {
                (state.stepDistanceMeters / 1000.0).coerceAtLeast(0.05)
            } else {
                0.1
            }
            val distance = Distance.create(distKm, Distance.UNIT_KILOMETERS)

            val routingInfo = RoutingInfo.Builder()
                .setCurrentStep(step, distance)
                .build()

            return NavigationTemplate.Builder()
                .setActionStrip(actionStrip)
                .setNavigationInfo(routingInfo)
                .build()
        } catch (e: Exception) {
            // Graceful fallback to place list if template construction encounters host constraints
            return buildIdleTemplate()
        }
    }

    private fun buildIdleTemplate(): Template {
        val listBuilder = ItemList.Builder()
        val places = CarBridge.savedPlaces

        // Prominent 1-tap voice search row directly in the car list
        val voiceRow = Row.Builder()
            .setTitle("🎤 بحث صوتي / Voice Navigation")
            .addText("قل: 'اريد الذهاب لمطعم رويال كالاكسي في المنصور'")
            .setOnClickListener {
                screenManager.push(DarbCarSearchScreen(carContext))
            }
            .build()
        listBuilder.addItem(voiceRow)

        if (places.isEmpty()) {
            listBuilder.addItem(
                Row.Builder()
                    .setTitle("درب - جاهز للملاحة")
                    .addText("اختر وجهتك بالصوت أو من الهاتف")
                    .build()
            )
        } else {
            for (place in places.take(5)) {
                val rowBuilder = Row.Builder()
                    .setTitle(place.title)
                    .addText(place.subtitle)
                    .setOnClickListener {
                        CarBridge.notifyDestinationSelected(place.id, place.lat, place.lon)
                    }
                listBuilder.addItem(rowBuilder.build())
            }
        }

        val voiceAction = Action.Builder()
            .setTitle("صوتي / Voice")
            .setOnClickListener {
                screenManager.push(DarbCarSearchScreen(carContext))
            }
            .build()

        val refreshAction = Action.Builder()
            .setTitle("تحديث / Refresh")
            .setOnClickListener {
                invalidate()
            }
            .build()

        val actionStrip = ActionStrip.Builder()
            .addAction(voiceAction)
            .addAction(refreshAction)
            .build()

        return PlaceListMapTemplate.Builder()
            .setTitle("درب - Darb")
            .setItemList(listBuilder.build())
            .setActionStrip(actionStrip)
            .build()
    }
}
