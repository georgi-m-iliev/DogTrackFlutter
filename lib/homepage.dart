import 'dart:ui' as ui;
import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
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

  Set<Marker> markers = {};
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
      log("ERROR$error");
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

  void connectDevice() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Initiating connection to device!"),
        duration: Duration(milliseconds: 1500)
      )
    );

    BluetoothConnection.toAddress(widget.server.address).then((result) {
      log('Connected to the device');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Connection successfully established!"),
          duration: Duration(seconds: 2)
        )
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
            const SnackBar(content: Text("Disconnect request success!"))
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Device disconnected willfully!"))
          );
          markers.clear();
        }
        if (mounted) {
          setState(() {});
        }
      });
    }).catchError((error) {
      log('Cannot connect, exception occured');
      log(error);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Connection attempt failed!"))
      );
    });
  }

  void disconnectDevice() {
    isDisconnecting = true;
    connection?.finish();
  }

  void addMarker(final LatLng loc) {
    // log(loc);
    setState(() {
      markers.clear();
      markers.add(
        Marker(
          markerId: const MarkerId("1"),
          position: loc,
          icon: customIcon,
        )
      );
      _controller.future.then((controller) {
        controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: loc, zoom: 16,)
          )
        );
      });
    });
  }

  LatLng parseData(String data, int endIndex, int sepIndex) {
    return LatLng(double.parse(data.substring(0, sepIndex)), double.parse(data.substring(sepIndex + 1, endIndex)));
  }

  void onDataReceived(Uint8List data) {
    dataBuffer += data;

    int endIndex = dataBuffer.indexOf('\n'.codeUnitAt(0));
    int sepIndex = dataBuffer.indexOf(' '.codeUnitAt(0));
    if (endIndex >= 0 && endIndex <= dataBuffer.length - 1) {
      String result = String.fromCharCodes(dataBuffer);
      // log(result);
      addMarker(parseData(result, endIndex, sepIndex));
      dataBuffer.clear();
    }
  }

  @override
  void initState() {
    getImages("assets/images/dog-paw.png", 150).then((value) {
      customIcon = BitmapDescriptor.fromBytes(value);
    });

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
