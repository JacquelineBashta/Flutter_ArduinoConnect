
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:location_permissions/location_permissions.dart';
import 'dart:async';
import 'dart:io' show Platform;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flow_draw/card.dart';

class BluetoothPage extends StatefulWidget {
  @override
  State<BluetoothPage> createState() => _BluetoothPageState();
}

class _BluetoothPageState extends State<BluetoothPage> {
    final double gForce = 9.81;

    final flutterReactiveBle = FlutterReactiveBle();
    List<DiscoveredDevice> devicesFound = [];

    // Some state management stuff
    bool _foundDeviceWaitingToConnect = false;
    bool _scanStarted = false;
    bool _connected = false;

    // Bluetooth related variables
    late DiscoveredDevice _ubiqueDevice;
    late StreamSubscription<DiscoveredDevice> _scanStream;
    late StreamSubscription<ConnectionStateUpdate> _currentConnectionStream;
    late QualifiedCharacteristic _qualifyMotionAccGyroCharacteristic;
    late QualifiedCharacteristic _qualifyMotionOriGravCharacteristic;

    // These are the UUIDs of your device
    final String deviceName = "NiclaSenseME";
    final Uuid serviceUuid = Uuid.parse("19b10000-0000-537e-4f6c-d104768a1214");
    final Uuid motionAccGyroCharacteristic = Uuid.parse("19b10000-4001-537e-4f6c-d104768a1214");
    final Uuid motionOriGravCharacteristic = Uuid.parse("19b10000-5001-537e-4f6c-d104768a1214");

    TextEditingController _textFieldController = TextEditingController();
    late String codeDialog ;
    late String valueText = "dataset_drink_100ml_00";

    ScrollController _scrollController = ScrollController();

    List<List<int>> recordedData = [];

    @override
    void initState() {
      _startScan();
      super.initState();
    }

    @override
    void dispose() {
      _disconnect();
      super.dispose();
    }

    void _startScan() async {
    // Platform permissions handling stuff
      bool permGranted = false;
      setState(() {
        _scanStarted = true;
      });
      PermissionStatus permission;
      if (Platform.isAndroid) {
        permission = await LocationPermissions().requestPermissions();
        if (permission == PermissionStatus.granted) permGranted = true;
      } else if (Platform.isIOS) {
        permGranted = true;
      }
      // Main scanning logic happens here
      if (permGranted) {
        _scanStream = flutterReactiveBle
            .scanForDevices(withServices: [serviceUuid]).listen((device) {

          setState(() {
            if (!(devicesFound.any((item) => item.name == device.name))){
              devicesFound.add(device);
            }
          });

          if (device.name == deviceName) {
            print("device found " + device.name.toString());
            setState(() {
              _ubiqueDevice = device;
              _foundDeviceWaitingToConnect = true;
            });
          }
        });
      }
    }

    void _connectToDevice() {
      setState(() {
        recordedData.clear();
      });

      // We're done scanning, we can cancel it
      _scanStream.cancel();
      // Let's listen to our connection so we can make updates on a state change
      _currentConnectionStream =
          flutterReactiveBle.connectToDevice(id: _ubiqueDevice.id).listen(
            (event) async{
              switch (event.connectionState) {
              // We're connected and good to go!
                case DeviceConnectionState.connected:
                  {
                    await _readCharacteristics();

                    setState(() {
                      _foundDeviceWaitingToConnect = false;
                      _connected = true;
                    });
                    break;
                  }
              // Can add various state state updates on disconnect
                case DeviceConnectionState.disconnected:
                  {
                    print("Device Disconnected");
                    break;
                  }
                  default:
              }
        },
        onError: (Object e) =>
            print('Connecting to device ${_ubiqueDevice.id} resulted in error $e'),
      );
    }

    void _disconnect() async {
      try {
        await _currentConnectionStream.cancel();
        setState(() {
          _foundDeviceWaitingToConnect = true;
          _connected = false;
        });
      } on Exception catch (e, _) {
        print("Error disconnecting from a device: $e");
      }
    }

    _readCharacteristics() async{
      if (_connected) {
        _qualifyMotionAccGyroCharacteristic = QualifiedCharacteristic(
            serviceId: serviceUuid,
            characteristicId: motionAccGyroCharacteristic,
            deviceId: _ubiqueDevice.id);
        flutterReactiveBle.subscribeToCharacteristic(_qualifyMotionAccGyroCharacteristic).listen((data) {

          var dataRec = _convert_ble_data2int(data);

          final list_index = recordedData.indexWhere((element) => element[0] == dataRec[0]);
          if (list_index != -1) {
            recordedData[list_index].replaceRange(1,7, List<int>.from(dataRec.sublist(1,7)));
          }
          else{
            List<int> defaultList = List.generate(13, (i) => 0);
            defaultList.replaceRange(0,7, List<int>.from(dataRec) );
            setState(() {
              recordedData.add(defaultList);
            });
          }

          }, onError: (dynamic error) {
          print("error reading motionAccGyroCharacteristic");
        });

        _qualifyMotionOriGravCharacteristic = QualifiedCharacteristic(
            serviceId: serviceUuid,
            characteristicId: motionOriGravCharacteristic,
            deviceId: _ubiqueDevice.id);

        flutterReactiveBle.subscribeToCharacteristic(_qualifyMotionOriGravCharacteristic).listen((data) {

          var dataRec = _convert_ble_data2int(data);
          final list_index = recordedData.indexWhere((element) => element[0] == dataRec[0]);
          if (list_index != -1) {
            recordedData[list_index].replaceRange(7,13, List<int>.from(dataRec.sublist(1,7)));
          }
          else{
            //  recordedData.add([dataRec[0] , 0,0,0,0,0,0 , dataRec[7:12]);
            List<int> defaultList = List.generate(13, (i) => 0);
            defaultList[0]=dataRec[0];
            defaultList.replaceRange(7,13, List<int>.from(dataRec.sublist(1,7)));

            setState(() {
              recordedData.add(defaultList);
            });
          }

        }, onError: (dynamic error) {
          print("error reading motionOriGravCharacteristic");
        }) ;

      }
    }

