package com.tripjournal.tripjournal

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity (not FlutterActivity) is required by the `health`
// plugin on Android 14+: Health Connect permission requests use
// registerForActivityResult, which needs a ComponentActivity to attach to.
class MainActivity : FlutterFragmentActivity()
