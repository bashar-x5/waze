package app.darb.darb

import android.content.Intent
import androidx.car.app.Screen
import androidx.car.app.Session

class DarbCarSession : Session() {
    override fun onCreateScreen(intent: Intent): Screen {
        return DarbCarScreen(carContext)
    }
}
