package com.plushbucket.wear

import android.os.Bundle
import android.text.format.DateUtils
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.wear.compose.foundation.lazy.ScalingLazyColumn
import androidx.wear.compose.foundation.lazy.items
import androidx.wear.compose.foundation.lazy.rememberScalingLazyListState
import androidx.wear.compose.material.Chip
import androidx.wear.compose.material.ChipDefaults
import androidx.wear.compose.material.ListHeader
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.material.PositionIndicator
import androidx.wear.compose.material.Scaffold
import androidx.wear.compose.material.Switch
import androidx.wear.compose.material.Text
import androidx.wear.compose.material.TimeText
import androidx.wear.compose.material.ToggleChip
import androidx.wear.compose.navigation.SwipeDismissableNavHost
import androidx.wear.compose.navigation.composable
import androidx.wear.compose.navigation.rememberSwipeDismissableNavController
import kotlinx.coroutines.delay
import java.util.Locale

// Plushbucket on Wear OS: the same three screens as the Apple Watch app.
// Your bikes (from the phone) → one bike's settings and Start ride → the ride timer, then Save.
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Store.init(this)
        setContent { App() }
    }

    override fun onResume() {
        super.onResume()
        Store.refresh()
    }
}

private val bigFont = FontWeight.Black

@Composable
fun App() {
    MaterialTheme {
        if (Store.rideStart > 0L) {
            RideScreen()
        } else {
            val nav = rememberSwipeDismissableNavController()
            SwipeDismissableNavHost(navController = nav, startDestination = "bikes") {
                composable("bikes") { BikeList { nav.navigate("bike/$it") } }
                composable("bike/{id}") { entry ->
                    val bike = Store.bikes.firstOrNull { it.id == entry.arguments?.getString("id") }
                    if (bike != null) BikeScreen(bike) else BikeList { nav.navigate("bike/$it") }
                }
            }
        }
    }
}

@Composable
private fun Screen(content: @Composable (androidx.wear.compose.foundation.lazy.ScalingLazyListState) -> Unit) {
    val state = rememberScalingLazyListState()
    Scaffold(
        modifier = Modifier.background(Brand.pine),
        timeText = { TimeText() },
        positionIndicator = { PositionIndicator(scalingLazyListState = state) },
    ) {
        content(state)
    }
}

@Composable
private fun Muted(text: String, center: Boolean = false) {
    Text(
        text,
        fontSize = 12.sp,
        color = Brand.muted,
        textAlign = if (center) TextAlign.Center else TextAlign.Start,
        modifier = Modifier.fillMaxWidth(),
    )
}

// MARK: bikes

@Composable
fun BikeList(open: (String) -> Unit) {
    Screen { state ->
        ScalingLazyColumn(state = state, modifier = Modifier.fillMaxSize().background(Brand.pine)) {
            item { ListHeader { Text("Plushbucket", color = Brand.orange, fontWeight = bigFont, fontStyle = FontStyle.Italic) } }
            Store.note?.let { n -> item { Text(n, fontSize = 12.sp, color = Brand.orange, textAlign = TextAlign.Center) } }
            if (Store.bikes.isEmpty()) {
                item {
                    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        Text("No bikes yet", fontWeight = FontWeight.Bold, color = Brand.cream)
                        Muted("Add a bike to your garage in Plushbucket on your phone. Its settings show up here.")
                    }
                }
            }
            items(Store.bikes) { bike ->
                Chip(
                    onClick = { open(bike.id) },
                    label = { Text(bike.name, fontWeight = bigFont, fontStyle = FontStyle.Italic, maxLines = 1) },
                    secondaryLabel = { Text(bike.parts.joinToString(" + ") { it.kindName }) },
                    colors = ChipDefaults.chipColors(backgroundColor = Brand.pineLight, contentColor = Brand.cream, secondaryContentColor = Brand.muted),
                    modifier = Modifier.fillMaxWidth(),
                )
            }
            if (Store.updated > 0L && Store.bikes.isNotEmpty()) {
                item {
                    Muted("From your phone, " + DateUtils.getRelativeTimeSpanString(Store.updated, System.currentTimeMillis(), DateUtils.MINUTE_IN_MILLIS), center = true)
                }
            }
        }
    }
}

