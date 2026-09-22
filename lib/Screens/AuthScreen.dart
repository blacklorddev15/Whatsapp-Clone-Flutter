import 'package:flutter/material.dart';

import '../Services/api.dart';

/// Sign-in, registration and email-code verification against the Varnox API.
///
/// The flow is the React client's flow, on the same endpoints:
///
///   1. Create account  -> POST /auth/register   (emails a 6-digit code through Resend)
///   2. Verify          -> POST /auth/verify-email  (returns the session token)
///   3. Sign in         -> POST /auth/login/email   (returns the session token)
///
/// "Resend code" is the same call as step 1: the API regenerates the code, stores the new expiry
/// and emails it again, which is why it does not need its own endpoint.
class AuthScreen extends StatefulWidget {
  AuthScreen({Key key, this.onSignedIn}) : super(key: key);

  /// Called with the user document returned by /auth/login/email or /auth/verify-email, so the
  /// dashboard can greet the account that just signed in without a second round trip.
  final Function onSignedIn;

  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  static const Color teal = Color(0xFF075E54);
  static const Color green = Color(0xFF128C7E);
  static const Color canvas = Color(0xFFECE5DD);

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController otpController = TextEditingController();

  bool busy = false;
  bool awaitingCode = false;
  String error = "";
  String notice = "";

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    otpController.dispose();
    super.dispose();
  }

  String get email => emailController.text.trim().toLowerCase();

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = "";
      notice = "";
    });
    try {
      await action();
    } on ApiException catch (e) {
      setState(() => error = e.message);
    } catch (e) {
      setState(() => error = "Could not reach the server. Check your connection and try again.");
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  bool validateCredentials() {
    if (email.isEmpty || !email.contains("@")) {
      setState(() => error = "Enter a valid email address.");
      return false;
    }
    if (passwordController.text.length < 6) {
      setState(() => error = "Password must be at least 6 characters.");
      return false;
    }
    return true;
  }

  Future<void> createAccount() => run(() async {
        if (!validateCredentials()) return;
        await Api.startEmailVerification(email, passwordController.text);
        setState(() {
          awaitingCode = true;
          notice = "We emailed a 6-digit code to $email.";
        });
      });

  Future<void> signIn() => run(() async {
        if (!validateCredentials()) return;
        final data = await Api.login(email, passwordController.text);
        widget.onSignedIn(data["user"]);
      });

  Future<void> verifyCode() => run(() async {
        final code = otpController.text.trim();
        if (code.length < 4) {
          setState(() => error = "Enter the code from the email.");
          return;
        }
        final data = await Api.verifyEmail(email, code);
        widget.onSignedIn(data["user"]);
      });

  Future<void> resendCode() => run(() async {
        await Api.startEmailVerification(email, passwordController.text);
        setState(() => notice = "A new code is on its way to $email.");
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: canvas,
      body: Column(
        children: [
          header(),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: awaitingCode ? codeStep() : credentialsStep(),
            ),
          ),
        ],
      ),
    );
  }

  Widget header() {
    return Container(
      width: double.infinity,
      color: teal,
      padding: EdgeInsets.fromLTRB(24, 48, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Varnox",
            style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 4),
          Text(
            awaitingCode ? "Verify your email" : "Sign in to continue",
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget card({List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))],
      ),
      padding: EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }

  InputDecoration fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Color(0xFFF7F7F7),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
    );
  }

  Widget banner(String text, Color color, IconData icon) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(color: color, fontSize: 13))),
        ],
      ),
    );
  }

  Widget primaryButton(String label, VoidCallback onPressed) {
    return SizedBox(
      height: 50,
      child: RaisedButton(
        color: green,
        disabledColor: green.withOpacity(0.5),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        onPressed: busy ? null : onPressed,
        child: busy
            ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
            : Text(label, style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
      ),
    );
  }

  Widget credentialsStep() {
    return card(children: [
      if (error.isNotEmpty) banner(error, Colors.red.shade700, Icons.error_outline),
      if (notice.isNotEmpty) banner(notice, green, Icons.mark_email_read_outlined),
      TextField(
        controller: emailController,
        keyboardType: TextInputType.emailAddress,
        autocorrect: false,
        decoration: fieldDecoration("Email"),
      ),
      SizedBox(height: 14),
      TextField(
        controller: passwordController,
        obscureText: true,
        decoration: fieldDecoration("Password"),
      ),
      SizedBox(height: 20),
      primaryButton("LOG IN", signIn),
      SizedBox(height: 10),
      FlatButton(
        onPressed: busy ? null : createAccount,
        child: Text("Create account", style: TextStyle(color: green, fontWeight: FontWeight.w600)),
      ),
      Text(
        "Creating an account emails you a 6-digit code to confirm your address. Codes are sent by Resend and expire after 5 minutes.",
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.black45, fontSize: 11.5),
      ),
    ]);
  }

  Widget codeStep() {
    return card(children: [
      if (error.isNotEmpty) banner(error, Colors.red.shade700, Icons.error_outline),
      if (notice.isNotEmpty) banner(notice, green, Icons.mark_email_read_outlined),
      TextField(
        controller: otpController,
        keyboardType: TextInputType.number,
        maxLength: 6,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 24, letterSpacing: 8),
        decoration: fieldDecoration("6-digit code").copyWith(counterText: ""),
      ),
      SizedBox(height: 16),
      primaryButton("VERIFY", verifyCode),
      SizedBox(height: 10),
      FlatButton(
        onPressed: busy ? null : resendCode,
        child: Text("Resend code", style: TextStyle(color: green, fontWeight: FontWeight.w600)),
      ),
      FlatButton(
        onPressed: busy
            ? null
            : () => setState(() {
                  awaitingCode = false;
                  otpController.clear();
                  notice = "";
                  error = "";
                }),
        child: Text("Use a different email", style: TextStyle(color: Colors.black54)),
      ),
    ]);
  }
}
