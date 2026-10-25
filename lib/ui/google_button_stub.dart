import 'package:flutter/material.dart';

class GoogleButton extends StatelessWidget {
  const GoogleButton({
    super.key,
    required this.clientId,
    required this.nonce,
    required this.onCredential,
    required this.onError,
  });
  final String clientId, nonce;
  final ValueChanged<String> onCredential, onError;
  @override
  Widget build(BuildContext context) =>
      const Text('Google sign-in is available in the browser.');
}
