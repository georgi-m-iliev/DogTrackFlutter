import 'dart:ui' as ui;
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geolocator/geolocator.dart' as geolocator;
import 'package:location/location.dart' hide PermissionStatus;
import 'package:permission_handler/permission_handler.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

class HomePage extends StatefulWidget {
  final BluetoothDevice server = const BluetoothDevice(
      address: String.fromEnvironment('HC05_MAC_ADDRESS'));
  const HomePage({Key? key}) : super(key: key);

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  final Completer<GoogleMapController> _controller = Completer();
  final CameraPosition initPosition = const CameraPosition(
    target: LatLng(42.5633914, 25.6155994),
    zoom: 16,
  );

  Map<Permission, PermissionStatus> statuses = {};

  Location userLocation = Location();
  final List<LatLng> locHistory = [];
  final Set<Marker> markers = {};
  final Set<Polyline> polylines = {};
  double distanceFromDog = 0;
 
  late BitmapDescriptor customIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);

  BluetoothConnection? connection;
  bool isConnecting = true;
  bool get isConnected => (connection?.isConnected ?? false);
  bool isDisconnecting = false;
  List<int> dataBuffer = List<int>.empty(growable: true);

  // Function to convert asset to bytes for usage by BitmapDescriptor
  Future<Uint8List> getImages(String path, int width) async{
    ByteData data = await rootBundle.load(path);
    ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List(), targetHeight: width);
    ui.FrameInfo fi = await codec.getNextFrame();
    return(await fi.image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
  }

  LatLngBounds boundsFromLatLngList(List<LatLng> list) {
    assert(list.isNotEmpty);
    double x0, x1, y0, y1;    
    x0 = x1 = list.first.latitude;
    y0 = y1 = list.first.longitude;
    for (LatLng latLng in list) {
        if (latLng.latitude > x1) x1 = latLng.latitude;
        if (latLng.latitude < x0) x0 = latLng.latitude;
        if (latLng.longitude > y1) y1 = latLng.longitude;
        if (latLng.longitude < y0) y0 = latLng.longitude;
    }
    return LatLngBounds(northeast: LatLng(x1, y1), southwest: LatLng(x0, y0));
  }

  LatLng parseData(String data, int endIndex, int sepIndex) {
    return LatLng(double.parse(data.substring(0, sepIndex)),
        double.parse(data.substring(sepIndex + 1, endIndex)));
  }

  void requestPermissions() async {
    statuses = await [
      Permission.location,
      Permission.locationWhenInUse,
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect
    ].request();
    
    if (!mounted) return; // if the widget is disposed, then do nothing

    if (statuses[Permission.location] != PermissionStatus.granted ||
      statuses[Permission.locationWhenInUse] != PermissionStatus.granted) {
      Fluttertoast.showToast(
        msg: AppLocalizations.of(context)!.locationPermissionError(statuses[Permission.location].toString()),
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.CENTER,
        timeInSecForIosWeb: 1,
        textColor: Colors.white,
        backgroundColor: Colors.red.shade400,
        fontSize: 16.0
      );
    }

    if (statuses[Permission.bluetooth] != PermissionStatus.granted ||
      statuses[Permission.bluetoothScan] != PermissionStatus.granted ||
      statuses[Permission.bluetoothConnect] != PermissionStatus.granted ) {
      Fluttertoast.showToast(
        msg: AppLocalizations.of(context)!.bluetoothPermissionError(statuses[Permission.bluetooth].toString()),
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.CENTER,
        timeInSecForIosWeb: 1,
        textColor: Colors.white,
        backgroundColor: Colors.red.shade400,
        fontSize: 16.0
      );
    }
  }

  void requestBluetooth() async {
    PermissionStatus status = await Permission.bluetoothConnect.status;
    if (status != PermissionStatus.granted) {
      debugPrint("Bluetooth connect: $status");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.bluetoothPermissionError("Bluetooth access denied")))
        );
      }
      return;
    }

    bool? enabled = await FlutterBluetoothSerial.instance.isEnabled;
    if (!enabled!) {
      FlutterBluetoothSerial.instance.requestEnable().then((request) {
        if (request!) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.bluetoothRequestSuccess))
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.bluetoothRequestDeclined))
          );
        }
      });
    }
  }

  void connectDevice() {
    // Clear recent data from map
    locHistory.clear();
    markers.clear();
    polylines.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.initConnection))
    );

    BluetoothConnection.toAddress(widget.server.address).then((result) {
      debugPrint('Connected to the device');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.connectSuccessful))
      );
      connection = result;
      setState(() {
        isConnecting = false;
        isDisconnecting = false;
      });

      connection!.input!.listen(onDataReceived).onDone(() {
        // Example: Detect which side closed the connection
        // There should be `isDisconnecting` flag to show are we are (locally)
        // in middle of disconnecting process, should be set before calling
        // `dispose`, `finish` or `close`, which all causes to disconnect.
        // If we except the disconnection, `onDone` should be fired as result.
        // If we didn't except this (no flag set), it means closing by remote.
        if (isDisconnecting) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.localDisconnect))
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.remoteDisconnect))
          );
          markers.clear();
        }
        if (mounted) {
          setState(() {});
        }
      });
    }).catchError((error) {
      debugPrint('Cannot connect, exception occured');
      debugPrint(error.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(AppLocalizations.of(context)!.connectAttemptFailed),
            backgroundColor: Colors.red),
      );
    });
  }

  void disconnectDevice() {
    isDisconnecting = true;
    connection?.finish();
  }

  void onDataReceived(Uint8List data) {
    dataBuffer += data;

    int endIndex = dataBuffer.indexOf('\n'.codeUnitAt(0));
    int sepIndex = dataBuffer.indexOf(' '.codeUnitAt(0));
    if (endIndex >= 0 && endIndex <= dataBuffer.length - 1) {
      String result = String.fromCharCodes(dataBuffer);
      // debugPrint(result);
      updateLocation(parseData(result, endIndex, sepIndex));
      dataBuffer.clear();
    }
  }
  
  void updateLocation(final LatLng loc) {
    // debugPrint(loc);
    updateMarker(loc);
    if(locHistory.isEmpty) {
      locHistory.add(loc);
    }
    else {
      LatLng lastLoc = locHistory.last;
      locHistory.add(loc);
      if(geolocator.Geolocator.distanceBetween(loc.latitude, loc.longitude, lastLoc.latitude, lastLoc.longitude) > 2) {
        updatePolyline();
      }
    }
  }

  void updateCamera() async {
    LocationData currentLoc = await userLocation.getLocation();
    CameraUpdate camUpdate;
    //if no dog marker, center on user
    if(markers.isEmpty) {
      camUpdate = CameraUpdate.newLatLng(LatLng(currentLoc.latitude!, currentLoc.longitude!));
    }
    else {
      LatLngBounds bound = boundsFromLatLngList(
        [markers.last.position, LatLng(currentLoc.latitude!, currentLoc.longitude!)]
      );
      distanceFromDog = geolocator.Geolocator.distanceBetween(
        markers.last.position.latitude, markers.last.position.longitude, 
        currentLoc.latitude!, currentLoc.longitude!
      );
      camUpdate = CameraUpdate.newLatLngBounds(bound, 80);
    }
    
    setState(() {
      _controller.future.then((controller) {
        controller.animateCamera(camUpdate);
      });
    });
  }

  void updateMarker(final LatLng loc) async {
    setState(() async {
      markers.clear();
      markers.add(Marker(
        markerId: const MarkerId("1"),
        position: loc,
        icon: customIcon,
      ));
    });
    updateCamera();
  }

  void updatePolyline() {
    polylines.add(
      Polyline(
        polylineId: const PolylineId("1"),
        points: locHistory,
        color: Colors.orange.shade900,
        width: 3,
      )
    );
  }

  double getStraightLineDistance(lat1, lon1, lat2, lon2) {
    var R = 6371; // Radius of the earth in km
    var dLat = deg2rad(lat2 - lat1);
    var dLon = deg2rad(lon2 - lon1);
    var a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(deg2rad(lat1)) *
            math.cos(deg2rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    var c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    var d = R * c; // Distance in km
    return d * 1000; //in m
  }

  dynamic deg2rad(deg) {
    return deg * (math.pi / 180);
  }

  double calculateDistane(List<LatLng> polyline) {
    double totalDistance = 0;
    for (int i = 0; i < polyline.length - 1; i++) {
      totalDistance += getStraightLineDistance(
        polyline[i + 1].latitude,
        polyline[i + 1].longitude,
        polyline[i].latitude,
        polyline[i].longitude
      );
    }
    return totalDistance;
  }

  @override
  void initState() {
    getImages("assets/images/dog-paw.png", 180).then((value) {
      customIcon = BitmapDescriptor.fromBytes(value);
    });
    requestPermissions();
    requestBluetooth();

    super.initState();

    userLocation.serviceEnabled().then((serviceEnabled) {
      if(!serviceEnabled) {
        userLocation.requestService();
        userLocation.changeSettings(
          accuracy: LocationAccuracy.high, distanceFilter: 2, interval: 5000
        );
      }
    });
  }

  @override
  void didChangeDependencies() {
    userLocation.onLocationChanged.listen((LocationData currentLocation) {
      // debugPrint("Location changed");
      updateCamera();
    });
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    // Avoid memory leak (`setState` after dispose) and disconnect
    if (isConnected) {
      isDisconnecting = true;
      connection?.dispose();
      connection = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: GoogleMap(
          initialCameraPosition: initPosition,
          mapType: MapType.satellite,
          myLocationEnabled: true,
          compassEnabled: true,
          zoomControlsEnabled: false,
          onMapCreated: (GoogleMapController controller) {
            _controller.complete(controller);
          },
          markers: markers,
          polylines: polylines,
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        color: Colors.green.shade700,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Wrap(
            spacing: 20,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text("ø: ${distanceFromDog.toStringAsFixed(2)} m", style: const TextStyle(fontSize: 16, color: Colors.white)),
              Text("${AppLocalizations.of(context)!.walkDistanceLabel} ø: ${calculateDistane(locHistory).toStringAsFixed(2)} m", style: const TextStyle(fontSize: 16, color: Colors.white)),
              IconButton(
                onPressed: () => showDialog<String>(
                  context: context,
                  builder: (BuildContext context) => AlertDialog(
                    title: const Text('AlertDialog Title'),
                    content: Column(children: [
                      Switch(value: true, onChanged: (bool ds) {})
                    ]),
                    actions: <Widget>[
                      TextButton(
                        onPressed: () => Navigator.pop(context, 'Cancel'),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, 'OK'),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                ),
                icon: const Icon(Icons.settings, color: Colors.white))
            ])
        )
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (isConnected) {
            disconnectDevice();
          } else {
            connectDevice();
          }
        },
        backgroundColor: isConnected ? Colors.red : Colors.green,
        child: isConnected
            ? const Icon(Icons.bluetooth_disabled)
            : const Icon(Icons.bluetooth_connected),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
    );
  }
}
