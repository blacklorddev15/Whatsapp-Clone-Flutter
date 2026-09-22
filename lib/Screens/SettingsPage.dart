import 'package:flutter/material.dart';

import '../Services/api.dart';

/// Settings, WhatsApp-shaped, reading and writing real values.
///
///   GET   /privacy        -> { lastSeen, online, profilePhoto, about, status,
///                             readReceipts, typingIndicators, silenceUnknownCallers }
///   PATCH /privacy        -> same document, only the sent keys are applied
///   GET   /devices        -> linked sessions
///   POST  /auth/logout    -> clears the session
///
/// The PrivacySetting document is created on first read (the endpoint upserts), so a brand new
/// account already has defaults to show.
class SettingsPage extends StatefulWidget {
  SettingsPage({Key key, this.user, this.onSignedOut}) : super(key: key);

  final Map user;
  final Function onSignedOut;

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const Color green = Color(0xFF128C7E);

  static const List<String> audienceOptions = ["everyone", "contacts", "nobody"];

  Map privacy = {};
  List devices = [];
  bool loading = true;
  String error = "";
  bool signingOut = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (mounted) setState(() => error = "");
    try {
      final settings = await Api.privacy();
      List deviceList = [];
      try {
        deviceList = await Api.devices();
      } catch (_) {
        // A device list we cannot read should not hide the rest of the screen.
        deviceList = [];
      }
      if (!mounted) return;
      setState(() {
        privacy = settings;
        devices = deviceList;
        loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.message;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        error = "Could not load your settings.";
        loading = false;
      });
    }
  }

  String get displayName {
    final account = widget.user;
    if (account == null) return "Varnox user";
    final username = account["username"];
    if (username is String && username.isNotEmpty) return username;
    final email = account["email"];
    if (email is String && email.contains("@")) return email.split("@").first;
    return "Varnox user";
  }

  String get email {
    final account = widget.user;
    if (account == null || account["email"] is! String) return "";
    return account["email"];
  }

  bool flag(String key, bool fallback) {
    final value = privacy[key];
    return value is bool ? value : fallback;
  }

  String audience(String key) {
    final value = privacy[key];
    if (value is String && audienceOptions.contains(value)) return value;
    return "everyone";
  }

  void snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Applies the change locally first so the switch does not lag behind the tap, then persists it
  /// and rolls the value back if the server refuses.
  Future<void> setPrivacy(String key, dynamic value) async {
    final previous = privacy[key];
    setState(() => privacy[key] = value);
    try {
      final updated = await Api.updatePrivacy({key: value});
      if (mounted && updated.isNotEmpty) setState(() => privacy = updated);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => privacy[key] = previous);
      snack(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => privacy[key] = previous);
      snack("Could not save that change. Check your connection.");
    }
  }

  Future<void> signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text("Log out?"),
        content: Text(
          "You will need to sign in again with your email and password. Your chats stay on the server.",
        ),
        actions: [
          FlatButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text("CANCEL")),
          FlatButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text("LOG OUT", style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => signingOut = true);
    await Api.logout();
    if (!mounted) return;
    // Pop this route before flipping the root, otherwise the settings screen stays on top of the
    // sign-in screen.
    Navigator.pop(context);
    if (widget.onSignedOut != null) widget.onSignedOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFECE5DD),
      appBar: AppBar(
        title: Text("Settings"),
        backgroundColor: Color(0xFF075E54),
      ),
      body: loading
          ? Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                if (error.isNotEmpty) errorBanner(),
                profileCard(),
                sectionLabel("Privacy"),
                privacyCard(),
                sectionLabel("Linked devices"),
                devicesCard(),
                sectionLabel("Account"),
                accountCard(),
                sectionLabel("About"),
                aboutCard(),
                SizedBox(height: 28),
              ],
            ),
    );
  }

  Widget errorBanner() {
    return Container(
      color: Colors.red.shade50,
      padding: EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 18, color: Colors.red.shade700),
          SizedBox(width: 8),
          Expanded(child: Text(error, style: TextStyle(color: Colors.red.shade700, fontSize: 13))),
        ],
      ),
    );
  }

  Widget sectionLabel(String text) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 6),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black45, letterSpacing: 0.6),
      ),
    );
  }

  Widget card(List<Widget> children) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: children),
    );
  }

  Widget profileCard() {
    final initial = displayName.isEmpty ? "?" : displayName.trim()[0].toUpperCase();
    return card([
      Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: green,
              child: Text(
                initial,
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(displayName, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
                  SizedBox(height: 3),
                  Text(
                    email.isEmpty ? "Signed in" : email,
                    style: TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ]);
  }

  Widget privacyCard() {
    return card([
      SwitchListTile(
        value: flag("readReceipts", true),
        onChanged: (value) => setPrivacy("readReceipts", value),
        title: Text("Read receipts"),
        subtitle: Text(
          "If turned off, you will not send or receive read receipts. Read receipts are always sent for group chats.",
          style: TextStyle(fontSize: 12),
        ),
      ),
      Divider(height: 1),
      SwitchListTile(
        value: flag("typingIndicators", true),
        onChanged: (value) => setPrivacy("typingIndicators", value),
        title: Text("Typing indicators"),
        subtitle: Text("Show when you are typing.", style: TextStyle(fontSize: 12)),
      ),
      Divider(height: 1),
      SwitchListTile(
        value: flag("silenceUnknownCallers", false),
        onChanged: (value) => setPrivacy("silenceUnknownCallers", value),
        title: Text("Silence unknown callers"),
        subtitle: Text(
          "Calls from unknown contacts will not ring.",
          style: TextStyle(fontSize: 12),
        ),
      ),
      Divider(height: 1),
      Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Last seen", style: TextStyle(fontSize: 15)),
                  SizedBox(height: 2),
                  Text(
                    "Who can see when you were last online.",
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
            DropdownButton<String>(
              value: audience("lastSeen"),
              underline: SizedBox(),
              onChanged: (value) {
                if (value != null) setPrivacy("lastSeen", value);
              },
              items: audienceOptions
                  .map((option) => DropdownMenuItem<String>(
                        value: option,
                        child: Text(option, style: TextStyle(fontSize: 14, color: green)),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    ]);
  }

  Widget devicesCard() {
    final summary = devices.isEmpty
        ? "No other linked devices."
        : "${devices.length} linked device${devices.length == 1 ? "" : "s"}.";
    return card([
      ListTile(
        leading: Icon(Icons.devices, color: Colors.black45),
        title: Text("Linked devices"),
        subtitle: Text(summary),
      ),
    ]);
  }

  Widget accountCard() {
    return card([
      ListTile(
        leading: Icon(Icons.lock_outline, color: Colors.black45),
        title: Text("Account", style: TextStyle(fontSize: 15)),
        subtitle: Text(email.isEmpty ? "Signed in" : email, style: TextStyle(fontSize: 12)),
      ),
      Divider(height: 1),
      ListTile(
        leading: signingOut
            ? SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : Icon(Icons.logout, color: Colors.red.shade700),
        title: Text(
          signingOut ? "Signing out…" : "Log out",
          style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w600),
        ),
        onTap: signingOut ? null : signOut,
      ),
    ]);
  }

  Widget aboutCard() {
    return card([
      ListTile(
        leading: Icon(Icons.info_outline, color: Colors.black45),
        title: Text("Varnox App"),
        subtitle: Text("Flutter client, talking to varnox-api"),
      ),
    ]);
  }
}
