import 'dart:ui' as ui;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geolocator/geolocator.dart';
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

  final List<LatLng> locHistory = [];
  final Set<Marker> markers = {};
  final Set<Polyline> polylines = {};
 
  late BitmapDescriptor customIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);

  BluetoothConnection? connection;
  bool isConnecting = true;
  bool get isConnected => (connection?.isConnected ?? false);
  bool isDisconnecting = false;

  List<int> dataBuffer = List<int>.empty(growable: true);

  Future<Position> getUserCurrentLocation() async {
    await Geolocator.requestPermission()
        .then((value) {})
        .onError((error, stackTrace) async {
      await Geolocator.requestPermission();
      debugPrint("Error with fetching location");
    });
    return await Geolocator.getCurrentPosition();
  }

  // Function to convert asset to bytes for usage by BitmapDescriptor
  Future<Uint8List> getImages(String path, int width) async{
    ByteData data = await rootBundle.load(path);
    ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List(), targetHeight: width);
    ui.FrameInfo fi = await codec.getNextFrame();
    return(await fi.image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
  }

  LatLng parseData(String data, int endIndex, int sepIndex) {
    return LatLng(double.parse(data.substring(0, sepIndex)),
        double.parse(data.substring(sepIndex + 1, endIndex)));
  }

  void requestPermissions() async {
    Map<Permission, PermissionStatus> statuses =
    await [
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
        toastLength: Toast.LENGTH_SHORT,
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
        toastLength: Toast.LENGTH_SHORT,
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

  late LatLng lastLocation;
  
  void updateLocation(final LatLng loc) {
    // debugPrint(loc);
    setMarker(loc);
    LatLng lastLoc = locHistory.last;
    if(Geolocator.distanceBetween(loc.latitude, loc.longitude, lastLoc.latitude, lastLoc.longitude) > 2) {
      locHistory.add(loc);
      if(locHistory.length > 1) {
        addPolyline();
      }
    }
  }

  void setMarker(final LatLng loc) {
    setState(() {
      markers.clear();
      markers.add(Marker(
        markerId: const MarkerId("1"),
        position: loc,
        icon: customIcon,
      ));
      _controller.future.then((controller) {
        controller.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(
          target: loc,
          zoom: 16,
        )));
      });
    });
  }

  void addPolyline() {
    polylines.add(
      Polyline(
        polylineId: const PolylineId("1"),
        points: locHistory,
        color: Colors.orange.shade900,
        width: 3,
      )
    );
  }

  @override
  void initState() {
    getImages("assets/images/dog-paw.png", 150).then((value) {
      customIcon = BitmapDescriptor.fromBytes(value);
    });
    requestPermissions();
    requestBluetooth();

    super.initState();
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
    );
  }
}