@Composable
fun BikeScreen(bike: Bike) {
    Screen { state ->
        ScalingLazyColumn(state = state, modifier = Modifier.fillMaxSize().background(Brand.pine)) {
            item { ListHeader { Text(bike.name, color = Brand.cream, fontWeight = bigFont, fontStyle = FontStyle.Italic, textAlign = TextAlign.Center) } }
            item {
                Chip(
                    onClick = { Store.start(bike) },
                    label = { Text("Start ride", fontWeight = FontWeight.Bold) },
                    colors = ChipDefaults.chipColors(backgroundColor = Brand.orange, contentColor = Color.Black),
                    modifier = Modifier.fillMaxWidth(),
                )
            }
            bike.parts.forEach { part ->
                item { ListHeader { Text(part.kindName, color = Brand.muted) } }
                item {
                    Column(modifier = Modifier.fillMaxWidth()) {
                        Muted(part.l1)
                        Text(part.psi, fontSize = 30.sp, color = Brand.orange, fontWeight = bigFont, fontStyle = FontStyle.Italic)
                        Muted(part.title)
                    }
                }
                item { Stat("Sag target", part.sag) }
                item { Stat(part.l3, part.tok) }
                items(part.lines) { line -> Stat(line.h, line.t) }
            }
            item {
                Muted("${bike.rider} · ${bike.profile} profile. \"Out\" means clicks counterclockwise from fully closed. Starting points only: check sag, and never exceed the maximum pressure printed on your fork or shock.")
            }
        }
    }
}

@Composable
private fun Stat(label: String, value: String) {
    Column(modifier = Modifier.fillMaxWidth().padding(vertical = 2.dp)) {
        Muted(label)
        Text(value, color = Brand.cream, fontSize = 14.sp)
    }
}

// MARK: ride timer

@Composable
fun RideScreen() {
    var stoppedAt by remember { mutableLongStateOf(0L) }
    var wet by remember { mutableStateOf(false) }
    var now by remember { mutableLongStateOf(System.currentTimeMillis()) }
    LaunchedEffect(stoppedAt) {
        while (stoppedAt == 0L) {
            now = System.currentTimeMillis()
            delay(1000)
        }
    }
    Screen { state ->
        ScalingLazyColumn(
            state = state,
            modifier = Modifier.fillMaxSize().background(Brand.pine),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            item { Text(Store.currentBike?.name ?: "Ride", color = Brand.orange, fontWeight = FontWeight.Bold) }
            if (stoppedAt > 0L) {
                val hours = Store.hoursUntil(stoppedAt)
                item { Text(String.format(Locale.US, "%.1f h", hours), fontSize = 40.sp, color = Brand.cream, fontWeight = bigFont, fontStyle = FontStyle.Italic) }
                item {
                    ToggleChip(
                        checked = wet,
                        onCheckedChange = { wet = it },
                        label = { Text("Wet or muddy") },
                        toggleControl = { Switch(checked = wet) },
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
                item {
                    Chip(
                        onClick = { Store.save(hours, wet) },
                        label = { Text("Save ride", fontWeight = FontWeight.Bold, modifier = Modifier.fillMaxWidth(), textAlign = TextAlign.Center) },
                        colors = ChipDefaults.chipColors(backgroundColor = Brand.orange, contentColor = Color.Black),
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
                item {
                    Chip(
                        onClick = { stoppedAt = 0L },
                        label = { Text("Keep riding", modifier = Modifier.fillMaxWidth(), textAlign = TextAlign.Center) },
                        colors = ChipDefaults.secondaryChipColors(),
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
                item {
                    Chip(
                        onClick = { Store.endRide() },
                        label = { Text("Discard", color = Color(0xFFFF6B6B), modifier = Modifier.fillMaxWidth(), textAlign = TextAlign.Center) },
                        colors = ChipDefaults.secondaryChipColors(),
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
            } else {
                item { Text(clock(now - Store.rideStart), fontSize = 40.sp, color = Brand.cream, fontWeight = bigFont, fontStyle = FontStyle.Italic) }
                item { Muted("Stop when you're done and the hours go into the service log on your phone.", center = true) }
                item {
                    Chip(
                        onClick = { stoppedAt = System.currentTimeMillis() },
                        label = { Text("Stop", fontWeight = FontWeight.Bold, modifier = Modifier.fillMaxWidth(), textAlign = TextAlign.Center) },
                        colors = ChipDefaults.chipColors(backgroundColor = Brand.orange, contentColor = Color.Black),
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
            }
        }
    }
}

private fun clock(ms: Long): String {
    val s = (ms / 1000).coerceAtLeast(0)
    return String.format(Locale.US, "%d:%02d:%02d", s / 3600, (s / 60) % 60, s % 60)
}
