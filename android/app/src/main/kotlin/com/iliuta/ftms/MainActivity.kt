package com.iliuta.ftms

import android.os.Build
import android.os.Bundle
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Enable edge-to-edge display for all supported Android versions
        // This approach doesn't use the deprecated setStatusBarColor, setNavigationBarColor,
        // or setNavigationBarDividerColor APIs which are no-ops on Android 15+
        WindowCompat.setDecorFitsSystemWindows(window, false)
        
        super.onCreate(savedInstanceState)
    }
}
