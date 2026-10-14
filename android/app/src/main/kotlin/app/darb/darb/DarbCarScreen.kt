package app.darb.darb

import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.model.Action
import androidx.car.app.model.ActionStrip
import androidx.car.app.model.CarColor
import androidx.car.app.model.CarIcon
import androidx.car.app.model.Distance
import androidx.car.app.model.ItemList
import androidx.car.app.model.PlaceListMapTemplate
import androidx.car.app.model.Row
import androidx.car.app.model.Template
import androidx.car.app.navigation.model.Maneuver
import androidx.car.app.navigation.model.NavigationTemplate
import androidx.car.app.navigation.model.RoutingInfo
import androidx.car.app.navigation.model.Step

class DarbCarScreen(carContext: CarContext) : Screen(carContext), CarBridge.StateListener {

    init {
        CarBridge.stateListener = this
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
            val stopAction = Action.Builder()
                .setTitle("إنهاء / Stop")
                .setOnClickListener {
                    CarBridge.notifyStopNavigation()
                }
                .build()

            val actionStrip = ActionStrip.Builder()
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

            // Safe fallback distance display (100 meters standard scale)
            val distance = Distance.create(0.1, Distance.UNIT_KILOMETERS)

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

        if (places.isEmpty()) {
            listBuilder.addItem(
                Row.Builder()
                    .setTitle("درب - جاهز للملاحة")
                    .addText("اختر وجهتك من الهاتف أو المحفوظات")
                    .build()
            )
        } else {
            for (place in places.take(6)) {
                val rowBuilder = Row.Builder()
                    .setTitle(place.title)
                    .addText(place.subtitle)
                    .setOnClickListener {
                        CarBridge.notifyDestinationSelected(place.id, place.lat, place.lon)
                    }
                listBuilder.addItem(rowBuilder.build())
            }
        }

        val refreshAction = Action.Builder()
            .setTitle("تحديث / Refresh")
            .setOnClickListener {
                invalidate()
            }
            .build()

        val actionStrip = ActionStrip.Builder()
            .addAction(refreshAction)
            .build()

        return PlaceListMapTemplate.Builder()
            .setTitle("درب - Darb")
            .setItemList(listBuilder.build())
            .setActionStrip(actionStrip)
            .build()
    }
}
