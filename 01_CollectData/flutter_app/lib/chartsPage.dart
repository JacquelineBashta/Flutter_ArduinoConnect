
import 'package:flutter/material.dart';
import 'package:flow_draw/chartData.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class ChartsPage extends StatefulWidget {
  @override
  State<ChartsPage> createState() => _ChartsPageState();
}

class _ChartsPageState extends State<ChartsPage> {

    ChartData _accXData = ChartData();
    ChartData _accYData = ChartData();
    ChartData _accZData = ChartData();

    @override
    void initState() {
      _accXData.fill();
      _accYData.fill();
      _accZData.fill();
      super.initState();
    }

    @override
    void dispose() {
      super.dispose();
    }

    _updateDataSource(){
      //if (_connected) {
        //_connected?_accXData.updateDataSource(data[0] ~/ gForce):print("Disconnected");
        //_connected?_accYData.updateDataSource(data[1] ~/ gForce):print("Disconnected");
        //_connected?_accZData.updateDataSource(data[2] ~/ gForce):print("Disconnected");
      //}
    }

    @override
    Widget build(BuildContext context) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
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
