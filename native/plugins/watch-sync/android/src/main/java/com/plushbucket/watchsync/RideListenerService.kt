package com.plushbucket.watchsync

import com.google.android.gms.wearable.DataEvent
import com.google.android.gms.wearable.DataEventBuffer
import com.google.android.gms.wearable.WearableListenerService

// Rides saved on the Wear OS watch, delivered even when the phone app isn't open.
class RideListenerService : WearableListenerService() {
    override fun onDataChanged(events: DataEventBuffer) {
        for (e in events) {
            if (e.type == DataEvent.TYPE_CHANGED) WatchSyncPlugin.keepRide(this, e.dataItem)
        }
    }
}
