package app.darb.darb

import androidx.car.app.CarAppService
import androidx.car.app.Session
import androidx.car.app.validation.HostValidator

class DarbCarAppService : CarAppService() {
    override fun createHostValidator(): HostValidator {
        // Allows connection from Android Auto head units, wireless dongles, and the Desktop Head Unit (DHU)
        return HostValidator.ALLOW_ALL_HOSTS_VALIDATOR
    }

    override fun onCreateSession(): Session {
        return DarbCarSession()
    }
}
