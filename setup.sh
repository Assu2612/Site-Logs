#!/bin/bash
# SiteTrack: creates the Android project around index.html
set -e
test -f index.html || { echo "index.html not found in the repo root - upload it first"; exit 1; }
mkdir -p "$(dirname 'settings.gradle')"
cat > 'settings.gradle' <<'EOF_ST'
pluginManagement {
    repositories { google(); mavenCentral(); gradlePluginPortal() }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories { google(); mavenCentral() }
}
rootProject.name = "SiteTrack"
include ':app'
EOF_ST
mkdir -p "$(dirname 'build.gradle')"
cat > 'build.gradle' <<'EOF_ST'
plugins {
    id 'com.android.application' version '8.7.3' apply false
}
EOF_ST
mkdir -p "$(dirname 'gradle.properties')"
cat > 'gradle.properties' <<'EOF_ST'
org.gradle.jvmargs=-Xmx2048m -Dfile.encoding=UTF-8
android.useAndroidX=true
android.nonTransitiveRClass=true
EOF_ST
mkdir -p "$(dirname 'app/build.gradle')"
cat > 'app/build.gradle' <<'EOF_ST'
plugins {
    id 'com.android.application'
}

android {
    namespace 'com.sitetrack.app'
    compileSdk 35

    defaultConfig {
        applicationId "com.sitetrack.app"
        minSdk 24
        targetSdk 35
        versionCode 1
        versionName "1.0"
    }

    buildTypes {
        release {
            minifyEnabled false
        }
    }
    compileOptions {
        sourceCompatibility JavaVersion.VERSION_17
        targetCompatibility JavaVersion.VERSION_17
    }
}

dependencies {
    implementation 'androidx.webkit:webkit:1.12.1'
    implementation 'androidx.core:core:1.13.1'
}
EOF_ST
mkdir -p "$(dirname 'app/src/main/AndroidManifest.xml')"
cat > 'app/src/main/AndroidManifest.xml' <<'EOF_ST'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <application
        android:allowBackup="true"
        android:icon="@mipmap/ic_launcher"
        android:label="@string/app_name"
        android:supportsRtl="true"
        android:theme="@style/AppTheme">

        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:configChanges="orientation|screenSize|keyboardHidden|screenLayout|uiMode"
            android:windowSoftInputMode="adjustResize"
            android:screenOrientation="portrait">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>

        <provider
            android:name="androidx.core.content.FileProvider"
            android:authorities="${applicationId}.files"
            android:exported="false"
            android:grantUriPermissions="true">
            <meta-data
                android:name="android.support.FILE_PROVIDER_PATHS"
                android:resource="@xml/file_paths" />
        </provider>
    </application>

    <queries>
        <intent><action android:name="android.media.action.IMAGE_CAPTURE" /></intent>
        <intent><action android:name="android.intent.action.SEND" /><data android:mimeType="*/*" /></intent>
        <intent><action android:name="android.intent.action.VIEW" /><data android:mimeType="application/pdf" /></intent>
    </queries>
</manifest>
EOF_ST
mkdir -p "$(dirname 'app/src/main/res/xml/file_paths.xml')"
cat > 'app/src/main/res/xml/file_paths.xml' <<'EOF_ST'
<?xml version="1.0" encoding="utf-8"?>
<paths>
    <cache-path name="images" path="images/" />
    <cache-path name="share" path="share/" />
    <external-files-path name="downloads" path="Download/" />
</paths>
EOF_ST
mkdir -p "$(dirname 'app/src/main/res/values/strings.xml')"
cat > 'app/src/main/res/values/strings.xml' <<'EOF_ST'
<resources>
    <string name="app_name">SiteTrack</string>
</resources>
EOF_ST
mkdir -p "$(dirname 'app/src/main/res/values/themes.xml')"
cat > 'app/src/main/res/values/themes.xml' <<'EOF_ST'
<resources>
    <style name="AppTheme" parent="@android:style/Theme.Material.Light.NoActionBar">
        <item name="android:statusBarColor">#1B1E22</item>
        <item name="android:navigationBarColor">#FFFFFF</item>
        <item name="android:windowBackground">@color/bg</item>
        <item name="android:colorPrimary">#1B1E22</item>
        <item name="android:colorAccent">#F2B705</item>
    </style>
    <color name="bg">#F3F1EC</color>
