import 'homepage.dart';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  void requestPermissions() async {
    [
      Permission.location,
      Permission.locationWhenInUse,
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect
    ].request().then((Map<Permission, PermissionStatus> statuses) {
      if(statuses[Permission.location] != PermissionStatus.granted) {
        Fluttertoast.showToast(
          msg: "Location permission error! Permission is ${statuses[Permission.location]}",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.CENTER,
          timeInSecForIosWeb: 1,
          textColor: Colors.white,
          backgroundColor: Colors.red.shade400,
          fontSize: 16.0
        );
      }
      if(statuses[Permission.bluetooth] != PermissionStatus.granted) {
        Fluttertoast.showToast(
          msg: "Bluetooth permission error! Permission is ${statuses[Permission.bluetooth]}",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.CENTER,
          timeInSecForIosWeb: 1,
          textColor: Colors.white,
          backgroundColor: Colors.red.shade400,
          fontSize: 16.0
        );
      }
      // log(statuses[Permission.location])      
    });
  }

  void requestBluetooth(BuildContext context) {
    FlutterBluetoothSerial.instance.isEnabled.then((enabled) {
      if(!enabled!) {
        FlutterBluetoothSerial.instance.requestEnable().then((request) {
          if (request!) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Bluetooth enabled!"))
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Bluetooth not enabled!"))
            );
          }
        });
      }
    });
  }

// This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    requestPermissions();
    requestBluetooth(context);

    return MaterialApp(
      // on below line we are specifying title of our app
      title: 'DogTrack',
      // on below line we are hiding debug banner
      debugShowCheckedModeBanner: true,
      theme: ThemeData(
        // on below line we are specifying theme
        primarySwatch: Colors.green,
      ),
      // First screen of our app
      home: const Scaffold(
        body: HomePage()
      ),
    );
  }
}
