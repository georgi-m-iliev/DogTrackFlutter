# DogTrackFlutter

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
* wakelock
* flutter_localizations

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

## Acknowledgements

 - 
 - 
 - 

## Disclaimer

This app is for my personal usage. I do not guarantee support for any issues that may arise. Use this code at your own risk!