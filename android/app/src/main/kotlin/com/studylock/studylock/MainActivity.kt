package com.studylock.studylock

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        GuardEngine.init(this)
        MonitorHost.install(this, flutterEngine)
    }

    override fun onResume() {
        super.onResume()
        GuardEngine.init(this)
        GuardEngine.foreground(packageName)
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) {
            GuardEngine.init(this)
            GuardEngine.foreground(packageName)
        }
    }
}
