package com.plushbucket.wear

import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.os.Handler
import android.os.Looper
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.google.android.gms.wearable.DataClient
import com.google.android.gms.wearable.DataItem
import com.google.android.gms.wearable.DataMapItem
import com.google.android.gms.wearable.PutDataMapRequest
import com.google.android.gms.wearable.Wearable
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.UUID
import kotlin.math.max
import kotlin.math.roundToInt

// Keeps the bikes the phone sent, the ride timer, and hands finished rides to the phone.
// The timer is just a saved start time, so it keeps counting when the screen sleeps or the app closes.
// Talks to the phone over Google's Wearable Data Layer: the phone puts its garage at /bikes, and each
// saved ride goes out as /ride/<id>. Data items wait and sync on their own when the phone is out of range.
object Store {
    private lateinit var app: Context
    private lateinit var prefs: SharedPreferences
    private val main = Handler(Looper.getMainLooper())

    var bikes by mutableStateOf<List<Bike>>(emptyList())
    var updated by mutableLongStateOf(0L)
    var rideStart by mutableLongStateOf(0L)
    var rideBike by mutableStateOf<String?>(null)
    var note by mutableStateOf<String?>(null)

    val currentBike: Bike? get() = bikes.firstOrNull { it.id == rideBike }

    fun init(ctx: Context) {
        if (::prefs.isInitialized) return
        app = ctx.applicationContext
        prefs = app.getSharedPreferences("plushbucket", Context.MODE_PRIVATE)
        prefs.getString("bikes", null)?.let { bikes = Bike.parseList(it) }
        updated = prefs.getLong("updated", 0L)
        rideStart = prefs.getLong("rideStart", 0L)
        rideBike = prefs.getString("rideBike", null)
        refresh()
    }

    // the newest garage the phone put on the Data Layer (it may have arrived while the app was closed)
    fun refresh() {
        Wearable.getDataClient(app).getDataItems(Uri.parse("wear://*/bikes"), DataClient.FILTER_LITERAL)
            .addOnSuccessListener { buf ->
                try {
                    for (item in buf) apply(item)
                } finally {
                    buf.release()
                }
            }
    }

    fun apply(item: DataItem) {
        if (item.uri.path != "/bikes") return
        val m = DataMapItem.fromDataItem(item).dataMap
        val json = m.getString("bikes") ?: return
        val at = m.getLong("at", System.currentTimeMillis())
        if (at < updated) return
        prefs.edit().putString("bikes", json).putLong("updated", at).apply()
        val list = Bike.parseList(json)
        main.post {
            bikes = list
            updated = at
        }
    }

    // MARK: ride timer

    fun start(bike: Bike) {
        val now = System.currentTimeMillis()
        rideStart = now
        rideBike = bike.id
        note = null
        prefs.edit().putLong("rideStart", now).putString("rideBike", bike.id).apply()
    }

    fun endRide() {
        rideStart = 0L
        rideBike = null
        prefs.edit().remove("rideStart").remove("rideBike").apply()
    }

    // hours to one decimal, never less than 0.1, as on the Apple Watch
    fun hoursUntil(end: Long): Double = max(0.1, ((end - rideStart) / 360_000.0).roundToInt() / 10.0)

    fun save(hours: Double, wet: Boolean) {
        val bike = currentBike ?: run { endRide(); return }
        val id = "w" + UUID.randomUUID().toString().replace("-", "").take(8)
        val date = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date(if (rideStart > 0) rideStart else System.currentTimeMillis()))
        val ride = JSONObject()
            .put("id", id)
            .put("date", date)
            .put("h", (hours * 100).roundToInt() / 100.0)
            .put("wet", wet)
            .put("bike", bike.id)
            .put("parts", JSONArray(bike.parts.map { it.id }))
        val req = PutDataMapRequest.create("/ride/$id").apply {
            dataMap.putString("ride", ride.toString())
            dataMap.putLong("at", System.currentTimeMillis())
        }.asPutDataRequest().setUrgent()
        Wearable.getDataClient(app).putDataItem(req)
        note = String.format(Locale.US, "%.1f h added to %s. It shows in the service log on your phone.", hours, bike.name)
        endRide()
    }
}
