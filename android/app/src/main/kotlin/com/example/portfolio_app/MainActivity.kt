package com.example.portfolio_app

import android.content.Context
import android.os.Bundle
import com.google.firebase.FirebaseApp
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity() {

    companion object {
        /** Must match Firebase Console → App Check → Debug tokens for this Android app. */
        private const val APP_CHECK_DEBUG_SECRET = "aabb1234-ccdd-4ef5-8901-23456789abcd"
        private const val DEBUG_SECRET_KEY = "com.google.firebase.appcheck.debug.DEBUG_SECRET"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        // SDK-compatible prefs for DebugAppCheckProviderFactory (see Firebase Android SDK).
        // Old key `firebase_app_check_debug_token` is ignored by the SDK.
        val persistenceKey =
            try {
                FirebaseApp.getInstance().persistenceKey
            } catch (_: IllegalStateException) {
                "[DEFAULT]"
            }
        getSharedPreferences(
            "com.google.firebase.appcheck.debug.store.$persistenceKey",
            Context.MODE_PRIVATE
        ).edit()
            .putString(DEBUG_SECRET_KEY, APP_CHECK_DEBUG_SECRET)
            .apply()
        super.onCreate(savedInstanceState)
    }
}
