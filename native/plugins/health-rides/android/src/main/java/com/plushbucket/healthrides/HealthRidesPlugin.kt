package com.plushbucket.healthrides

import android.content.Intent
import android.net.Uri
import androidx.activity.result.ActivityResult
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import com.getcapacitor.JSArray
import com.getcapacitor.JSObject
import com.getcapacitor.Plugin
import com.getcapacitor.PluginCall
import com.getcapacitor.PluginMethod
import com.getcapacitor.annotation.ActivityCallback
import com.getcapacitor.annotation.CapacitorPlugin
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import java.time.Instant

// Ride import, Android side.
// Reads bike rides that other apps (Garmin Connect, Strava, Trailforks...) saved to Health Connect, so the
// web app can count their hours toward fork and shock service. Read-only, and nothing leaves the phone.
//
// JS:  status() -> { available, platform, asked, granted, needsInstall }
//      request() -> { asked, granted }
//      rides({ from }) -> { rides: [{ id, start, end, duration, source, bundle, indoor }] }   (ms, seconds)
//      openSettings() -> opens Health Connect (or the Play Store when it needs installing or updating)
@CapacitorPlugin(name = "HealthRides")
class HealthRidesPlugin : Plugin() {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private val provider = "com.google.android.apps.healthdata"
    private val perms = setOf(HealthPermission.getReadPermission(ExerciseSessionRecord::class))

    // Health Connect reports which app wrote each ride by package name; these are the usual ones
    private val names = mapOf(
        "com.garmin.android.apps.connectmobile" to "Garmin Connect",
        "com.strava" to "Strava",
        "com.pinkbike.trailforks" to "Trailforks",
        "com.sec.android.app.shealth" to "Samsung Health",
        "com.google.android.apps.fitness" to "Google Fit",
        "com.fitbit.FitbitMobile" to "Fitbit"
    )

    private fun sdk(): Int = HealthConnectClient.getSdkStatus(context, provider)

    private suspend fun granted(): Boolean = try {
        HealthConnectClient.getOrCreate(context).permissionController.getGrantedPermissions().containsAll(perms)
    } catch (_: Exception) {
        false
    }

    @PluginMethod
    fun status(call: PluginCall) {
        val st = sdk()
        if (st != HealthConnectClient.SDK_AVAILABLE) {
            call.resolve(
                JSObject().put("available", false).put("platform", "android").put("asked", false).put("granted", false)
                    .put("needsInstall", st == HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED)
            )
            return
        }
        scope.launch {
            val ok = granted()
            call.resolve(JSObject().put("available", true).put("platform", "android").put("asked", ok).put("granted", ok).put("needsInstall", false))
        }
    }

    @PluginMethod
    fun request(call: PluginCall) {
        if (sdk() != HealthConnectClient.SDK_AVAILABLE) {
            call.resolve(JSObject().put("asked", false).put("granted", false))
            return
        }
        val intent = PermissionController.createRequestPermissionResultContract().createIntent(context, perms)
        startActivityForResult(call, intent, "permissionResult")
    }

    @ActivityCallback
    private fun permissionResult(call: PluginCall?, result: ActivityResult) {
        if (call == null) return
        scope.launch {
            val ok = granted()
            call.resolve(JSObject().put("asked", true).put("granted", ok))
            bridge.releaseCall(call)
        }
    }

    @PluginMethod
    fun rides(call: PluginCall) {
        if (sdk() != HealthConnectClient.SDK_AVAILABLE) {
            call.resolve(JSObject().put("rides", JSArray()))
            return
        }
        // a ms timestamp arrives as a Long, which PluginCall.getDouble doesn't read, so take any number
        val from = (call.data.opt("from") as? Number)?.toLong() ?: (System.currentTimeMillis() - 30L * 86_400_000L)
        scope.launch {
            val out = JSArray()
            try {
                val client = HealthConnectClient.getOrCreate(context)
                var token: String? = null
                var pages = 0
                do {
                    val res = client.readRecords(
                        ReadRecordsRequest(
                            ExerciseSessionRecord::class,
                            TimeRangeFilter.after(Instant.ofEpochMilli(from)),
                            ascendingOrder = false,
                            pageSize = 500,
                            pageToken = token
                        )
                    )
                    for (r in res.records) {
                        val bike = r.exerciseType == ExerciseSessionRecord.EXERCISE_TYPE_BIKING
                        val trainer = r.exerciseType == ExerciseSessionRecord.EXERCISE_TYPE_BIKING_STATIONARY
                        if (!bike && !trainer) continue
                        val pkg = r.metadata.dataOrigin.packageName
                        val s = r.startTime.toEpochMilli()
                        val e = r.endTime.toEpochMilli()
                        out.put(
                            JSObject().put("id", r.metadata.id).put("start", s).put("end", e)
                                .put("duration", (e - s) / 1000.0).put("source", appName(pkg))
                                .put("bundle", pkg).put("indoor", trainer)
                        )
                    }
                    token = res.pageToken
                    pages++
                } while (!token.isNullOrEmpty() && pages < 5)
                call.resolve(JSObject().put("rides", out))
            } catch (e: SecurityException) {
                call.resolve(JSObject().put("rides", out).put("error", "permission"))
            } catch (e: Exception) {
                call.resolve(JSObject().put("rides", out).put("error", e.message ?: "error"))
            }
        }
    }

    @PluginMethod
    fun openSettings(call: PluginCall) {
        val intent = if (sdk() == HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED) {
            Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=$provider&url=healthconnect%3A%2F%2Fonboarding"))
                .setPackage("com.android.vending")
        } else {
            Intent(HealthConnectClient.ACTION_HEALTH_CONNECT_SETTINGS)
        }
        try {
            activity.startActivity(intent)
            call.resolve(JSObject().put("opened", true))
        } catch (_: Exception) {
            call.resolve(JSObject().put("opened", false))
        }
    }

    private fun appName(pkg: String): String {
        names[pkg]?.let { return it }
        return try {
            val pm = context.packageManager
            pm.getApplicationLabel(pm.getApplicationInfo(pkg, 0)).toString()
        } catch (_: Exception) {
            pkg
        }
    }

    override fun handleOnDestroy() {
        scope.cancel()
        super.handleOnDestroy()
    }
}
