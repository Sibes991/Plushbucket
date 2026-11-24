package com.plushbucket.wear

import com.google.android.gms.wearable.DataEvent
import com.google.android.gms.wearable.DataEventBuffer
import com.google.android.gms.wearable.WearableListenerService

// Takes the phone's newest garage even when the watch app isn't open.
class BikesListenerService : WearableListenerService() {
    override fun onDataChanged(events: DataEventBuffer) {
        Store.init(this)
        for (e in events) {
            if (e.type == DataEvent.TYPE_CHANGED) Store.apply(e.dataItem)
        }
    }
}
