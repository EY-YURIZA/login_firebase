import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// untuk menampilkan dan menyalin FCM Token .
class FcmTokenCard extends StatefulWidget {
  const FcmTokenCard({super.key});

  @override
  State<FcmTokenCard> createState() => _FcmTokenCardState();
}

class _FcmTokenCardState extends State<FcmTokenCard> {
  String? _token;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadToken();

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      if (!mounted) return;
      setState(() {
        _token = newToken;
      });
    });
  }

  Future<void> _loadToken() async {
    setState(() => _isLoading = true);
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (!mounted) return;
      setState(() {
        _token = token;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _token = null;
        _isLoading = false;
      });
    }
  }

  Future<void> _copyToken() async {
    if (_token == null || _token!.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _token!));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('FCM Token berhasil disalin ke clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.vpn_key, color: Colors.orange),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'FCM Device Token',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Muat ulang token',
                  onPressed: _isLoading ? null : _loadToken,
                  icon: const Icon(Icons.refresh, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12.0),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_token == null || _token!.isEmpty)
              const Text(
                'Token belum tersedia. Pastikan koneksi internet aktif lalu tekan refresh.',
                style: TextStyle(color: Colors.redAccent, fontSize: 13),
              )
            else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: SelectableText(
                  _token!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _copyToken,
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Salin FCM Token'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}