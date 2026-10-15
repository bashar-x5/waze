package app.darb.darb

import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.model.Action
import androidx.car.app.model.ItemList
import androidx.car.app.model.Row
import androidx.car.app.model.SearchTemplate
import androidx.car.app.model.Template
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver

class DarbCarSearchScreen(carContext: CarContext) : Screen(carContext),
    CarBridge.StateListener, CarBridge.SearchListener {

    private var currentQuery: String = ""
    private var isSearching: Boolean = false
    private var statusMessage: String = ""
    private var searchResults: List<CarSearchResult> = emptyList()

    init {
        CarBridge.addStateListener(this)
        CarBridge.searchListener = this

        lifecycle.addObserver(LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_DESTROY) {
                CarBridge.removeStateListener(this)
                if (CarBridge.searchListener === this) {
                    CarBridge.searchListener = null
                }
            }
        })
    }

    override fun onStateChanged(state: CarNavState) {
        if (state.isNavigating) {
            // Navigation has started! Pop back to DarbCarScreen to show NavigationTemplate
            if (screenManager.top == this) {
                screenManager.pop()
            }
        }
    }

    override fun onSavedPlacesChanged(places: List<CarSavedPlace>) {
        invalidate()
    }

    override fun onSearchResultsChanged(results: List<CarSearchResult>) {
        isSearching = false
        searchResults = results
        invalidate()
    }

    override fun onSearchStatusChanged(status: String) {
        isSearching = false
        statusMessage = status
        invalidate()
    }

    override fun onGetTemplate(): Template {
        val listBuilder = ItemList.Builder()

        if (isSearching) {
            listBuilder.addItem(
                Row.Builder()
                    .setTitle("جارٍ البحث الصوتي...")
                    .addText(if (currentQuery.isNotEmpty()) "\"$currentQuery\"" else "جارٍ الاستماع لوجهتك...")
                    .build()
            )
        } else if (searchResults.isNotEmpty()) {
            for (place in searchResults.take(6)) {
                val rowBuilder = Row.Builder()
                    .setTitle(place.title)
                    .addText(
                        if (place.distanceText.isNotEmpty()) {
                            "${place.subtitle} • ${place.distanceText}"
                        } else {
                            place.subtitle
                        }
                    )
                    .setOnClickListener {
                        CarBridge.notifyDestinationSelected(place.id, place.lat, place.lon)
                    }
                listBuilder.addItem(rowBuilder.build())
            }
        } else if (statusMessage.isNotEmpty()) {
            listBuilder.addItem(
                Row.Builder()
                    .setTitle(statusMessage)
                    .addText("اضغط على المايكروفون للتحدث مرة أخرى")
                    .build()
            )
        } else {
            // Default guidance and quick examples
            listBuilder.addItem(
                Row.Builder()
                    .setTitle("🎤 الملاحة الصوتية الذكية (عراقي / فصحى)")
                    .addText("قل: 'اريد الذهاب لساحة الفردوس'")
                    .build()
            )
            listBuilder.addItem(
                Row.Builder()
                    .setTitle("أمثلة لأوامر سريعة:")
                    .addText("وديني لمول بغداد • اخذني للكرادة • اكو سيطرة هنا")
                    .build()
            )

            // Include saved places as convenient quick buttons
            for (place in CarBridge.savedPlaces.take(3)) {
                listBuilder.addItem(
                    Row.Builder()
                        .setTitle(place.title)
                        .addText(place.subtitle)
                        .setOnClickListener {
                            CarBridge.notifyDestinationSelected(place.id, place.lat, place.lon)
                        }
                        .build()
                )
            }
        }

        val searchCallback = object : SearchTemplate.SearchCallback {
            override fun onSearchTextChanged(searchText: String) {
                currentQuery = searchText
                if (searchText.length >= 2) {
                    CarBridge.notifySearchTextChanged(searchText)
                }
            }

            override fun onSearchSubmitted(searchText: String) {
                if (searchText.isNotBlank()) {
                    currentQuery = searchText
                    isSearching = true
                    statusMessage = ""
                    invalidate()
                    CarBridge.notifyVoiceSearchSubmitted(searchText)
                }
            }
        }

        return SearchTemplate.Builder(searchCallback)
            .setHeaderAction(Action.BACK)
            .setSearchHint("تحدث أو ابحث: 'ساحة الفردوس' / Speak")
            .setShowKeyboardByDefault(false)
            .setItemList(listBuilder.build())
            .build()
    }
}
