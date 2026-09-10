# Setup note: generating the example app's native projects

This sandbox has no Flutter SDK, so `android/` and `ios/` native
project folders for the **example app** could not be generated here
(they're the standard `flutter create` boilerplate — MainActivity,
gradle wrapper, Xcode project, etc — none of which is
plugin-specific). An earlier version of this package included a
hand-written partial `android/` folder (manifest only, no
MainActivity/gradle files); **that caused a
"Build failed due to use of deleted Android v1 embedding" error**,
because Flutter's build tooling checks for a real
`MainActivity extends FlutterActivity` (v2 embedding) class, not just
a manifest tag. That partial folder has been removed from this
package. Follow these steps in order on a machine with Flutter
installed:

## 1. Generate the native projects

```bash
cd flutter_bio_auth/example
flutter create --platforms=android,ios --org com.example .
```

This creates a complete, current `android/` and `ios/` project
(MainActivity, gradle wrapper, settings.gradle, Xcode project, launch
screens, etc) with the v2 Android embedding already wired up
correctly — don't hand-write any of this yourself.

## 2. Add the camera permission (Android)

Open the **freshly generated**
`example/android/app/src/main/AndroidManifest.xml` and add one line
inside `<manifest>`, above `<application>`:

```xml
<uses-permission android:name="android.permission.CAMERA" />
```

Don't replace the whole file — the tool-generated `<application>`
block (with `MainActivity` and the `flutterEmbedding` v2 meta-data)
must stay exactly as generated.

## 3. Add the camera usage description (iOS)

Open the **freshly generated** `example/ios/Runner/Info.plist` and add
before the closing `</dict>`:

```xml
<key>NSCameraUsageDescription</key>
<string>This app uses the camera for face enrollment and authentication.</string>
```

## 4. Run

```bash
flutter pub get
flutter run
```

Then continue with the root `README.md` "Build validation" section
and expect/report further compile errors the same way — I can't run
the toolchain myself, so your `flutter analyze`/`flutter run` output
is the fastest feedback loop for shaking out the rest.
