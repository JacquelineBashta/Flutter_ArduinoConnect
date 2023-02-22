import 'package:syncfusion_flutter_charts/charts.dart';

class BaseData {
  BaseData(this.time, this.value);
  final int time;
  final num value;
}

class ChartData {
  ChartData();

  int count = 49;
  bool readyFlag = false;
  ChartSeriesController? chartSeriesController;
  List<BaseData> baseDataList = [];

  void fill(){
    for( var i = 1 ; i <= count; i++ ) {
      baseDataList.add(BaseData(i, 0)) ;
    }
    readyFlag =true;
  }

  void updateDataSource(int val) {
    baseDataList.add(BaseData(count, val));
    if (baseDataList.length == 50) {
      // Removes the last index data of data source.
      baseDataList.removeAt(0);
      // Here calling updateDataSource method with addedDataIndexes
      // to add data in last index and removedDataIndexes to remove data from the last.
      chartSeriesController?.updateDataSource(addedDataIndexes: <int>[baseDataList.length -1],
          removedDataIndexes: <int>[0]);
    }
    count = count + 1;
  }
}