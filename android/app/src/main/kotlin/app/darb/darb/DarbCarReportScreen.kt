package app.darb.darb

import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.model.Action
import androidx.car.app.model.ItemList
import androidx.car.app.model.ListTemplate
import androidx.car.app.model.Row
import androidx.car.app.model.Template

class DarbCarReportScreen(carContext: CarContext) : Screen(carContext) {

    override fun onGetTemplate(): Template {
        val state = CarBridge.currentState
        val arabic = state.arabic

        val listBuilder = ItemList.Builder()

        // 1. Police Checkpoint
        listBuilder.addItem(
            Row.Builder()
                .setTitle(if (arabic) "👮 سيطرة مرورية أو دورية" else "👮 Police / Checkpoint")
                .addText(if (arabic) "إبلاغ السائقين بوجود نقطة تفتيش أو مفرزة" else "Report police checkpoint or patrol")
                .setOnClickListener {
                    CarBridge.notifyReportIncident("police")
                    screenManager.pop()
                }
                .build()
        )

        // 2. Heavy Traffic
        listBuilder.addItem(
            Row.Builder()
                .setTitle(if (arabic) "🚗 ازدحام مروري خانق" else "🚗 Heavy Traffic Jam")
                .addText(if (arabic) "تباطؤ أو توقف تام في حركة السير" else "Standstill or heavy slowdown ahead")
                .setOnClickListener {
                    CarBridge.notifyReportIncident("traffic")
                    screenManager.pop()
                }
                .build()
        )

        // 3. Traffic Crash
        listBuilder.addItem(
            Row.Builder()
                .setTitle(if (arabic) "💥 حادث سير" else "💥 Traffic Accident")
                .addText(if (arabic) "حادث اصطدام يعيق مسار الطريق" else "Car crash blocking lane")
                .setOnClickListener {
                    CarBridge.notifyReportIncident("crash")
                    screenManager.pop()
                }
                .build()
        )

        // 4. Road Hazard
        listBuilder.addItem(
            Row.Builder()
                .setTitle(if (arabic) "⚠️ خطر أو عائق على الطريق" else "⚠️ Road Hazard / Obstacle")
                .addText(if (arabic) "حفرة أو عائق مفاجئ أمام المركبات" else "Pothole, debris or road hazard")
                .setOnClickListener {
                    CarBridge.notifyReportIncident("hazard")
                    screenManager.pop()
                }
                .build()
        )

        // 5. Road Closure / Construction
        listBuilder.addItem(
            Row.Builder()
                .setTitle(if (arabic) "🚧 قطع شارع أو أعمال صيانة" else "🚧 Road Closure / Works")
                .addText(if (arabic) "تحويلة إجبارية أو إغلاق مؤقت" else "Detour or road closed ahead")
                .setOnClickListener {
                    CarBridge.notifyReportIncident("closure")
                    screenManager.pop()
                }
                .build()
        )

        // 6. Speed Camera / Radar
        listBuilder.addItem(
            Row.Builder()
                .setTitle(if (arabic) "📷 كاميرا رادار سرعة" else "📷 Speed Camera")
                .addText(if (arabic) "رادار سرعة ثابت أو متحرك" else "Speed radar or camera trap")
                .setOnClickListener {
                    CarBridge.notifyReportIncident("camera")
                    screenManager.pop()
                }
                .build()
        )

        // 7. Speed Bump
        listBuilder.addItem(
            Row.Builder()
                .setTitle(if (arabic) "🛑 مطب اصطناعي غير معلّم" else "🛑 Speed Bump")
                .addText(if (arabic) "مطب مرتفع يحتاج إلى تهدئة السرعة" else "Unmarked speed bump ahead")
                .setOnClickListener {
                    CarBridge.notifyReportIncident("bump")
                    screenManager.pop()
                }
                .build()
        )

        return ListTemplate.Builder()
            .setHeaderAction(Action.BACK)
            .setTitle(if (arabic) "📢 إبلاغ عن أحوال الطريق" else "📢 Report Road Incident")
            .setSingleList(listBuilder.build())
            .build()
    }
}
