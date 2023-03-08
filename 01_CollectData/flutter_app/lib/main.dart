
import 'package:flutter/material.dart';
import 'package:flow_draw/blePage.dart';
import 'package:flow_draw/chartsPage.dart';

void main() {
  runApp(MaterialApp(
    title: 'Flow Draw',
    theme: ThemeData(
      useMaterial3: true,
    ),
    home: const MyHomePage(),
  ),
  );
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  var selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    Widget page;
    switch (selectedIndex) {
      case 0:
        page = BluetoothPage();
        break;
      case 1:
        //page = ChartsPage();
        page = BluetoothPage();
        break;
      default:
        throw UnimplementedError('no widget for $selectedIndex');
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Scaffold(
          appBar: AppBar(
            title: Text("Flow Draw"),
            centerTitle: true,
            backgroundColor: Colors.orangeAccent[100],
          ),
          body: Row(
            children: [
              SafeArea(
                child: NavigationRail(
                  extended: constraints.maxWidth >= 1200,
                  backgroundColor: Colors.orangeAccent[100],
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.bluetooth),
                      label: Text('Bluetooth'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.smart_toy),
                      label: Text('Charts'),
                    ),

                  ],
                  selectedIndex: selectedIndex,
                  onDestinationSelected: (value) {
                    setState(() {
                      selectedIndex = value;
                    });
                  },
                ),
              ),
              Expanded(
                child: Container(
                  child: page,
                ),
              ),
            ],
          ),
        );
      }
    );
  }
}
