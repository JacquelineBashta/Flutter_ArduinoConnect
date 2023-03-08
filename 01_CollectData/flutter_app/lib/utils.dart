
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'package:flutter/services.dart' show rootBundle;

Future<String?> getDocumentsPath() async{
  Directory? appDocumentsDirectory = await getExternalStorageDirectory(); // 1
  String? appDocumentsPath = appDocumentsDirectory?.path; // 2
  return appDocumentsPath ;
}

Future<List<String>> loadCSVList(String txtName) async{
  String fileContent = await rootBundle.loadString('assets/$txtName.txt');
  List<String> listRet = [];

  for(String element in fileContent.split('\n')){
    listRet.add(element.trim());
  }
  listRet.removeWhere((element) => element=="");

  return listRet;
}

Future<List<String>> getRecordLists(String txtName) async{

  List<String> listRet = await loadCSVList(txtName);

  String? appDocumentsPath = await getDocumentsPath();

  if (appDocumentsPath != null) {
    List<FileSystemEntity> files = Directory(appDocumentsPath).listSync();
    for(FileSystemEntity file in files){
      File filePath = File(file.path);
      String fileName = basename(filePath.path);
      listRet.removeWhere((item) => item == fileName);
    }
  }

  return listRet;
}

saveSensorData( {required String fileName , required List<List<int>> sensorData} ) async {
  // Save to CSV
  String fileNameCSV = fileName.contains(".csv")? fileName: "$fileName.csv";

  String? appDocumentsPath = await getDocumentsPath();

  if (appDocumentsPath != null) {
    String filePath = '$appDocumentsPath/$fileNameCSV';
    File file = File(filePath);

    //OLD String csv = "time,attitude_roll,attitude_pitch,attitude_yaw,gravity_x,gravity_y,gravity_z,rotationRate_x,rotationRate_y,rotationRate_z,userAcceleration_x,userAcceleration_y,userAcceleration_z";
    String csv = "time,rotationRate_x,rotationRate_y,rotationRate_z,userAcceleration_x,userAcceleration_y,userAcceleration_z,orientation_roll,orientation_pitch,orientation_yaw,gravity_x,gravity_y,gravity_z";

    for(List<int> data in sensorData){
      csv += "\n";
      csv += data.join(', ');
    }
    file.writeAsString(csv);

    return null;
  }
}

List convertBleData2Int(List<int> dataList) {
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