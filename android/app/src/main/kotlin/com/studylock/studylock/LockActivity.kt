package com.studylock.studylock

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class LockActivity : FlutterActivity() {
    companion object { var visible = false; private set }
    override fun getInitialRoute() = "/intercept"
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine); MonitorHost.install(this, flutterEngine)
    }
    override fun onCreate(savedInstanceState: Bundle?) { super.onCreate(savedInstanceState); GuardEngine.init(this) }
    override fun onResume() {
        super.onResume()
        visible = true
        GuardEngine.foreground(packageName)
        if (!GuardEngine.locked) finish()
    }
    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) GuardEngine.foreground(packageName)
    }
    override fun onPause() { visible = false; super.onPause() }
    override fun onDestroy() { visible = false; super.onDestroy() }
}
