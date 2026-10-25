import 'package:flutter/material.dart';

import '../platform/browser_platform.dart';

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
  Widget build(BuildContext context) => SizedBox(
    width: 280,
    height: 48,
    child: HtmlElementView.fromTagName(
      tagName: 'div',
      onElementCreated: (element) => BrowserPlatform.instance
          .renderGoogleButton(element, clientId, nonce, onCredential, onError),
    ),
  );
}
