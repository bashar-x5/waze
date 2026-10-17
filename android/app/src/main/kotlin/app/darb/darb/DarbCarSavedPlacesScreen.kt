package app.darb.darb

import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.model.Action
import androidx.car.app.model.ItemList
import androidx.car.app.model.ListTemplate
import androidx.car.app.model.Row
import androidx.car.app.model.Template
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver

class DarbCarSavedPlacesScreen(carContext: CarContext) : Screen(carContext), CarBridge.StateListener {

    init {
        CarBridge.addStateListener(this)
        lifecycle.addObserver(LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_DESTROY) {
                CarBridge.removeStateListener(this)
            }
        })
    }

    override fun onStateChanged(state: CarNavState) {
        if (state.isNavigating) {
            if (screenManager.top == this) {
                screenManager.pop()
            }
        }
    }

    override fun onSavedPlacesChanged(places: List<CarSavedPlace>) {
        invalidate()
    }

    override fun onGetTemplate(): Template {
        val listBuilder = ItemList.Builder()
        val places = CarBridge.savedPlaces

        if (places.isEmpty()) {
            listBuilder.addItem(
                Row.Builder()
                    .setTitle("لا توجد أماكن مفضلة / No saved places")
                    .addText("أضف أماكنك المفضلة من الهاتف لتظهر على شاشة السيارة")
                    .build()
            )
        } else {
            for (place in places.take(6)) {
                val row = Row.Builder()
                    .setTitle(place.title)
                    .addText(place.subtitle.ifBlank { "انقر للملاحة المباشرة" })
                    .setOnClickListener {
                        CarBridge.notifyDestinationSelected(place.id, place.lat, place.lon)
                        if (screenManager.top == this) {
                            screenManager.pop()
                        }
                    }
                    .build()
                listBuilder.addItem(row)
            }
        }

        return ListTemplate.Builder()
            .setHeaderAction(Action.BACK)
            .setTitle("الأماكن المفضلة / Saved Places")
            .setSingleList(listBuilder.build())
            .build()
    }
}
