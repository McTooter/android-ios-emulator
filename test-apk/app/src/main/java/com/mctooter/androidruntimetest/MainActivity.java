package com.mctooter.androidruntimetest;

import android.app.Activity;
import android.os.Bundle;
import android.view.Gravity;
import android.widget.TextView;

public final class MainActivity extends Activity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        TextView view = new TextView(this);
        view.setText("AndroidRuntime test APK\nPackage installation and launch succeeded.");
        view.setTextSize(22.0f);
        view.setGravity(Gravity.CENTER);
        view.setContentDescription("AndroidRuntime test APK launch marker");
        setContentView(view);
    }
}
