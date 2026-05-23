class LegalConstants {
  const LegalConstants._();

  // 域名未定前保持为空，避免误跳转到伪正式地址。
  // 正式上线时请替换为实际可访问的法律页面链接。
  static const String privacyPolicyUrl = 'https://wzhua.indevs.in/privacy';
  static const String termsOfServiceUrl = 'https://wzhua.indevs.in/terms';

  static bool get hasPrivacyPolicyUrl => privacyPolicyUrl.trim().isNotEmpty;
  static bool get hasTermsOfServiceUrl => termsOfServiceUrl.trim().isNotEmpty;
}
