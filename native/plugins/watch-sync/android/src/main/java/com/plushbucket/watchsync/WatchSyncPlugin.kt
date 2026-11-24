package com.plushbucket.watchsync

import android.content.Context
import android.net.Uri
import com.getcapacitor.JSArray
import com.getcapacitor.JSObject
import com.getcapacitor.Plugin
import com.getcapacitor.PluginCall
import com.getcapacitor.PluginMethod
import com.getcapacitor.annotation.CapacitorPlugin
import com.google.android.gms.wearable.CapabilityClient
import com.google.android.gms.wearable.DataClient
import com.google.android.gms.wearable.DataItem
import com.google.android.gms.wearable.DataMapItem
import com.google.android.gms.wearable.PutDataMapRequest
import com.google.android.gms.wearable.Wearable
import org.json.JSONArray

// Plushbucket on Wear OS, phone side. The same calls as the iPhone's WatchSync plugin, so the web app
// treats both watches alike.
// The web app sends each garage bike's settings as one JSON string; it goes on the Wearable Data Layer at
// /bikes, and the watch always gets the newest one, even if it was asleep. Rides saved on the watch arrive
// as /ride/<id> data items, are kept here until the web app takes them, and then count toward service like
// a ride logged on the phone. Everything stays between the phone and the watch.
//
// JS:  status() -> { supported, paired, installed }
//      sendBikes({ json }) -> { sent }
//      takeRides() -> { rides: [json string] }
//      event "ride" when a ride arrives while the app is open
@CapacitorPlugin(name = "WatchSync")
class WatchSyncPlugin : Plugin() {

    companion object {
        private const val PREFS = "plushbucket.watch"
        private const val RIDES = "rides"
        @Volatile private var instance: WatchSyncPlugin? = null

        // keep a ride from the watch until the web app takes it, then drop it from the Data Layer
        fun keepRide(ctx: Context, item: DataItem) {
            val path = item.uri.path ?: return
            if (!path.startsWith("/ride/")) return
            val json = DataMapItem.fromDataItem(item).dataMap.getString("ride") ?: return
            synchronized(this) {
                val p = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                val list = JSONArray(p.getString(RIDES, "[]"))
                list.put(json)
                p.edit().putString(RIDES, list.toString()).apply()
            }
            Wearable.getDataClient(ctx).deleteDataItems(item.uri)
            instance?.rideArrived()
        }
    }

    override fun load() {
        instance = this
        // rides that came in before this plugin was listening
        try {
            Wearable.getDataClient(context)
                .getDataItems(Uri.parse("wear://*/ride"), DataClient.FILTER_PREFIX)
                .addOnSuccessListener { buf ->
                    try {
                        for (item in buf) keepRide(context, item)
                    } finally {
                        buf.release()
                    }
                }
        } catch (_: Exception) {
        }
    }

    private fun rideArrived() {
        bridge?.executeOnMainThread { notifyListeners("ride", JSObject()) }
    }

    @PluginMethod
    fun status(call: PluginCall) {
        val out = JSObject().put("supported", false).put("paired", false).put("installed", false)
        try {
            Wearable.getNodeClient(context).connectedNodes
                .addOnSuccessListener { nodes ->
                    Wearable.getCapabilityClient(context)
                        .getCapability("plushbucket_watch", CapabilityClient.FILTER_ALL)
                        .addOnSuccessListener { cap ->
                            call.resolve(
                                JSObject().put("supported", true)
                                    .put("paired", nodes.isNotEmpty() || cap.nodes.isNotEmpty())
                                    .put("installed", cap.nodes.isNotEmpty())
                            )
                        }
                        .addOnFailureListener { call.resolve(JSObject().put("supported", true).put("paired", nodes.isNotEmpty()).put("installed", false)) }
                }
                // no Wear OS support on this phone (the Wear OS app isn't installed): nothing to talk to
                .addOnFailureListener { call.resolve(out) }
        } catch (_: Exception) {
            call.resolve(out)
        }
    }

    @PluginMethod
    fun sendBikes(call: PluginCall) {
        val json = call.getString("json") ?: "[]"
        try {
            val req = PutDataMapRequest.create("/bikes").apply {
                dataMap.putString("bikes", json)
                dataMap.putLong("at", System.currentTimeMillis())
            }.asPutDataRequest().setUrgent()
            Wearable.getDataClient(context).putDataItem(req)
                .addOnSuccessListener { call.resolve(JSObject().put("sent", true)) }
                .addOnFailureListener { e -> call.resolve(JSObject().put("sent", false).put("error", e.message ?: "")) }
        } catch (e: Exception) {
            call.resolve(JSObject().put("sent", false).put("error", e.message ?: ""))
        }
    }

    @PluginMethod
    fun takeRides(call: PluginCall) {
        val rides = JSArray()
        synchronized(Companion) {
            val p = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val list = JSONArray(p.getString(RIDES, "[]"))
            for (i in 0 until list.length()) rides.put(list.getString(i))
            p.edit().remove(RIDES).apply()
        }
        call.resolve(JSObject().put("rides", rides))
    }
}
