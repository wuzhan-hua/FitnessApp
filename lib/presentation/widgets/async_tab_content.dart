import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import '../../utils/snackbar_helper.dart';

class AsyncTabContent<T> extends StatefulWidget {
  const AsyncTabContent({
    super.key,
    required this.asyncValue,
    required this.builder,
    this.errorPrefix = '加载失败',
  });

  final AsyncValue<T> asyncValue;
  final Widget Function(BuildContext context, T data) builder;
  final String errorPrefix;

  @override
  State<AsyncTabContent<T>> createState() => _AsyncTabContentState<T>();
}

class _AsyncTabContentState<T> extends State<AsyncTabContent<T>> {
  T? _lastData;
  String? _lastErrorMessage;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final currentData = widget.asyncValue.valueOrNull;
    if (currentData != null) {
      _lastData = currentData;
      _lastErrorMessage = null;
    }

    final hasCache = _lastData != null;
    final hasError = widget.asyncValue.hasError;
    final isLoading = widget.asyncValue.isLoading;
    final errorText = hasError
        ? '${widget.errorPrefix}: ${widget.asyncValue.error}'
        : null;

    if (hasError &&
        hasCache &&
        errorText != null &&
        errorText != _lastErrorMessage) {
      _lastErrorMessage = errorText;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        showLatestSnackBar(context, errorText);
      });
    }

    Widget content;
    if (currentData != null) {
      content = widget.builder(context, currentData);
    } else if (hasCache) {
      content = widget.builder(context, _lastData as T);
    } else if (hasError) {
      content = Center(child: Text(errorText ?? '加载失败'));
    } else {
      content = const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        Positioned.fill(child: content),
        if (isLoading && hasCache)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
              minHeight: 2,
              backgroundColor: colors.panelAlt,
            ),
          ),
      ],
    );
  }
}
