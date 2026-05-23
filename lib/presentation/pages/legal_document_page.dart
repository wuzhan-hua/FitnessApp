import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../theme/app_theme.dart';

class LegalDocumentPage extends StatefulWidget {
  const LegalDocumentPage({
    super.key,
    required this.title,
    required this.url,
  });

  final String title;
  final String url;

  @override
  State<LegalDocumentPage> createState() => _LegalDocumentPageState();
}

class _LegalDocumentPageState extends State<LegalDocumentPage> {
  late final WebViewController _controller;

  bool _isLoading = true;
  bool _hasLoadError = false;
  String _errorMessage = '协议加载失败，请稍后重试。';

  @override
  void initState() {
    super.initState();
    _controller =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setNavigationDelegate(
            NavigationDelegate(
              onPageStarted: (_) {
                if (!mounted) return;
                setState(() {
                  _isLoading = true;
                  _hasLoadError = false;
                });
              },
              onPageFinished: (_) {
                if (!mounted) return;
                setState(() {
                  _isLoading = false;
                });
              },
              onWebResourceError: (error) {
                if (!mounted) return;
                setState(() {
                  _isLoading = false;
                  _hasLoadError = true;
                  _errorMessage = error.description.isNotEmpty
                      ? '协议加载失败：${error.description}'
                      : '协议加载失败，请稍后重试。';
                });
              },
            ),
          );
    _loadDocument();
  }

  Future<void> _loadDocument() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hasLoadError = false;
      _errorMessage = '协议加载失败，请稍后重试。';
    });
    await _controller.loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Stack(
        children: [
          Positioned.fill(
            child: Offstage(
              offstage: _hasLoadError,
              child: WebViewWidget(controller: _controller),
            ),
          ),
          if (_isLoading && !_hasLoadError)
            const Positioned.fill(
              child: ColoredBox(
                color: Colors.white,
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          if (_hasLoadError)
            Positioned.fill(
              child: ColoredBox(
                color: colors.background,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.wifi_tethering_error_rounded,
                          size: 36,
                          color: colors.warning,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          _errorMessage,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        FilledButton(
                          onPressed: _loadDocument,
                          child: const Text('重试'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
