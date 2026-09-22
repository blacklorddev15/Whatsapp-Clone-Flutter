import 'package:varnox_app/Screens/AuthScreen.dart';
import 'package:varnox_app/Screens/LoginScreen.dart';
import 'package:varnox_app/Services/api.dart';
import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // The camera plugin has no web implementation, so enumerating devices here threw before
  // runApp and the web build rendered a blank page. Nothing needs the device list at startup
  // now that the camera screen is outside the web build — see Homescreen for the tab.
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
          fontFamily: "OpenSans",
          primaryColor: Color(0xFF075E54),
          accentColor: Color(0xFF128C7E)),
      home: Root(),
    );
  }
}

/// Chooses between the sign-in screen and the chat list on launch.
///
/// A stored token is treated as a hint rather than proof: it is validated against
/// /auth/check-auth before the chat list appears, so an expired or revoked session lands on the
/// sign-in screen instead of a screen whose every request would immediately 401.
class Root extends StatefulWidget {
  @override
  _RootState createState() => _RootState();
}

class _RootState extends State<Root> {
  bool checking = true;
  bool signedIn = false;

  @override
  void initState() {
    super.initState();
    restoreSession();
  }

  Future<void> restoreSession() async {
    bool valid = false;
    await Api.loadToken();
    if (Api.hasToken) {
      try {
        await Api.checkAuth();
        valid = true;
      } catch (_) {
        // Expired or revoked. Falls through to the sign-in screen.
        valid = false;
      }
    }
    if (!mounted) return;
    setState(() {
      signedIn = valid;
      checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (checking) return splash();
    if (signedIn) return LoginScreen();
    return AuthScreen(onSignedIn: () => setState(() => signedIn = true));
  }

  Widget splash() {
    return Scaffold(
      backgroundColor: Color(0xFF075E54),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Varnox",
              style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 22),
            SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
