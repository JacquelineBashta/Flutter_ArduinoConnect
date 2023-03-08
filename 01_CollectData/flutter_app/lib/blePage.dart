import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:location_permissions/location_permissions.dart';
import 'dart:async';
import 'dart:io' show Platform;
import 'dart:io';
import 'dart:core';
import 'package:flow_draw/bleCard.dart';
import 'package:flow_draw/utils.dart';
import 'package:flow_draw/userDialog.dart';
import 'package:flow_draw/algos.dart';
import 'package:ditredi/ditredi.dart';
import 'package:vector_math/vector_math_64.dart' as vector;
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
import 'dart:math';
import 'package:collection/collection.dart';

class BluetoothPage extends StatefulWidget {
  @override
  State<BluetoothPage> createState() => _BluetoothPageState();
}

class _BluetoothPageState extends State<BluetoothPage>
    with TickerProviderStateMixin {
  final flutterReactiveBle = FlutterReactiveBle();
  List<DiscoveredDevice> devicesFound = [];

  bool debug = false ;

  // Some state management stuff
  bool _connected = false;
  String _activeDeviceId = "";

  // Bluetooth related variables
  late StreamSubscription<DiscoveredDevice> _scanStream;
  late StreamSubscription<ConnectionStateUpdate> _currentConnectionStream;
  late QualifiedCharacteristic _qualifyMotionAccGyroCharacteristic;
  late QualifiedCharacteristic _qualifyMotionOriGravCharacteristic;

  // These are the UUIDs of your device
  final String deviceName = "NiclaSenseMEB44E";
  final Uuid serviceUuid = Uuid.parse("19b10000-0000-537e-4f6c-d104768a1214");
  final Uuid motionAccGyroCharacteristic =
      Uuid.parse("19b10000-4001-537e-4f6c-d104768a1214");
  final Uuid motionOriGravCharacteristic =
      Uuid.parse("19b10000-5001-537e-4f6c-d104768a1214");

  //
  late AnimationController controller;
  late DiTreDiController diTreDiController;

  // Record sensor data to csv
  bool _record = false;
  late String csvName;
  List<List<int>> recordedData = [];
  late List<String> recordsNameList;
  late String savedFilePath;
  late String txtListName="DrinkBottle";

  // Quality measures
  late DateTime startTime;
  int elapsedMs = 0;
  int recordTime = 0;
  String infoRecord = "";

  // Machine learning Model
  late tfl.Interpreter _interpreter;
  late List mlOutputs;
  late List<List<double>> inputList;
  int modelListLen = 100;
  int modelDataLen = 52;
  bool modelLoaded = false;

  void updateRecordsList(String txtFileName){
    getRecordLists(txtFileName).then((List<String> result) {
      setState(() {
        recordsNameList = result;
        csvName = recordsNameList.first;
      });
    });
    getDocumentsPath().then((String? result) {
      setState(() {
        savedFilePath = result!;
      });
    });
  }

  @override
  void initState() {
    super.initState();

    _startScan();

    diTreDiController = DiTreDiController();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..addListener(() {
        setState(() {});
      });
    controller.repeat(reverse: false);

    recordsNameList = [];
    csvName = "";
    savedFilePath="";
    updateRecordsList(txtListName);
  }

  @override
  void dispose() {
    _disconnect();
    _interpreter.close();
    super.dispose();
  }

  void _startScan() async {
    if(!_connected) {
      devicesFound.clear();

      // Platform permissions handling stuff
      bool permGranted = false;

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
            if (!(devicesFound.any((item) => item.name == device.name))) {
              devicesFound.add(device);
            }
          });

          if (device.name == deviceName) {
            print("device found " + device.name.toString());
            //setState(() {
            //  _ubiqueDevice = device;
            //});
          }
        });
      }
    }
  }

  void _connectToDevice(String deviceID) {
    if (!_connected) {
      setState(() {
        recordedData.clear();
        _activeDeviceId = deviceID;
      });

      // We're done scanning, we can cancel it
      _scanStream.cancel();
      // Let's listen to our connection so we can make updates on a state change
      _currentConnectionStream =
          flutterReactiveBle.connectToDevice(id: deviceID).listen(
        (event) async {
          switch (event.connectionState) {
            // We're connected and good to go!
            case DeviceConnectionState.connected:
              {
                print("Device Connected");
                setState(() {
                  _connected = true;
                });

                await _readCharacteristics();
                break;
              }
            // Can add various state state updates on disconnect
            case DeviceConnectionState.disconnected:
              {
                print("Device Disconnected");
                setState(() {
                  _connected = false;
                });
                break;
              }
            default:
          }
        },
        onError: (Object e) =>
            print('Connecting to device $deviceID resulted in error $e'),
      );
    }
  }

  void _disconnect() async {
    try {
      setState(() {
        _record = false;
        _connected = false;
        _activeDeviceId = "";
      });
      await _currentConnectionStream.cancel();

    } on Exception catch (e, _) {
      print("Error disconnecting from a device: $e");
    }
  }

  _readCharacteristics() async {
    if (_connected) {
      _qualifyMotionAccGyroCharacteristic = QualifiedCharacteristic(
          serviceId: serviceUuid,
          characteristicId: motionAccGyroCharacteristic,
          deviceId: _activeDeviceId);
      flutterReactiveBle
          .subscribeToCharacteristic(_qualifyMotionAccGyroCharacteristic)
          .listen((data) async{
        if (_record) {

          var dataRec = convertBleData2Int(data);
          if(debug) {
            detectHit(List<int>.from(dataRec.sublist(1, 4)));
          }

          // check if the time index already exist
          final listIndex =
              recordedData.indexWhere((element) =>  element[0] == dataRec[0]);
          if (listIndex != -1) {
            recordedData[listIndex]
                .replaceRange(1, 7, List<int>.from(dataRec.sublist(1, 7)));

            await prepareModel(recordedData[listIndex]);
          } else {
            List<int> defaultList = List.generate(13, (i) => 0);
            defaultList.replaceRange(0, 7, List<int>.from(dataRec));
            setState(() {
              recordedData.add(defaultList);
              elapsedMs = DateTime.now().difference(startTime).inMilliseconds; // 20 ms
              recordTime+=elapsedMs;
              startTime = DateTime.now();
            });
          }
        }
      }, onError: (dynamic error) {
        print("error reading motionAccGyroCharacteristic");
      });

      _qualifyMotionOriGravCharacteristic = QualifiedCharacteristic(
          serviceId: serviceUuid,
          characteristicId: motionOriGravCharacteristic,
          deviceId: _activeDeviceId);

      flutterReactiveBle
          .subscribeToCharacteristic(_qualifyMotionOriGravCharacteristic)
          .listen((data) async {
        if (_record) {
          var dataRec = convertBleData2Int(data);

          // check if the time index already exist
          final listIndex =
              recordedData.indexWhere((element) => element[0] == dataRec[0]);
          if (listIndex != -1) {
            recordedData[listIndex]
                .replaceRange(7, 13, List<int>.from(dataRec.sublist(1, 7)));

            await prepareModel(recordedData[listIndex]);

          } else {
            //  recordedData.add([dataRec[0] , 0,0,0,0,0,0 , dataRec[7:12]);
            List<int> defaultList = List.generate(13, (i) => 0);
            defaultList[0] = dataRec[0];
            defaultList.replaceRange(
                7, 13, List<int>.from(dataRec.sublist(1, 7)));

            setState(() {
              recordedData.add(defaultList);
            });
          }

          if(debug) {
            diTreDiController.update(
                rotationX: (dataRec[1]).toDouble(),
                rotationY: (dataRec[3]).toDouble(),
                rotationZ: (180 - dataRec[2]).toDouble());
          }
        }
      }, onError: (dynamic error) {
        print("error reading motionOriGravCharacteristic");
      });
    }
  }

  void _recordData() async {
    if (_connected && !_record) {
      setState(() {
        startTime = DateTime.now();
        recordTime=0;
        _record = true;
      });
    }
  }

  void _stopRecordData() async {
    if (recordedData.isNotEmpty && _record) {
      setState(() {
        _record = false;
      });
      //_disconnect(); // to reset time_count in Nicla

      // https://www.bosch-sensortec.com/media/boschsensortec/downloads/datasheets/bst-bhi260ap-ds000.pdf
      // userAcceleration data
      // float S8g = 4096.0;
      // NewAcceleration = userAcceleration/S8g ;  //unit = g

      // For rotationRate data (speed of rotation)
      // float RFS2000 = 16.4;
      // NewRotationRate = rotationRate/RFS2000 ;  //unit = deg/sec

      // attitude "should be renamed to oriantation" (angle of rotation) unit = degree

      // gravity ( gravitional force on sensor axis)
      // float S8g = 4096.0;
      // NewGravity = gravity/S8g ;  //unit = g

      // clean up data
      if (recordedData.isNotEmpty) {
        recordedData.removeAt(recordedData.length - 1);
        for (int i = 0; i < 10; i++) {
          recordedData.removeAt(i);
        }
      }

      int sentData = recordedData.last[0] - recordedData.first[0] +1;
      infoRecord =
          "accuracy ${double.parse(((recordedData.length/sentData)*100).toStringAsFixed(2))} %"
          //"received $sentData"
          "\nrecorded ${recordedData.length}"
          //"\nin $recordTime milli sec"
          //"\navg time = ${(recordTime/recordedData.length).ceil()} ms";
          "\navg freq = ${(1000/(recordTime/recordedData.length)).ceil()} Hz";
      // user enter file name
      _displayTextInputDialog(context);
    }
  }

  Future<void> _displayTextInputDialog(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return WillPopScope(
          onWillPop: () => Future.value(false),
          child: DisplayUserDialog(
            valueText: csvName,
            infoText: infoRecord,
            // You can use the callback function like this
            onConfirm: (bool confirmed) {
              if (confirmed) {
                saveSensorData(fileName: csvName, sensorData: recordedData)
                    .then((dynamic result) {
                  setState(() {
                    recordedData.clear();
                    updateRecordsList(txtListName);
                  });
                });
              }
              else {
                recordedData.clear();
              }
            },
          ),
        );
      });
  }

  loadModel() async {
    //initialize input list with zeros
    if(!modelLoaded) {
      inputList = List.generate(modelListLen, (index) => (List.generate(
          modelDataLen, (index) => (0))));
      _interpreter = await tfl.Interpreter.fromAsset('My_TFlite_Model.tflite');
      modelLoaded = true;
      print("Model Loaded $modelLoaded");
    }
    // await Tflite.loadModel(
    //     model: "assets/best_model_LSTM.tflite",
    //     labels: "assets/labels.txt",
    // );
  }

  prepareModel(List<int> inputData) async {
    await loadModel();

    //inputData = recordedData at anytime ( 9 values )
    // time,rotationRate_x,rotationRate_y,rotationRate_z,userAcceleration_x,userAcceleration_y,userAcceleration_z,orientation_roll,orientation_pitch,orientation_yaw,gravity_x,gravity_y,gravity_z

    //apply conversions
    List<double> newData = List.generate(modelDataLen, (index) => 0); // (features 52 values)

    double rotX = inputData[1]/(16.4*100);
    double rotY = inputData[2]/(16.4*100);
    double rotZ = inputData[3]/(16.4*100);
    double accX = inputData[4]/4096.0;
    double accY = inputData[5]/4096.0;
    double accZ = inputData[6]/4096.0;
    double oriX = inputData[7]/100;
    double oriY = inputData[8]/100;
    double oriZ = inputData[9]/100;
    double gravX = inputData[10]/4096.0;
    double gravY = inputData[11]/4096.0;
    double gravZ = inputData[12]/4096.0;


    newData[0] = (sqrt(pow(accX+gravX, 2) + pow(accY+gravY, 2) + pow(accZ+gravZ, 2)));

    newData[4] = (rotX); //rotationRate_x
    newData[8] = (rotY);
    newData[12] = (rotZ);

    newData[16] = (accX);  //userAcceleration_x
    newData[20] = (accY);
    newData[24] = (accZ);

    newData[28] = (oriX);  //or_x
    newData[32] = (oriY);
    newData[36] = (oriZ);

    newData[40] = (gravX);  //gravity_x
    newData[44] = (gravY);
    newData[48] = (gravZ);

    //add list to inputList
    setState(() {
      inputList.removeAt(0);
      inputList.add(newData);
    });

    rollModel();
    await runModel();
  }

  List<double> getColumn(int index) {
    int rollSteps = 100;
    List<double> newColumn = <double>[];

    for(int i=0; i<rollSteps ;i++){
      newColumn.add(inputList[i][index]);
    }

    return newColumn;
  }
  double getStd(List<double> data){
    // Calculate the mean
    double mean = data.reduce((a, b) => a + b) / data.length;

    // Calculate the variance
    double variance = data.map((x) => pow(x - mean, 2)).reduce((a, b) => a + b) /
        (data.length - 1);

    // Calculate the standard deviation
    double standardDeviation = sqrt(variance);

    return standardDeviation;
  }
  double getMedian(List<double> data) {
    var middle = data.length ~/ 2;
    if (data.length % 2 == 1) {
      return data[middle];
    } else {
      return (data[middle - 1] + data[middle]) / 2.0;
    }
  }

  rollModel() {
    for(int j=0; j<51; j=j+4) {
      inputList.last[j+1] = getColumn(j).average;
      inputList.last[j+2] = getStd(getColumn(j));
      inputList.last[j+3] = getMedian(getColumn(j));
     }
  }

  runModel() async {
    // reshap input
    var input = <List<double>>[];
    input.add(inputList.last);

    var output = List<double>.filled(1, 55).reshape([1,1]);

    _interpreter.run(input, output);

    if(output[0][0] >= 0.5) {
      print("predict = $output");
    }
    setState(() {
      //mlOutputs = output!;
    });
  }


  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton.icon(
          onPressed: _startScan,
          icon: const Icon(Icons.search),
          label: const Text('Scan'),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                onPressed: _recordData,
                icon: Icon(Icons.play_circle,
                    color: _record ? Colors.green : Colors.red),
                label: const Text('Record'),
              ),
            ),
            Visibility(
              visible: _record,
              child: CircularProgressIndicator(
                value: controller.value,
                semanticsLabel: 'Progress indicator',
              ),
            ),
            const SizedBox(width: 10),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                onPressed: _stopRecordData,
                icon: const Icon(Icons.stop_circle, color: Colors.red),
                label: const Text('Stop'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        FittedBox(
            fit: BoxFit.fitWidth,
            child: Text(
              "Records will be saved at \n $savedFilePath"
            ),
        ),

        FittedBox(
          fit: BoxFit.fitWidth,
          child: DropdownButton<String>(
            value: txtListName,
            items: ["DrinkBottle","DrinkCup",
              "EatFood","LookMobile"].
            map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child:
                Text(
                  value
                ),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                txtListName=newValue!;
                updateRecordsList(newValue!);
              });
            },
          ),
        ),

        const SizedBox(height: 10),

        FittedBox(
          fit: BoxFit.fitWidth,
          child:
          DropdownButton<String>(
            value: csvName,
            items: recordsNameList.map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child:
                Text(
                  value,
                  style: const TextStyle(fontSize: 18),
                ),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                csvName = newValue!;
              });
            },
          ),
        ),

        const SizedBox(height: 10),

        Expanded(
          child: ListView(
            children: devicesFound
                .map((device) => BleCard(
                      title: Text(device.name),
                      subtitle: Text(device.id),
                      note: Text("RSSI : ${device.rssi}"),
                      icon: const Icon(Icons.bluetooth),
                      color:
                          _connected ? Colors.lightBlueAccent : Colors.white30,
                      onConnect: (String deviceID) {
                        print("connecting $deviceID");
                        _connectToDevice(deviceID);
                      },
                      onDisconnect: (String deviceID) {
                        print("disconnecting $deviceID");
                        _disconnect();
                      },
                    ))
                .toList(),
          ), // And rest of them in ListView
        ),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children:
            <Widget>[
          if (debug == true) ...[
            Text(
             '$elapsedMs',
             style: TextStyle(backgroundColor: elapsedMs >30 ? elapsedMs >50 ? Colors.red : Colors.yellow : Colors.green,
                 fontSize: 24),
            ),
            Text(
             '$elapsedMs',
             style: TextStyle(backgroundColor: elapsedMs >30 ? elapsedMs >50 ? Colors.red : Colors.yellow : Colors.green,
                 fontSize: 24),
            ),
            SizedBox(
              height: 150,
              width: 150,
              child:
              DiTreDi(
                figures: [
                  Cube3D(1, vector.Vector3(0, 0, 0), color: _record ? Colors.lightBlueAccent : Colors.white10),
                ],
                config: const DiTreDiConfig(
                  supportZIndex: false,
                ),
                controller: diTreDiController,
              ),
            ),
          ]],
        ),

        const SizedBox(height: 10),
        Expanded(
          //flex: 2,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: ListView(
              children: recordedData.reversed
                  .map((dataList) => Text(dataList.toString()))
                  .toList(),
            ),
          ), // And rest of them in ListView
        ),
      ],
    );
  }
}
