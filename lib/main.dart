import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import './handlers/cookies_management.dart'; // Import your CookiesManagment class here

Future<void> main() async {
  // Load environment variables from .env file
  await dotenv.load(fileName: ".env");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cookie Encryption Demo',
      theme: ThemeData(primarySwatch: Colors.deepPurple),
      home: const HomeScreen(),
      routes: {
        '/set': (context) => const SetCookieScreen(),
        '/read': (context) => const ReadCookieScreen(),
      },
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cookie Demo Home')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/set'),
              child: const Text('Set Cookies'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/read'),
              child: const Text('Read Cookies'),
            ),
          ],
        ),
      ),
    );
  }
}

class SetCookieScreen extends StatelessWidget {
  const SetCookieScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set Cookies')),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            CookiesManagement.encryptAndSetCookie('access_token', 'my_access_token_123');
            CookiesManagement.encryptAndSetCookie('refresh_token', 'my_refresh_token_456');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Cookies Set Successfully')),
            );
          },
          child: const Text('Set Encrypted Cookies'),
        ),
      ),
    );
  }
}

class ReadCookieScreen extends StatefulWidget {
  const ReadCookieScreen({super.key});

  @override
  State<ReadCookieScreen> createState() => _ReadCookieScreenState();
}

class _ReadCookieScreenState extends State<ReadCookieScreen> {
  String accessToken = '';
  String refreshToken = '';

  void _loadCookies() {
  setState(() {
    accessToken = CookiesManagement.decryptAndGetCookie('access_token');
    refreshToken = CookiesManagement.decryptAndGetCookie('refresh_token');
  });

  debugPrint('Access Token read from cookie: $accessToken');
  debugPrint('Refresh Token read from cookie: $refreshToken');
}


  @override
  void initState() {
    super.initState();
    _loadCookies();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Read Cookies')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Access Token: $accessToken'),
            const SizedBox(height: 16),
            Text('Refresh Token: $refreshToken'),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _loadCookies,
              child: const Text('Reload Cookies'),
            ),
          ],
        ),
      ),
    );
  }
}
