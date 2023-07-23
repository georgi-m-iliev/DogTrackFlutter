import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';

class HomePage extends StatefulWidget {
  final BluetoothDevice server = const BluetoothDevice(
      address: String.fromEnvironment('HC05_MAC_ADDRESS'));
  const HomePage({Key? key}) : super(key: key);

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  final Completer<GoogleMapController> _controller = Completer();
// on below line we have specified camera position

  Future<Position> getUserCurrentLocation() async {
    await Geolocator.requestPermission()
        .then((value) {})
        .onError((error, stackTrace) async {
      await Geolocator.requestPermission();
      print("ERROR$error");
    });
    return await Geolocator.getCurrentPosition();
  }

  static CameraPosition _kGoogle = const CameraPosition(
    target: LatLng(42.5633914, 25.6155994),
    zoom: 16,
  );

  BluetoothConnection? connection;
  bool isConnecting = true;
  bool get isConnected => (connection?.isConnected ?? false);
  bool isDisconnecting = false;

  void connectDevice() {
    BluetoothConnection.toAddress(widget.server.address).then((_connection) {
      print('Connected to the device');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Connection successfully established!"))
      );
      connection = _connection;
      setState(() {
        isConnecting = false;
        isDisconnecting = false;
      });

      connection!.input!.listen(_onDataReceived).onDone(() {
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
        }
        if (this.mounted) {
          setState(() {});
        }
      });
    }).catchError((error) {
      print('Cannot connect, exception occured');
      print(error);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Connection attempt failed!"))
      );
    });
  }

  void disconnectDevice() {
    isDisconnecting = true;
    connection?.finish();
  }

  @override
  void initState() {
    getUserCurrentLocation().then((value) {
      _kGoogle = CameraPosition(
        target: LatLng(value.latitude, value.longitude),
        zoom: 14.4746,
      );
    });

    super.initState();

    Permission.bluetoothScan.status.then((status) {
      if (status.isGranted) {
        // We didn't ask for permission yet or the permission has been denied before but not permanently.
      }
    });
  }

  void _onDataReceived(Uint8List data) {
    print(data);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: GoogleMap(
            initialCameraPosition: _kGoogle,
            mapType: MapType.normal,
            myLocationEnabled: true,
            compassEnabled: true,
            zoomControlsEnabled: false,
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
            },
            markers: {
              const Marker(
                  markerId: MarkerId('1'),
                  position: LatLng(20.42796133580664, 75.885749655962),
                  infoWindow: InfoWindow(
                    title: 'My Position',
                  ))
            }),
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
