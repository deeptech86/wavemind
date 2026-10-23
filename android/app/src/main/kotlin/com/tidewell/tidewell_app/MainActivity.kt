package com.tidewell.tidewell_app

import io.flutter.embedding.android.FlutterFragmentActivity

// The `health` package's Health Connect integration relies on
// registerForActivityResult to drive the permission dialog, which requires a
// FragmentActivity host. On Android 14+ FlutterActivity is not sufficient, so
// MainActivity extends FlutterFragmentActivity as the plugin documents.
class MainActivity : FlutterFragmentActivity()
