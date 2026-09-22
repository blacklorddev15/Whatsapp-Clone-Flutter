import 'package:varnox_app/Model/ChatModel.dart';
import 'package:varnox_app/Pages/ChatPage.dart';
import 'package:varnox_app/Screens/SettingsPage.dart';
import 'package:varnox_app/Screens/StatusPage.dart';
import 'package:flutter/material.dart';

class Homescreen extends StatefulWidget {
  Homescreen({Key key, this.chatmodels, this.sourchat, this.user, this.onSignedOut})
      : super(key: key);
  final List<ChatModel> chatmodels;
  final ChatModel sourchat;

  /// The authenticated account, handed to the Status and Settings screens.
  final Map user;

  /// Called after the account signs out, so the root can return to the sign-in screen.
  final Function onSignedOut;

  @override
  _HomescreenState createState() => _HomescreenState();
}

class _HomescreenState extends State<Homescreen>
    with SingleTickerProviderStateMixin {
  TabController _controller;
  @override
  void initState() {
    super.initState();
    _controller = TabController(length: 4, vsync: this, initialIndex: 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Varnox"),
        actions: [
          IconButton(icon: Icon(Icons.search), onPressed: () {}),
          PopupMenuButton<String>(
            onSelected: openMenu,
            itemBuilder: (BuildContext contesxt) {
              return [
                PopupMenuItem(
                  child: Text("New group"),
                  value: "New group",
                ),
                PopupMenuItem(
                  child: Text("New broadcast"),
                  value: "New broadcast",
                ),
                PopupMenuItem(
                  child: Text("Starred messages"),
                  value: "Starred messages",
                ),
                PopupMenuItem(
                  child: Text("Settings"),
                  value: "Settings",
                ),
              ];
            },
          )
        ],
        bottom: TabBar(
          controller: _controller,
          indicatorColor: Colors.white,
          tabs: [
            Tab(
              icon: Icon(Icons.camera_alt),
            ),
            Tab(
              text: "CHATS",
            ),
            Tab(
              text: "STATUS",
            ),
            Tab(
              text: "CALLS",
            )
          ],
        ),
      ),
      body: TabBarView(
        controller: _controller,
        children: [
          _CameraTabUnavailable(),
          ChatPage(
            chatmodels: widget.chatmodels,
            sourchat: widget.sourchat,
          ),
          StatusPage(user: widget.user),
          _CallsTabUnavailable(),
        ],
      ),
    );
  }

  void openMenu(String value) {
    if (value == "Settings") {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SettingsPage(user: widget.user, onSignedOut: widget.onSignedOut),
        ),
      );
      return;
    }
    // The remaining entries have no endpoint behind them yet. Saying so beats the previous
    // behaviour, which was to print the label to the console and do nothing.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("$value is not implemented yet.")),
    );
  }
}

/// Placeholder for the Calls tab.
///
/// The API has no call-history endpoint — the React client keeps its call log in browser storage —
/// so there is nothing to read here yet. Call signalling does exist over the socket, which is a
/// separate piece of work.
class _CallsTabUnavailable extends StatelessWidget {
  const _CallsTabUnavailable();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.call, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text("No calls yet", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
            SizedBox(height: 6),
            Text(
              "Call history is not stored by the API yet, so this tab stays empty.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }
}

/// Placeholder for the camera tab.
///
/// The real tab is Pages/CameraPage.dart -> Screens/CameraScreen.dart, which pulls in
/// Screens/CameraView.dart and Screens/VideoView.dart. Both of those import dart:io and use
/// File(), and dart:io cannot be compiled for web — referencing them at all fails the web
/// build. They are left untouched in the repository; this tab simply does not import them, so
/// a web build never reaches dart:io. Restore CameraPage() here for mobile builds.
class _CameraTabUnavailable extends StatelessWidget {
  const _CameraTabUnavailable();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.camera_alt, size: 48, color: Colors.grey),
          SizedBox(height: 12),
          Text(
            "Camera is not available in this build",
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
