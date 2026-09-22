import 'package:varnox_app/Model/ChatModel.dart';
import 'package:varnox_app/Screens/AuthScreen.dart';
import 'package:varnox_app/Screens/Homescreen.dart';
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

/// Chooses between the auth screen and the dashboard on launch.
///
/// A stored token is treated as a hint rather than proof: it is validated against
/// /auth/check-auth before the dashboard appears, so an expired or revoked session lands on the
/// sign-in screen instead of a dashboard whose every request would immediately 401.
///
/// Signing in goes straight to the dashboard. The original demo inserted a contact-picker screen
/// here (Screens/LoginScreen.dart) whose only job was to choose which fake identity you wanted to
/// be — it removed the chosen entry from a hardcoded list and pushed the dashboard with it. Real
/// accounts make that step meaningless, so it is no longer in the flow. The file is left in the
/// repository but is unreferenced.
class Root extends StatefulWidget {
  @override
  _RootState createState() => _RootState();
}

class _RootState extends State<Root> {
  bool checking = true;
  bool signedIn = false;
  Map user;

  @override
  void initState() {
    super.initState();
    restoreSession();
  }

  Future<void> restoreSession() async {
    bool valid = false;
    Map signedInUser;
    await Api.loadToken();
    if (Api.hasToken) {
      try {
        final data = await Api.checkAuth();
        signedInUser = data["user"] is Map ? data["user"] : data;
        valid = true;
      } catch (_) {
        // Expired or revoked. Falls through to the sign-in screen.
        valid = false;
      }
    }
    if (!mounted) return;
    setState(() {
      user = signedInUser;
      signedIn = valid;
      checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (checking) return splash();
    if (signedIn) {
      return Homescreen(
        chatmodels: placeholderChats(),
        sourchat: selfChat(user),
        user: user,
        onSignedOut: () => setState(() {
          user = null;
          signedIn = false;
        }),
      );
    }
    return AuthScreen(
      onSignedIn: (newUser) => setState(() {
        user = newUser is Map ? newUser : null;
        signedIn = true;
      }),
    );
  }

  /// The dashboard takes the signed-in account as `sourchat`, which is what outgoing messages are
  /// attributed to.
  ChatModel selfChat(Map account) {
    return ChatModel(
      name: displayName(account),
      icon: "person.svg",
      isGroup: false,
      time: "",
      currentMessage: "",
      status: "online",
      id: 0,
    );
  }

  String displayName(Map account) {
    if (account == null) return "You";
    final username = account["username"];
    if (username is String && username.isNotEmpty) return username;
    final email = account["email"];
    if (email is String && email.contains("@")) return email.split("@").first;
    return "You";
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

/// Placeholder conversations for the dashboard's chat list.
///
/// These are the four demo entries that used to live in Screens/LoginScreen.dart. The real list
/// is GET /conversations, already reachable from Services/api.dart — mapping a conversation
/// document (participants, lastMessage, timestamps) onto ChatModel is the next piece of work, and
/// until then the dashboard would otherwise open completely empty.
List<ChatModel> placeholderChats() {
  return [
    ChatModel(name: "Dev Stack", isGroup: false, currentMessage: "Hi Everyone", time: "4:00", icon: "person.svg", id: 1),
    ChatModel(name: "Kishor", isGroup: false, currentMessage: "Hi Kishor", time: "13:00", icon: "person.svg", id: 2),
    ChatModel(name: "Collins", isGroup: false, currentMessage: "Hi Dev Stack", time: "8:00", icon: "person.svg", id: 3),
    ChatModel(name: "Balram Rathore", isGroup: false, currentMessage: "Hi Dev Stack", time: "2:00", icon: "person.svg", id: 4),
  ];
}