</resources>
EOF_ST
mkdir -p "$(dirname 'app/src/main/java/com/sitetrack/app/MainActivity.java')"
cat > 'app/src/main/java/com/sitetrack/app/MainActivity.java' <<'EOF_ST'
package com.sitetrack.app;

import android.app.Activity;
import android.content.ActivityNotFoundException;
import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.ContentResolver;
import android.content.ContentValues;
import android.content.Context;
import android.content.Intent;
import android.graphics.Insets;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.Environment;
import android.provider.MediaStore;
import android.util.Base64;
import android.view.View;
import android.view.WindowInsets;
import android.webkit.JavascriptInterface;
import android.webkit.ValueCallback;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceResponse;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.Toast;

import androidx.core.content.FileProvider;
import androidx.webkit.WebViewAssetLoader;

import java.io.File;
import java.io.FileOutputStream;
import java.io.OutputStream;
import java.util.ArrayList;
import java.util.List;

public class MainActivity extends Activity {

    private static final String HOST = "appassets.androidplatform.net";
    private static final String START_URL = "https://" + HOST + "/assets/index.html";
    private static final int REQ_FILE = 101;

    private WebView web;
    private ValueCallback<Uri[]> fileCallback;
    private Uri cameraUri;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        web = new WebView(this);
        web.setBackgroundColor(0xFFF3F1EC);
        setContentView(web);

        // Android 15+ draws edge-to-edge: keep content clear of the status bar, nav bar and keyboard
        if (Build.VERSION.SDK_INT >= 35) {
            web.setOnApplyWindowInsetsListener((View v, WindowInsets insets) -> {
                Insets bars = insets.getInsets(WindowInsets.Type.systemBars());
                Insets ime = insets.getInsets(WindowInsets.Type.ime());
                v.setPadding(bars.left, bars.top, bars.right, Math.max(bars.bottom, ime.bottom));
                return insets;
            });
        }

        final WebViewAssetLoader loader = new WebViewAssetLoader.Builder()
                .setDomain(HOST)
                .addPathHandler("/assets/", new WebViewAssetLoader.AssetsPathHandler(this))
                .build();

        WebSettings s = web.getSettings();
        s.setJavaScriptEnabled(true);
        s.setDomStorageEnabled(true);
        s.setDatabaseEnabled(true);
        s.setAllowFileAccess(false);
        s.setAllowContentAccess(true);
        s.setMediaPlaybackRequiresUserGesture(true);
        s.setTextZoom(100);

        web.addJavascriptInterface(new Bridge(), "AndroidBridge");

