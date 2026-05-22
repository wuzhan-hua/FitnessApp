import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import '../../utils/app_error.dart';
import '../../utils/snackbar_helper.dart';

class AsyncTabContent<T> extends StatefulWidget {
  const AsyncTabContent({
    super.key,
    required this.asyncValue,
    required this.builder,
    this.errorPrefix = '加载失败',
    this.cacheKey,
  });

  final AsyncValue<T> asyncValue;
  final Widget Function(BuildContext context, T data) builder;
  final String errorPrefix;
  final Object? cacheKey;

  @override
  State<AsyncTabContent<T>> createState() => _AsyncTabContentState<T>();
}

class _AsyncTabContentState<T> extends State<AsyncTabContent<T>> {
  T? _lastData;
  Object? _lastCacheKey;
  String? _lastErrorMessage;

  @override
  void didUpdateWidget(covariant AsyncTabContent<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cacheKey != widget.cacheKey) {
      _lastData = null;
      _lastCacheKey = widget.cacheKey;
      _lastErrorMessage = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final currentData = widget.asyncValue.valueOrNull;
    if (_lastCacheKey != widget.cacheKey) {
      _lastData = null;
      _lastCacheKey = widget.cacheKey;
      _lastErrorMessage = null;
    }
    if (currentData != null) {
      _lastData = currentData;
      _lastErrorMessage = null;
    }

    final hasCache = _lastData != null;
    final hasError = widget.asyncValue.hasError;
    final isLoading = widget.asyncValue.isLoading;
    final isAuthRequiredError =
        widget.asyncValue.error is AppError &&
        (widget.asyncValue.error as AppError).code == 'auth_required';
    final errorText = hasError
        ? '${widget.errorPrefix}: ${widget.asyncValue.error}'
        : null;

    if (hasError &&
        hasCache &&
        !isAuthRequiredError &&
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
