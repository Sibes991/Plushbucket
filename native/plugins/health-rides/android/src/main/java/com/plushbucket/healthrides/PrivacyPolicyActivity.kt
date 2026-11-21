package com.plushbucket.healthrides

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Bundle

// Health Connect opens this when the rider asks how Plushbucket uses their data. It shows the privacy policy.
class PrivacyPolicyActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        try {
            startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://plushbucket.com/privacy")))
        } catch (_: Exception) {
        }
        finish()
    }
}
