"""يعدّل ملفات أندرويد و iOS بعد `flutter create` لإضافة الصلاحيات والإعدادات المطلوبة."""
import pathlib
import re
import sys

APP_NAME = "رفيق المسلم"
root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".")


def patch_android():
    manifest = root / "android/app/src/main/AndroidManifest.xml"
    if not manifest.exists():
        print("no android manifest, skipping")
        return
    m = manifest.read_text(encoding="utf-8")
    perms = [
        "android.permission.INTERNET",
        "android.permission.ACCESS_FINE_LOCATION",
        "android.permission.ACCESS_COARSE_LOCATION",
        "android.permission.POST_NOTIFICATIONS",
        "android.permission.RECEIVE_BOOT_COMPLETED",
        "android.permission.SCHEDULE_EXACT_ALARM",
        "android.permission.VIBRATE",
        "android.permission.WAKE_LOCK",
    ]
    block = "".join(
        f'    <uses-permission android:name="{p}"/>\n' for p in perms if p not in m
    )
    m = re.sub(r"(<manifest[^>]*>\n?)", r"\1" + block.replace("\\", "\\\\"), m, count=1)
    m = re.sub(r'android:label="[^"]*"', f'android:label="{APP_NAME}"', m, count=1)
    receivers = """
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
"""
    if "ScheduledNotificationReceiver" not in m:
        m = m.replace("</application>", receivers + "    </application>", 1)
    manifest.write_text(m, encoding="utf-8")
    print("patched AndroidManifest.xml")

    kts = root / "android/app/build.gradle.kts"
    groovy = root / "android/app/build.gradle"
    if kts.exists():
        g = kts.read_text(encoding="utf-8")
        if "isCoreLibraryDesugaringEnabled" not in g:
            g = re.sub(
                r"compileOptions\s*\{",
                "compileOptions {\n        isCoreLibraryDesugaringEnabled = true",
                g,
                count=1,
            )
        g = re.sub(r"minSdk\s*=\s*flutter\.minSdkVersion", "minSdk = 24", g)
        if "desugar_jdk_libs" not in g:
            g += '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'
        kts.write_text(g, encoding="utf-8")
        print("patched build.gradle.kts")
    elif groovy.exists():
        g = groovy.read_text(encoding="utf-8")
        if "coreLibraryDesugaringEnabled" not in g:
            g = re.sub(
                r"compileOptions\s*\{",
                "compileOptions {\n        coreLibraryDesugaringEnabled true",
                g,
                count=1,
            )
        g = re.sub(r"minSdk(Version)?\s*=?\s*flutter\.minSdkVersion", "minSdkVersion 24", g)
        if "desugar_jdk_libs" not in g:
            g += "\ndependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'\n}\n"
        groovy.write_text(g, encoding="utf-8")
        print("patched build.gradle")


def patch_ios():
    plist = root / "ios/Runner/Info.plist"
    if not plist.exists():
        print("no ios plist, skipping")
        return
    p = plist.read_text(encoding="utf-8")
    entries = {
        "NSLocationWhenInUseUsageDescription": "نحتاج موقعك لحساب مواقيت الصلاة واتجاه القبلة بدقة.",
        "NSLocationAlwaysAndWhenInUseUsageDescription": "نحتاج موقعك لحساب مواقيت الصلاة واتجاه القبلة بدقة.",
    }
    add = ""
    for k, v in entries.items():
        if k not in p:
            add += f"\t<key>{k}</key>\n\t<string>{v}</string>\n"
    if "UIBackgroundModes" not in p:
        add += "\t<key>UIBackgroundModes</key>\n\t<array>\n\t\t<string>audio</string>\n\t</array>\n"
    # اسم التطبيق
    p = re.sub(
        r"(<key>CFBundleDisplayName</key>\s*<string>)[^<]*(</string>)",
        r"\g<1>" + APP_NAME + r"\g<2>",
        p,
    )
    idx = p.rfind("</dict>")
    p = p[:idx] + add + p[idx:]
    plist.write_text(p, encoding="utf-8")
    print("patched Info.plist")


patch_android()
patch_ios()
