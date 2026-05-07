import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../application/providers/providers.dart';
import '../../application/state/auth_status.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_error.dart';
import '../../utils/snackbar_helper.dart';
import '../widgets/section_card.dart';

class PersonalInfoPage extends ConsumerStatefulWidget {
  const PersonalInfoPage({super.key});

  static const routeName = '/personal-info';

  @override
  ConsumerState<PersonalInfoPage> createState() => _PersonalInfoPageState();
}

class _PersonalInfoPageState extends ConsumerState<PersonalInfoPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _birthDateController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  String? _avatarUrl;
  XFile? _selectedAvatarFile;
  Uint8List? _selectedAvatarBytes;
  String? _gender;
  DateTime? _birthDate;
  String? _trainingGoal;
  String? _trainingYears;
  String? _activityLevel;
  bool _isLoading = true;
  bool _isSaving = false;

  static const _genders = ['男', '女', '其他', '不透露'];
  static const _goals = ['增肌', '减脂', '维持', '提升力量'];
  static const _years = ['<1年', '1-3年', '3-5年', '5年以上'];
  static const _activityLevels = ['久坐', '轻度活跃', '中度活跃', '高活跃'];
  static const _supportedAvatarExtensions = {'jpg', 'jpeg', 'png', 'webp'};
  static const _unsupportedAvatarExtensions = {'heic', 'heif'};

  @override
  void initState() {
    super.initState();
    _loadPersonalInfo();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _birthDateController.dispose();
    super.dispose();
  }

  void _applySettings() {
    final settings = ref.read(settingsProvider);
    _nameController.text = settings.profileName;
    _avatarUrl = settings.avatarUrl;
    _heightController.text = settings.heightCm?.toStringAsFixed(1) ?? '';
    _weightController.text = settings.weightKg?.toStringAsFixed(1) ?? '';
    _gender = settings.gender;
    _birthDate = settings.birthDate;
    _birthDateController.text = _birthDate == null
        ? ''
        : DateFormat('yyyy/MM/dd').format(_birthDate!);
    _trainingGoal = settings.trainingGoal;
    _trainingYears = settings.trainingYears;
    _activityLevel = settings.activityLevel;
  }

  Future<void> _loadPersonalInfo() async {
    try {
      await ref.read(settingsProvider.notifier).loadPersonalInfo();
      if (!mounted) {
        return;
      }
      setState(() {
        _applySettings();
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _applySettings();
        _isLoading = false;
      });
      showLatestSnackBar(
        context,
        AppError.from(error, fallbackMessage: '加载个人资料失败，请稍后重试。').message,
      );
    }
  }

  Future<void> _pickBirthDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(1998, 1, 1),
      firstDate: DateTime(1950, 1, 1),
      lastDate: DateTime.now(),
      locale: const Locale('zh', 'CN'),
      helpText: '选择生日',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (selected == null || !mounted) {
      return;
    }
    setState(() {
      _birthDate = selected;
      _birthDateController.text = DateFormat('yyyy/MM/dd').format(selected);
    });
  }

  Future<void> _pickAvatar() async {
    final authStatus =
        ref.read(authStatusProvider).valueOrNull ?? AuthStatus.signedOut;
    if (!authStatus.isSignedIn || authStatus.isGuest) {
      showLatestSnackBar(context, '请先登录正式账号后再上传头像');
      return;
    }

    try {
      final file = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1080,
      );
      if (file == null || !mounted) {
        return;
      }
      final validationError = _validateAvatarFile(file);
      if (validationError != null) {
        showLatestSnackBar(context, validationError);
        return;
      }
      final bytes = await file.readAsBytes();
      setState(() {
        _selectedAvatarFile = file;
        _selectedAvatarBytes = bytes;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      showLatestSnackBar(
        context,
        AppError.from(error, fallbackMessage: '选择头像失败，请稍后重试。').message,
      );
    }
  }

  String? _validateAvatarFile(XFile file) {
    final name = file.name.trim().toLowerCase();
    final dotIndex = name.lastIndexOf('.');
    if (dotIndex < 0 || dotIndex >= name.length - 1) {
      return '当前仅支持 JPG、PNG、WebP，请先转换后再上传。';
    }

    final extension = name.substring(dotIndex + 1);
    if (_supportedAvatarExtensions.contains(extension)) {
      final mimeType = file.mimeType?.toLowerCase().trim();
      if (mimeType == null || mimeType.isEmpty) {
        return null;
      }
      if (mimeType == 'image/jpeg' ||
          mimeType == 'image/png' ||
          mimeType == 'image/webp') {
        return null;
      }
      return '当前仅支持 JPG、PNG、WebP，请先转换后再上传。';
    }

    if (_unsupportedAvatarExtensions.contains(extension)) {
      return '当前仅支持 JPG、PNG、WebP，请先转换后再上传。';
    }

    return '当前仅支持 JPG、PNG、WebP，请先转换后再上传。';
  }

  Future<void> _save() async {
    if (_isSaving || !_formKey.currentState!.validate()) {
      return;
    }
    final height = double.tryParse(_heightController.text.trim());
    final weight = double.tryParse(_weightController.text.trim());
    setState(() => _isSaving = true);
    try {
      var nextAvatarUrl = _avatarUrl;
      if (_selectedAvatarFile != null) {
        final validationError = _validateAvatarFile(_selectedAvatarFile!);
        if (validationError != null) {
          throw AppError(
            message: validationError,
            code: 'unsupported_avatar_format',
          );
        }
        final bytes =
            _selectedAvatarBytes ?? await _selectedAvatarFile!.readAsBytes();
        nextAvatarUrl = await ref
            .read(settingsProvider.notifier)
            .uploadAvatar(bytes: bytes, fileName: _selectedAvatarFile!.name);
      }
      await ref
          .read(settingsProvider.notifier)
          .updatePersonalInfo(
            profileName: _nameController.text.trim(),
            avatarUrl: nextAvatarUrl,
            gender: _gender,
            birthDate: _birthDate,
            heightCm: height,
            weightKg: weight,
            trainingGoal: _trainingGoal,
            trainingYears: _trainingYears,
            activityLevel: _activityLevel,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _avatarUrl = nextAvatarUrl;
        _selectedAvatarFile = null;
        _selectedAvatarBytes = null;
      });
      showLatestSnackBar(context, '个人信息已保存');
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) {
        return;
      }
      showLatestSnackBar(
        context,
        AppError.from(error, fallbackMessage: '保存个人资料失败，请稍后重试。').message,
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  InputDecoration _inputDecoration(String label) {
    final colors = AppColors.of(context);
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.82),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colors.textMuted.withValues(alpha: 0.35)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colors.textMuted.withValues(alpha: 0.35)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colors.accent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colors.warning.withValues(alpha: 0.9)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colors.warning, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('个人信息')),
      body: SafeArea(child: _buildBody(context, colors)),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: FilledButton.icon(
          onPressed: _isLoading || _isSaving ? null : _save,
          icon: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save),
          label: Text(_isSaving ? '保存中...' : '保存个人信息'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, AppPalette colors) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: colors.panelAlt,
              borderRadius: AppRadius.card,
              border: Border.all(color: colors.accent.withValues(alpha: 0.24)),
            ),
            child: Row(
              children: [
                Icon(Icons.tune_rounded, color: colors.accent, size: 20),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    '完善资料以获得更精准训练建议',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SectionCard(
            title: '基础信息',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '用于完善你的基础档案',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
                ),
                const SizedBox(height: AppSpacing.sm),
                _AvatarEditor(
                  imageFile: _selectedAvatarFile,
                  imageBytes: _selectedAvatarBytes,
                  avatarUrl: _avatarUrl,
                  displayName: _nameController.text.trim(),
                  onTap: _isSaving ? null : _pickAvatar,
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _nameController,
                  onChanged: (_) => setState(() {}),
                  decoration: _inputDecoration(
                    '昵称*',
                  ).copyWith(hintText: '请输入昵称'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '请输入昵称';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                _ChoiceField(
                  label: '性别',
                  options: _genders,
                  value: _gender,
                  onChanged: (value) => setState(() => _gender = value),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _birthDateController,
                  readOnly: true,
                  onTap: _pickBirthDate,
                  decoration: _inputDecoration('生日').copyWith(
                    hintText: '点击选择生日',
                    suffixIcon: Container(
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colors.panelAlt,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: colors.textMuted.withValues(alpha: 0.28),
                        ),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.event, size: 18),
                        onPressed: _pickBirthDate,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SectionCard(
            title: '体征信息',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '用于训练负荷和消耗估算',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _heightController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: _inputDecoration('身高(cm)'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return null;
                    }
                    final parsed = double.tryParse(value.trim());
                    if (parsed == null || parsed <= 0) {
                      return '请输入有效身高';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _weightController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: _inputDecoration('体重(kg)'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return null;
                    }
                    final parsed = double.tryParse(value.trim());
                    if (parsed == null || parsed <= 0) {
                      return '请输入有效体重';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          SectionCard(
            title: '训练背景',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '帮助系统给出更合适的训练建议',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
                ),
                const SizedBox(height: AppSpacing.sm),
                _ChoiceField(
                  label: '训练目标',
                  options: _goals,
                  value: _trainingGoal,
                  onChanged: (value) => setState(() => _trainingGoal = value),
                ),
                const SizedBox(height: AppSpacing.sm),
                _ChoiceField(
                  label: '训练年限',
                  options: _years,
                  value: _trainingYears,
                  onChanged: (value) => setState(() => _trainingYears = value),
                ),
                const SizedBox(height: AppSpacing.sm),
                _ChoiceField(
                  label: '活动水平',
                  options: _activityLevels,
                  value: _activityLevel,
                  onChanged: (value) => setState(() => _activityLevel = value),
                ),
              ],
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _AvatarEditor extends StatelessWidget {
  const _AvatarEditor({
    required this.imageFile,
    required this.imageBytes,
    required this.avatarUrl,
    required this.displayName,
    required this.onTap,
  });

  final XFile? imageFile;
  final Uint8List? imageBytes;
  final String? avatarUrl;
  final String displayName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final hasPreview =
        imageFile != null ||
        (avatarUrl != null && avatarUrl!.trim().isNotEmpty);

    ImageProvider? preview;
    if (imageBytes != null) {
      preview = MemoryImage(imageBytes!);
    } else if (avatarUrl != null && avatarUrl!.trim().isNotEmpty) {
      preview = NetworkImage(avatarUrl!.trim());
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.panelAlt,
        borderRadius: AppRadius.card,
        border: Border.all(color: colors.textMuted.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: colors.accent.withValues(alpha: 0.16),
            backgroundImage: preview,
            child: hasPreview
                ? null
                : Text(
                    displayName.isEmpty ? '我' : displayName.substring(0, 1),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: colors.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '头像',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasPreview ? '保存后会同步到“我的”页顶部卡片' : '未设置头像，将使用昵称首字母',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
                ),
              ],
            ),
          ),
          FilledButton.tonalIcon(
            onPressed: onTap,
            icon: const Icon(Icons.photo_library_outlined),
            label: Text(hasPreview ? '更换头像' : '选择头像'),
          ),
        ],
      ),
    );
  }
}

class _ChoiceField extends StatelessWidget {
  const _ChoiceField({
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final List<String> options;
  final String? value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: options.map((item) {
            final selected = item == value;
            return ChoiceChip(
              label: Text(item),
              selected: selected,
              onSelected: (_) => onChanged(item),
              visualDensity: const VisualDensity(horizontal: -1, vertical: -1),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              side: BorderSide(
                color: selected
                    ? colors.accent.withValues(alpha: 0.60)
                    : colors.textMuted.withValues(alpha: 0.20),
                width: selected ? 1.4 : 1.2,
              ),
              backgroundColor: Color.lerp(colors.panelAlt, colors.panel, 0.12),
              selectedColor: colors.accent.withValues(alpha: 0.28),
              labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                fontSize: 14,
                color: selected ? colors.textPrimary : colors.textMuted,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
