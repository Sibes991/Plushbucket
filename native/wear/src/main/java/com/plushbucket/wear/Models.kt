package com.plushbucket.wear

import androidx.compose.ui.graphics.Color
import org.json.JSONArray

// What the phone app sends: every value is already worked out and worded on the phone, so the watch
// shows exactly what the setup card on the phone shows. Same shape as the Apple Watch app's Models.swift.
data class Line(val h: String, val t: String)

data class Part(
    val id: String,
    val kind: String,       // "fork" or "shock"
    val title: String,
    val l1: String,         // "Starting pressure", "Bike park pressure", "Spring rate"...
    val psi: String,
    val sag: String,
    val l3: String,         // "Volume spacers", "Tokens", "Max pressure"...
    val tok: String,
    val lines: List<Line>,
) {
    val kindName: String get() = if (kind == "fork") "Fork" else "Shock"
}

data class Bike(
    val id: String,
    val name: String,
    val rider: String,
    val profile: String,
    val parts: List<Part>,
) {
    companion object {
        fun parseList(json: String): List<Bike> = try {
            val a = JSONArray(json)
            (0 until a.length()).map { i ->
                val b = a.getJSONObject(i)
                val ps = b.optJSONArray("parts") ?: JSONArray()
                Bike(
                    id = b.optString("id"),
                    name = b.optString("name"),
                    rider = b.optString("rider"),
                    profile = b.optString("profile"),
                    parts = (0 until ps.length()).map { j ->
                        val p = ps.getJSONObject(j)
                        val ls = p.optJSONArray("lines") ?: JSONArray()
                        Part(
                            id = p.optString("id"),
                            kind = p.optString("kind"),
                            title = p.optString("title"),
                            l1 = p.optString("l1"),
                            psi = p.optString("psi"),
                            sag = p.optString("sag"),
                            l3 = p.optString("l3"),
                            tok = p.optString("tok"),
                            lines = (0 until ls.length()).map { k ->
                                val l = ls.getJSONObject(k)
                                Line(l.optString("h"), l.optString("t"))
                            },
                        )
                    },
                )
            }
        } catch (e: Exception) {
            emptyList()
        }
    }
}

object Brand {
    val orange = Color(0xFFFF7A2E)
    val pine = Color(0xFF1A3328)
    val pineLight = Color(0xFF24463A)
    val cream = Color(0xFFF6EFE4)
    val muted = Color(0xFFB9C7BF)
}
