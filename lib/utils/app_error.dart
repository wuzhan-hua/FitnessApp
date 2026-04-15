class AppError implements Exception {
  const AppError({required this.message, this.code, this.details});

  final String message;
  final String? code;
  final Object? details;

  factory AppError.from(Object error, {String? fallbackMessage}) {
    if (error is AppError) {
      return error;
    }
    return AppError(
      message: fallbackMessage ?? '发生未知错误，请稍后重试。',
      details: error,
    );
  }

  @override
  String toString() => message;
}
