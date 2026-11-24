import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Kartu untuk menampilkan FCM Token + tombol salin.
/// Otomatis memperbarui tampilan jika FCM Token berubah (onTokenRefresh).
class FcmTokenCard extends StatefulWidget {
  const FcmTokenCard({super.key});

  @override
  State<FcmTokenCard> createState() => _FcmTokenCardState();
}

class _FcmTokenCardState extends State<FcmTokenCard> {
  String? _token;
  bool _isLoading = true;
  StreamSubscription<String>? _tokenSubscription;

  @override
  void initState() {
    super.initState();
    _loadToken();

    // Dengarkan jika FCM Token berubah/di-refresh
    _tokenSubscription = FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      if (!mounted) return;
      setState(() {
        _token = newToken;
        _isLoading = false;
      });
    });
  }

  Future<void> _loadToken() async {
    final token = await FirebaseMessaging.instance.getToken();
    if (!mounted) return;
    setState(() {
      _token = token;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _tokenSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const CircularProgressIndicator();
    }

    final token = _token ?? 'Token tidak tersedia';

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'FCM Token:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SelectableText(token, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.copy),
              label: const Text('Salin Token'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: token));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Token disalin!')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}