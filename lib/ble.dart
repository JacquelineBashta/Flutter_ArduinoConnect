import 'dart:ffi';

import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:location_permissions/location_permissions.dart';
import 'dart:async';
import 'dart:io' show Platform;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flow_draw/card.dart';
import 'package:flow_draw/chart.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'dart:math' as math;
import 'package:csv/csv.dart';

class BluetoothPage extends StatefulWidget {
  @override
  State<BluetoothPage> createState() => _BluetoothPageState();
}

class _BluetoothPageState extends State<BluetoothPage> {
    final double gForce = 9.81;
    ChartData _accXData = ChartData();
    ChartData _accYData = ChartData();
    ChartData _accZData = ChartData();

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

    List<List<int>> recordedData = [];

    @override
    void initState() {
      _accXData.fill();
      _accYData.fill();
      _accZData.fill();
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
      // Main scanning logic happens here ⤵️
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
          //_connected?_accXData.updateDataSource(data[0] ~/ gForce):print("Disconnected");
          //_connected?_accYData.updateDataSource(data[1] ~/ gForce):print("Disconnected");
          //_connected?_accZData.updateDataSource(data[2] ~/ gForce):print("Disconnected");

          List<int> defaultList = List.generate(13, (i) => 0);

          var dataRec = _convert_ble_data2int(data);
          if(recordedData.length >=  dataRec[0]) {
            // time_count start with 1
            print("found TBD");
            //recordedData[dataRec[0]] = dataRec.sublist(1,7);
          }
          else{
            print("data recorded");

            defaultList.replaceRange(0,7, List<int>.from(dataRec) );
            setState(() {
              recordedData.add(defaultList);
            });
          }


          }, onError: (dynamic error) {
          print("error reading accelerometerCharacteristic");
        });

        _qualifyMotionOriGravCharacteristic = QualifiedCharacteristic(
            serviceId: serviceUuid,
            characteristicId: motionOriGravCharacteristic,
            deviceId: _ubiqueDevice.id);

        flutterReactiveBle.subscribeToCharacteristic(_qualifyMotionOriGravCharacteristic).listen((data) {
          //save to file
          //print("*******************");
          //print("data= $data");

          var dataRec = _convert_ble_data2int(data);
          //if(dataRec[0] in recordedData indexes) {
          //  recordedData[dataRec[0]] = dataRec[7:12];
          //}
          //else{
          //  recordedData.add([dataRec[0] , 0,0,0,0,0,0 , dataRec[7:12]);
          //}

        }, onError: (dynamic error) {
          print("error reading motionCharacteristic");
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
          print("i :  $i");
          value = (value - 32768 * 2);
        }
        allVal.add(value);
        i +=1; // act as i+2 in the for loop
      }

      return allVal;
    }

    _recordData() async {

      Directory? appDocumentsDirectory = await getExternalStorageDirectory(); // 1
      String? appDocumentsPath = appDocumentsDirectory?.path; // 2

      if (appDocumentsPath != null) {
        print('File path: $appDocumentsPath');
        String filePath = '$appDocumentsPath/tempData.csv'; // 3
        File file = File(filePath);

        //file.writeAsString(
        //    "time,attitude_roll,attitude_pitch,attitude_yaw,gravity_x,gravity_y,gravity_z,rotationRate_x,rotationRate_y,rotationRate_z,userAcceleration_x,userAcceleration_y,userAcceleration_z"); // 2

        // convert rows to String and write as csv file
        //String csv = const ListToCsvConverter().convert(recordedData);
        String csv ="";
        print("recordedData : $recordedData");
        for(List<int> data in recordedData){
          csv += data.join(', ');
          csv += "\n";
        }

        print("csv : $csv");
        file.writeAsString(csv);
        //String fileContent = await file.readAsString(); // 2
        //print('File Content: $fileContent');
        ///data/user/0/com.example.flow_draw/app_flutter
        return null;
      }
    }

    _stopRecordData() async {
      _disconnect(); // to reset time_count in Nicla

      // code for saving data to be handled here!
      _recordData();

    }

    @override
    Widget build(BuildContext context) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton.icon(
                  onPressed: _startScan,
                  icon: Icon(
                    Icons.saved_search ,
                    color: _scanStarted ? Colors.green:Colors.grey),
                  label: const Text('Scan'),
                ),
              ),
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
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton.icon(
                  onPressed: _readCharacteristics,
                  icon: const Icon(Icons.celebration_rounded),
                  label: const Text('Graph'),
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

          const SizedBox(height: 10),

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

          Expanded(
          child:  SfCartesianChart(
            series: <LineSeries<BaseData, int>>[
              addSeries(_accXData),
              addSeries(_accYData),
              addSeries(_accZData),
            ],
          ),
        ),
        ],
      );
    }
}

/// Add series into the chart.
LineSeries<BaseData, int> addSeries(ChartData _chartdata) {
  return LineSeries<BaseData, int>(
      onRendererCreated: (ChartSeriesController controller) {
      // Assigning the controller to the _chartSeriesController.
        _chartdata.chartSeriesController = controller;
      },
      // Binding the chartData to the dataSource of the line series.
      dataSource: _chartdata.baseDataList,
      xValueMapper: (BaseData data, _) => data.time,
      yValueMapper: (BaseData data, _) => data.value,
  );
}
