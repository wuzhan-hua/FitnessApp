class LegalConstants {
  const LegalConstants._();

  // 上架前请替换为正式线上文档地址。
  static const String privacyPolicyUrl = '';
  static const String termsOfServiceUrl = '';

  static bool get hasPrivacyPolicyUrl => privacyPolicyUrl.trim().isNotEmpty;
  static bool get hasTermsOfServiceUrl => termsOfServiceUrl.trim().isNotEmpty;
}