    _convert_ble_data2int(List<int> dataList) {
      // each value is represented in short
      // [-32767 to 32768] -> represented in range [ 0 to 32768 *2 ]
      // each value takes 2 data elements (1st + (256 * 2nd))
      // 2th complement require to get negative values
      int value = 0;
      List allVal =[];

      for(int i=0 ; i<(dataList.length) ;i++){

        value = dataList[i] + 256 * dataList[i+1] ;
        if (value > 32767 && i!=0) {
          value = (value - 32768 * 2);
        }
        allVal.add(value);
        i +=1; // act as i+2 in the for loop
      }

      return allVal;
    }

    _recordData() async {
      _readCharacteristics();
    }

    _stopRecordData() async {
      _disconnect(); // to reset time_count in Nicla

      if (recordedData.isNotEmpty) {
        // clean up data
        recordedData.removeAt(recordedData.length - 1);
        recordedData.removeAt(0);
        recordedData.removeAt(1);
        recordedData.removeAt(2);
        recordedData.removeAt(3);
        recordedData.removeAt(4);
      }

      // user enter file name
      _displayTextInputDialog(context);
    }

    _saveData() async {
      String fileName = valueText;

      // Save to CSV
      Directory? appDocumentsDirectory = await getExternalStorageDirectory(); // 1
      String? appDocumentsPath = appDocumentsDirectory?.path; // 2

      if (appDocumentsPath != null) {
        print('File path: $appDocumentsPath');
        String filePath = '$appDocumentsPath/$fileName.csv'; // 3
        File file = File(filePath);

        String csv = "time,attitude_roll,attitude_pitch,attitude_yaw,gravity_x,gravity_y,gravity_z,rotationRate_x,rotationRate_y,rotationRate_z,userAcceleration_x,userAcceleration_y,userAcceleration_z";

        for(List<int> data in recordedData){
          csv += "\n";
          csv += data.join(', ');
        }
        file.writeAsString(csv);

        //print("csv : $csv");
        //String fileContent = await file.readAsString(); // 2
        //print('File Content: $fileContent');
        return null;
      }
    }

    Future<void> _displayTextInputDialog(BuildContext context) {
      return showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text('Enter CSV name'),
              content: TextField(
                onChanged: (value) {
                  setState(() {
                    valueText = value;
                  });
                },
                controller: _textFieldController,
                decoration: InputDecoration(hintText: "dataset_drink_100ml_00"),
              ),
              actions: <Widget>[
                ElevatedButton(
                  child: Text('CANCEL'),
                  onPressed: () {
                    setState(() {
                      Navigator.pop(context);
                    });
                  },
                ),
                ElevatedButton(
                  child: Text('OK'),
                  onPressed: () {
                    setState(() {
                      codeDialog = valueText;
                      Navigator.pop(context);
                    });
                    _saveData();
                  },
                ),

              ],
            );
          });
    }


    @override
    Widget build(BuildContext context) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(_scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 500),
              curve: Curves.fastOutSlowIn);
        }
      });

      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [

              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton.icon(
                  onPressed: _connectToDevice,
                  icon: Icon(Icons.power,
                      color: _connected ? Colors.green:Colors.grey),
                  label: const Text('Connect'),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton.icon(
                  onPressed: _disconnect,
                  icon: Icon(Icons.power_off,
                      color: _connected ? Colors.grey:Colors.red),
                  label: const Text('Disconnect'),
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton.icon(
                  onPressed: _recordData,
                  icon: const Icon(
                      Icons.save),
                  label: const Text('Record'),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton.icon(
                  onPressed: _stopRecordData,
                  icon: const Icon(Icons.stop_circle),
                  label: const Text('Stop'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10 ),

          Expanded(
            child: ListView(
              children:
              devicesFound.map((device) => IconCard(
                title: Text(device.name),
                subtitle: Text("ID : " +device.id + "\n RSSI : " + device.rssi.toString()),
                icon: Icon(Icons.bluetooth),
                color: _connected ? Colors.lightBlueAccent : Colors.white30 ,
              )).toList(),
            ), // And rest of them in ListView
          ),

          const SizedBox(height: 10),

          Expanded(
            child: ListView(
              children:
              recordedData.map((dataList) => Text(
                  dataList.toString()
              )).toList(),
            ), // And rest of them in ListView
          ),
        ],
      );

    }
}
