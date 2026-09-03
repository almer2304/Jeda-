import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class EducationScreen extends StatefulWidget {
  const EducationScreen({super.key});

  @override
  State<EducationScreen> createState() => _EducationScreenState();
}

class _EducationScreenState extends State<EducationScreen> {
  double _progress = 0;
  late InAppWebViewController _webViewController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      body: SafeArea(
        child: Column(
          children: [
            if (_progress < 1.0)
              LinearProgressIndicator(
                value: _progress,
                backgroundColor: const Color(0xFFF5F0E8),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF87A878)),
              ),
            Expanded(
              child: InAppWebView(
                initialUrlRequest: URLRequest(
                  url: WebUri("file:///android_asset/flutter_assets/assets/education/index.html"),
                ),
                initialSettings: InAppWebViewSettings(
                  transparentBackground: true,
                  disableHorizontalScroll: true,
                  disableVerticalScroll: false,
                  allowFileAccess: true,
                ),
                onWebViewCreated: (controller) {
                  _webViewController = controller;
                },
                onProgressChanged: (controller, progress) {
                  setState(() {
                    _progress = progress / 100;
                  });
                },
                shouldOverrideUrlLoading: (controller, navigationAction) async {
                  final uri = navigationAction.request.url;
                  // Allow local assets
                  if (uri != null && uri.scheme == 'file') {
                    return NavigationActionPolicy.ALLOW;
                  }
                  // Block external navigation to keep them inside the app environment
                  return NavigationActionPolicy.CANCEL;
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
