import 'package:flutter/material.dart';

import '../Services/api.dart';

/// The Status tab, WhatsApp-shaped and backed by the API.
///
///   GET  /statuses            -> every unexpired status, newest first, author populated
///   POST /statuses            -> { text, contentType: "text" } (media is left for later)
///   POST /statuses/:id/view   -> records that this account has seen it
///
/// Statuses expire 24 hours after creation, which the server sets; the list only ever contains
/// unexpired rows, so the client does not filter by time.
class StatusPage extends StatefulWidget {
  StatusPage({Key key, this.user}) : super(key: key);

  final Map user;

  @override
  _StatusPageState createState() => _StatusPageState();
}

class _StatusPageState extends State<StatusPage> {
  static const Color green = Color(0xFF128C7E);
  static const Color teal = Color(0xFF075E54);

  List statuses = [];
  bool loading = true;
  String error = "";

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (mounted) setState(() => error = "");
    try {
      final list = await Api.statuses();
      if (!mounted) return;
      setState(() {
        statuses = list;
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
        error = "Could not load status updates.";
        loading = false;
      });
    }
  }

  String get displayName {
    final account = widget.user;
    if (account == null) return "My status";
    final username = account["username"];
    if (username is String && username.isNotEmpty) return username;
    final email = account["email"];
    if (email is String && email.contains("@")) return email.split("@").first;
    return "My status";
  }

  String get myId {
    if (widget.user == null) return "";
    final value = widget.user["_id"];
    return value == null ? "" : value.toString();
  }

  String initialOf(String value) {
    if (value == null || value.isEmpty) return "?";
    return value.trim()[0].toUpperCase();
  }

  String authorName(dynamic status) {
    final author = status is Map ? status["author"] : null;
    if (author is Map && author["username"] is String && author["username"].isNotEmpty) {
      return author["username"];
    }
    if (author is Map && author["_id"] != null) return "Varnox user";
    return "Varnox user";
  }

  String ago(dynamic createdAt) {
    if (createdAt == null) return "";
    final when = DateTime.tryParse(createdAt.toString());
    if (when == null) return "";
    final difference = DateTime.now().difference(when.toLocal());
    if (difference.inMinutes < 1) return "Just now";
    if (difference.inMinutes < 60) return "${difference.inMinutes} minutes ago";
    if (difference.inHours < 24) return "${difference.inHours} hours ago";
    return "${difference.inDays} days ago";
  }

  /// viewers is [{ user: <id|populated>, viewedAt }]. The api populates nothing here, so the
  /// entry is usually a bare id string.
  bool viewedByMe(dynamic status) {
    if (myId.isEmpty || status is! Map) return false;
    final viewers = status["viewers"];
    if (viewers is! List) return false;
    for (final viewer in viewers) {
      if (viewer is! Map) continue;
      final user = viewer["user"];
      final idValue = user is Map ? user["_id"] : user;
      if (idValue != null && idValue.toString() == myId) return true;
    }
    return false;
  }

  Future<void> addStatus() async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text("New status"),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          maxLength: 700,
          decoration: InputDecoration(hintText: "Type a status update"),
        ),
        actions: [
          FlatButton(onPressed: () => Navigator.pop(dialogContext), child: Text("Cancel")),
          FlatButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: Text("POST", style: TextStyle(color: green, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (text == null || text.isEmpty) return;
    try {
      await Api.createStatus(text);
      await load();
      if (mounted) snack("Status posted. It disappears after 24 hours.");
    } on ApiException catch (e) {
      if (mounted) snack(e.message);
    } catch (_) {
      if (mounted) snack("Could not post the status. Check your connection.");
    }
  }

  Future<void> openStatus(dynamic status) async {
    final id = status is Map && status["_id"] != null ? status["_id"].toString() : null;
    if (id != null) {
      try {
        await Api.viewStatus(id);
      } catch (_) {
        // A failed view receipt should not stop the status from opening.
      }
    }
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _StatusViewer(
          status: status,
          name: authorName(status),
          initial: initialOf(authorName(status)),
        ),
      ),
    );
    load();
  }

  void snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        children: [
          if (error.isNotEmpty) errorBanner(),
          myStatusTile(),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              "RECENT UPDATES",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black45),
            ),
          ),
          if (loading)
            Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (statuses.isEmpty)
            emptyState()
          else
            ...statuses.map(statusTile),
          SizedBox(height: 24),
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

  Widget emptyState() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: Column(
        children: [
          Icon(Icons.public, size: 44, color: Colors.black26),
          SizedBox(height: 12),
          Text(
            "No status updates yet",
            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black54),
          ),
          SizedBox(height: 6),
          Text(
            "Tap \u201cMy status\u201d to post one. Updates from your contacts appear here and expire after 24 hours.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black38, fontSize: 12.5),
          ),
        ],
      ),
    );
  }

  Widget myStatusTile() {
    return InkWell(
      onTap: addStatus,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Stack(
              children: [
                _avatar(initialOf(displayName), 52, false),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    decoration: BoxDecoration(color: green, shape: BoxShape.circle),
                    padding: EdgeInsets.all(3),
                    child: Icon(Icons.add, size: 14, color: Colors.white),
                  ),
                ),
              ],
            ),
            SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("My status", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                SizedBox(height: 2),
                Text(
                  "Tap to add status update",
                  style: TextStyle(color: Colors.black45, fontSize: 12.5),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget statusTile(dynamic status) {
    final name = authorName(status);
    final seen = viewedByMe(status);
    final text = status is Map && status["text"] is String ? status["text"] : "";
    return InkWell(
      onTap: () => openStatus(status),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            _avatar(initialOf(name), 52, !seen),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  SizedBox(height: 2),
                  Text(
                    ago(status is Map ? status["createdAt"] : null),
                    style: TextStyle(color: Colors.black45, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            if (text.isNotEmpty)
              Icon(Icons.chevron_right, color: Colors.black26)
            else
              Icon(Icons.image, color: Colors.black26),
          ],
        ),
      ),
    );
  }

  /// An unviewed status gets the green ring, WhatsApp's unread marker.
  Widget _avatar(String initial, double size, bool ring) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: ring ? green.withOpacity(0.12) : Colors.black12,
        border: ring ? Border.all(color: green, width: 2) : null,
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: size * 0.36,
          fontWeight: FontWeight.bold,
          color: ring ? green : Colors.black54,
        ),
      ),
    );
  }
}

/// Full-screen status viewer: the update over a status-coloured background, tap anywhere to close.
class _StatusViewer extends StatelessWidget {
  _StatusViewer({Key key, this.status, this.name, this.initial}) : super(key: key);

  final dynamic status;
  final String name;
  final String initial;

  @override
  Widget build(BuildContext context) {
    final text = status is Map && status["text"] is String ? status["text"] : "";
    final posted = status is Map && status["createdAt"] != null
        ? DateTime.tryParse(status["createdAt"].toString())
        : null;
    final label = posted == null
        ? ""
        : "${posted.toLocal().hour.toString().padLeft(2, '0')}:${posted.toLocal().minute.toString().padLeft(2, '0')}";

    return Scaffold(
      backgroundColor: Color(0xFF0B141A),
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.all(12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: Color(0xFF128C7E),
                      child: Text(initial, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                          Text(label, style: TextStyle(color: Colors.white54, fontSize: 11)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 28),
                    child: text.isEmpty
                        ? Text(
                            "This status has no text.",
                            style: TextStyle(color: Colors.white70),
                          )
                        : Text(
                            text,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white, fontSize: 24, height: 1.4),
                          ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  "Tap anywhere to close",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white24, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