        web.setWebViewClient(new WebViewClient() {
            @Override
            public WebResourceResponse shouldInterceptRequest(WebView view, WebResourceRequest request) {
                return loader.shouldInterceptRequest(request.getUrl());
            }

            @Override
            public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
                Uri u = request.getUrl();
                if (HOST.equals(u.getHost())) return false;
                try {
                    startActivity(new Intent(Intent.ACTION_VIEW, u));
                } catch (ActivityNotFoundException ignored) { }
                return true;
            }
        });

        web.setWebChromeClient(new WebChromeClient() {
            @Override
            public boolean onShowFileChooser(WebView view, ValueCallback<Uri[]> callback, FileChooserParams params) {
                if (fileCallback != null) fileCallback.onReceiveValue(null);
                fileCallback = callback;
                cameraUri = null;

                String[] accept = params.getAcceptTypes();
                boolean images = false;
                StringBuilder joined = new StringBuilder();
                if (accept != null) for (String a : accept) { joined.append(a); if (a != null && a.contains("image")) images = true; }
                if (joined.length() == 0) images = true;

                Intent pick = new Intent(Intent.ACTION_GET_CONTENT);
                pick.addCategory(Intent.CATEGORY_OPENABLE);
                pick.setType(images ? "image/*" : "*/*");
                if (params.getMode() == FileChooserParams.MODE_OPEN_MULTIPLE) pick.putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true);

                Intent camera = null;
                if (images) {
                    try {
                        File dir = new File(getCacheDir(), "images");
                        //noinspection ResultOfMethodCallIgnored
                        dir.mkdirs();
                        File photo = new File(dir, "site_" + System.currentTimeMillis() + ".jpg");
                        cameraUri = FileProvider.getUriForFile(MainActivity.this, getPackageName() + ".files", photo);
                        camera = new Intent(MediaStore.ACTION_IMAGE_CAPTURE);
                        camera.putExtra(MediaStore.EXTRA_OUTPUT, cameraUri);
                        camera.addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION | Intent.FLAG_GRANT_READ_URI_PERMISSION);
                    } catch (Exception e) {
                        camera = null;
                        cameraUri = null;
                    }
                }

                Intent launch;
                if (params.isCaptureEnabled() && camera != null) {
                    launch = camera;
                } else {
                    launch = Intent.createChooser(pick, images ? "Add photo" : "Choose file");
                    if (camera != null) launch.putExtra(Intent.EXTRA_INITIAL_INTENTS, new Intent[]{camera});
                }
                try {
                    startActivityForResult(launch, REQ_FILE);
                } catch (ActivityNotFoundException e) {
                    fileCallback = null;
                    Toast.makeText(MainActivity.this, "No app found to pick a file", Toast.LENGTH_SHORT).show();
                    return false;
                }
                return true;
            }
        });

        if (savedInstanceState != null) web.restoreState(savedInstanceState);
        else web.loadUrl(START_URL);
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode != REQ_FILE || fileCallback == null) return;
        Uri[] result = null;
        if (resultCode == RESULT_OK) {
            List<Uri> list = new ArrayList<>();
            if (data != null && data.getClipData() != null) {
                ClipData cd = data.getClipData();
                for (int i = 0; i < cd.getItemCount(); i++) list.add(cd.getItemAt(i).getUri());
            } else if (data != null && data.getData() != null) {
                list.add(data.getData());
            } else if (cameraUri != null) {
                list.add(cameraUri);
            }
            if (!list.isEmpty()) result = list.toArray(new Uri[0]);
        }
        fileCallback.onReceiveValue(result);
        fileCallback = null;
    }

    @Override
    public void onBackPressed() {
        web.evaluateJavascript("(window.__back&&window.__back())?'1':'0'", value -> {
            if (value != null && value.contains("1")) return;
            MainActivity.super.onBackPressed();
        });
    }

    @Override
    protected void onSaveInstanceState(Bundle outState) {
        super.onSaveInstanceState(outState);
        web.saveState(outState);
    }

    /* ------------ bridge used by the web app ------------ */
    private class Bridge {

        /** Saves a file into Downloads/SiteTrack. Returns the content uri, or "" on failure. */
        @JavascriptInterface
        public String saveFile(String name, String base64, String mime) {
            try {
                byte[] bytes = Base64.decode(base64, Base64.DEFAULT);
                Uri uri;
                if (Build.VERSION.SDK_INT >= 29) {
                    ContentResolver cr = getContentResolver();
                    ContentValues v = new ContentValues();
                    v.put(MediaStore.MediaColumns.DISPLAY_NAME, name);
                    v.put(MediaStore.MediaColumns.MIME_TYPE, mime);
                    v.put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + "/SiteTrack");
                    uri = cr.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, v);
                    if (uri == null) return "";
                    try (OutputStream os = cr.openOutputStream(uri)) {
                        if (os == null) return "";
                        os.write(bytes);
                    }
                } else {
                    File dir = new File(getExternalFilesDir(null), "Download");
                    //noinspection ResultOfMethodCallIgnored
                    dir.mkdirs();
                    File f = new File(dir, name);
                    try (FileOutputStream fos = new FileOutputStream(f)) { fos.write(bytes); }
                    uri = FileProvider.getUriForFile(MainActivity.this, getPackageName() + ".files", f);
                }
                return uri.toString();
            } catch (Exception e) {
                return "";
            }
        }

        @JavascriptInterface
        public void openUri(String uri, String mime) {
            runOnUiThread(() -> {
                try {
                    Intent i = new Intent(Intent.ACTION_VIEW);
                    i.setDataAndType(Uri.parse(uri), mime);
                    i.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
                    startActivity(Intent.createChooser(i, "Open with"));
                } catch (Exception e) {
                    Toast.makeText(MainActivity.this, "No app found to open this file", Toast.LENGTH_SHORT).show();
                }
            });
        }

        @JavascriptInterface
        public void shareUri(String uri, String mime) {
            runOnUiThread(() -> {
                try {
                    Intent i = new Intent(Intent.ACTION_SEND);
                    i.setType(mime);
                    i.putExtra(Intent.EXTRA_STREAM, Uri.parse(uri));
                    i.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
                    startActivity(Intent.createChooser(i, "Share"));
                } catch (Exception e) {
                    Toast.makeText(MainActivity.this, "Couldn't share", Toast.LENGTH_SHORT).show();
                }
            });
        }

        @JavascriptInterface
        public void shareText(String text) {
            runOnUiThread(() -> {
                Intent i = new Intent(Intent.ACTION_SEND);
                i.setType("text/plain");
                i.putExtra(Intent.EXTRA_TEXT, text);
                startActivity(Intent.createChooser(i, "Share report"));
            });
        }

        @JavascriptInterface
        public void copyText(String text) {
            runOnUiThread(() -> {
                ClipboardManager cm = (ClipboardManager) getSystemService(Context.CLIPBOARD_SERVICE);
                if (cm != null) cm.setPrimaryClip(ClipData.newPlainText("SiteTrack", text));
            });
        }

        @JavascriptInterface
        public void toast(String text) {
            runOnUiThread(() -> Toast.makeText(MainActivity.this, text, Toast.LENGTH_SHORT).show());
        }
    }
}
EOF_ST
mkdir -p app/src/main/assets app/src/main/res/mipmap-xxxhdpi
cp index.html app/src/main/assets/index.html
echo 'iVBORw0KGgoAAAANSUhEUgAAAMAAAADABAMAAACg8nE0AAAAMFBMVEXytwXsswbZpQjMnArKmgrAkwywiA6hfRB2XxZaSxpGPRw8NR47NR4vLR8fISIbHiKrIkqVAAADHElEQVR42u2bzWsTQRTA36ZR8bRzKeKtqR/1GOhBPAvizeBBUry05KDkVAULXTx4KdFKvVW9iLmUiiD6Dwge9aDkJFRRAl4sKJ3Fg21I8zxsG2fdNTs78yZReHPJTiZ5v7z35n3MhvUQ3I4CMIABDGAAAxjAAAYwYCiAYvrbocgvKr1H9JBI/N8QBUL54OkBjOWnElIAwsKlQgMQ2uyZMBsQCqtd6WUChOW+F6OO5NBWYJgBENY/WQwEhPY2CUfrA0EgUoxSg5BCZMgl0wYgSGQK9gEDGMAABjBA84ymtMuXzk6X8NO7z0/bhucqdSSXD9zbX9t9OAcAcBjTxqz6HT8mcjCg+FxdXjMAZPhguaLOLpI7+eg1x7towfE2PTjvGuA60GquAWUAAOgsTBaOV5cN42xgHGwhInb3dmpxceunsnYBERFfpInUDrQxRET80p8fuW8AGGSiMQAAeNafb9aJfRDdFpD/cT1A4wSUC3Cq7AywG1WEN9ddAXqtKGGsbCwJN05+tfd6Mvj2oOwC8Ph3SFx9u+QA8EH9YLBOD9iJZYLqGjkAb8amM/Pkkfy+GUsdDXIAXmmp00MV8lzUOa/q4M3SJ7vNWqCk03MOsmmvMR604hWCOl13G9OLbc1W2bAe9G5PRRFRKLsqOJ2Z6HXCWUXbbhresdIume3hAIidvJp4R9IC6qt/tpFtYhPV1/eNXqgAAGCL2gfV13PRxeUJAICupG1+ERF7T26UvBNBtL5N2/xC4jD5g7b5TY5HjntTbDoG7LQcA+64a7wAAODrLfJTplouoXOGvi9qTN3tIzZOG+W7+F/uKX84j9cmj5XE95cfV7Rl+jIPwGDEAHxTkAEMYAADGMAABjgGICLKvFdS/4Tj96d5rqT+CcdIgRwAMwVQ/4xmo4AOwEoBHYCVAhoAOwU0AHYKZAMsFYgD+ADyrwEkiUzJFc0C4JOEwUhNJKk30dA18KldkNBAElsoAfCJFRhBoElaCyUBvh0Bs1OFT+mBVB9IQgOlAiyMhHrZ1JiAuo8qOX8WiisaAxjAAAYwgAEMYAD9+AX6CpFha07fDQAAAABJRU5ErkJggg==' | base64 -d > app/src/main/res/mipmap-xxxhdpi/ic_launcher.png
