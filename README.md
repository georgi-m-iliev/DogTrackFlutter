# DogTrackFlutter [![Aandroid release](https://github.com/georgi-m-iliev/DogTrackFlutter/actions/workflows/release-android.yml/badge.svg)](https://github.com/georgi-m-iliev/DogTrackFlutter/actions/workflows/release-android.yml)

Flutter App that visualises coordinates received from [DogTrack](https://github.com/georgi-m-iliev/DogTrack) on a Google Maps Component

## Requirements

* Flutter Dev Environment
* Android Studio (for Android Dev)
* Android SDK (for Android Dev)

## Used packages

* flutter_bluetooth_serial
* google_maps_flutter
* geolocator
* permission_handler
* fluttertoast
* flutter_launcher_icons
* wakelock_plus
* flutter_localizations
* http
* flutter_file_downloader
* app_installer
* package_info_plus

## Running the app

1. Satisfy the mentioned requirements
2. Run the following command to install all the required packages:
```bash
flutter pub get
```
3. Run the following command to start the app in debug mode
```bash
flutter run --dart-define-from-file=env.json	
```

## Build the app

```
flutter build apk --release --dart-define-from-file=env.json
```

## Automatic OTA updates

The app has an implemented update system, which relies on the Releases of this repository. On every startup a check is performed and if newer version is available, it would be downloaded.
**NB:** To perform the update you would have to allow the app to install .apk files.

## Acknowledgements

 - 
 - 
 - 

## Disclaimer

This app is for my personal usage. I do not guarantee support for any issues that may arise. Use this code at your own risk!
