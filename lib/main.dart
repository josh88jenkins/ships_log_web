import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyAUZVaLEqd-mZtNZ9aDfDcd8MvjfhlYbjg",
      appId: "1:1059006950587:android:921e9ea17e38c461d08d9e",
      messagingSenderId: "1059006950587",
      projectId: "ships-log-6c13d",
    ),
  );
  runApp(WebViewerApp());
}

class WebViewerApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Ships Log Viewer",
      theme: ThemeData(primarySwatch: Colors.blue),
      home: AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasData) {
          return LogViewerScreen(user: snapshot.data!);
        }
        return LoginScreen();
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _errorMessage;

  Future<void> _login() async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
    } catch (e) {
      setState(() {
        _errorMessage = "Login failed: ${e.toString()}";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Login")),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: InputDecoration(labelText: "Email"),
            ),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(labelText: "Password"),
              obscureText: true,
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _login,
              child: Text("Login"),
            ),
            if (_errorMessage != null)
              Padding(
                padding: EdgeInsets.only(top: 16),
                child: Text(_errorMessage!, style: TextStyle(color: Colors.red)),
              ),
          ],
        ),
      ),
    );
  }
}

class LogViewerScreen extends StatelessWidget {
  final User user;

  LogViewerScreen({required this.user});

  Future<Map<String, dynamic>> _getUserData() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    return doc.data() ?? {};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Ships Log Viewer"),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _getUserData(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
          final userData = snapshot.data!;
          final role = userData['role'] ?? 'individual';
          final vesselId = userData['vessel_id'];

          return StreamBuilder<QuerySnapshot>(
            stream: role == 'company'
                ? FirebaseFirestore.instance.collection('logs').orderBy('time', descending: true).snapshots()
                : FirebaseFirestore.instance
                .collection('logs')
                .where('vessel_id', isEqualTo: vesselId)
                .orderBy('time', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
              final logs = snapshot.data!.docs;
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: [
                    DataColumn(label: Text("Date")),
                    DataColumn(label: Text("Time")),
                    DataColumn(label: Text("Latitude")),
                    DataColumn(label: Text("Longitude")),
                    DataColumn(label: Text("Course")),
                    DataColumn(label: Text("Speed")),
                    DataColumn(label: Text("Vessel ID")),
                  ],
                  rows: logs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return DataRow(cells: [
                      DataCell(Text(data['date'] ?? '')),
                      DataCell(Text(data['time'] ?? '')),
                      DataCell(Text(data['latitude']?.toString() ?? '')),
                      DataCell(Text(data['longitude']?.toString() ?? '')),
                      DataCell(Text(data['course'] ?? '')),
                      DataCell(Text(data['speed'] ?? '')),
                      DataCell(Text(data['vessel_id'] ?? '')),
                    ]);
                  }).toList(),
                ),
              );
            },
          );
        },
      ),
    );
  }
}