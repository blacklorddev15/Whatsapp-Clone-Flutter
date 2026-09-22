import 'package:varnox_app/Screens/Homescreen.dart';
import 'package:varnox_app/Screens/LoginScreen.dart';
import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // The camera plugin has no web implementation, so enumerating devices here threw before
  // runApp and the web build rendered a blank page. Nothing needs the device list at startup
  // now that the camera screen is outside the web build — see Homescreen for the tab.
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
          fontFamily: "OpenSans",
          primaryColor: Color(0xFF075E54),
          accentColor: Color(0xFF128C7E)),
      home: LoginScreen(),
    );
  }
}
