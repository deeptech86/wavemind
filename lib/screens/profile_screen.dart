import 'package:flutter/material.dart';

import '../data/models/user_profile.dart';
import '../data/profile_api.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../widgets/back_header.dart';

/// Crew profile screen (Stage 4).
///
/// The only part of the app backed by a remote server: it reads and writes the
/// sailor's name / email / phone to the tiny FastAPI profile service (see
/// `backend/`). Everything else in TideWell stays on-device.
///
/// The network call is deliberately non-blocking for the rest of the app: if
/// the backend is unreachable, the screen surfaces a clear message and still
/// lets the user fill the form — it never crashes or hangs the experience.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, ProfileApi? api}) : _api = api;

  final ProfileApi? _api;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final ProfileApi _api = widget._api ?? ProfileApi();
  late final bool _ownsApi = widget._api == null;

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final profile = await _api.fetch();
      if (!mounted) return;
      if (profile != null) {
        _nameCtrl.text = profile.name;
        _emailCtrl.text = profile.email;
        _phoneCtrl.text = profile.phone;
      }
      setState(() => _loading = false);
    } on ProfileApiException catch (e) {
      if (!mounted) return;
      // Not fatal: let the user still fill in and attempt a save.
      setState(() {
        _loading = false;
        _loadError = e.message;
      });
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _api.save(
        UserProfile(
          name: _nameCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
        ),
      );
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('Crew details saved to the registry.')),
      );
    } on ProfileApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: AppColors.stormRed,
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    if (_ownsApi) _api.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: AppColors.appBackgroundGradient,
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BackHeader(title: 'Crew Profile'),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: _loading
                      ? const Padding(
                          padding: EdgeInsets.only(top: 48),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppColors.seafoam,
                            ),
                          ),
                        )
                      : Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'These few details are stored on the crew '
                                'registry. Everything else in TideWell stays '
                                'private on this device.',
                                style: AppTextStyles.bodySmall,
                              ),
                              if (_loadError != null) ...[
                                const SizedBox(height: 16),
                                _ErrorBanner(
                                  message: _loadError!,
                                  onRetry: _load,
                                ),
                              ],
                              const SizedBox(height: 24),
                              _Field(
                                label: 'Name',
                                controller: _nameCtrl,
                                hint: 'e.g. Marcus Thorne',
                                textInputAction: TextInputAction.next,
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                    ? 'Please enter a name.'
                                    : null,
                              ),
                              const SizedBox(height: 16),
                              _Field(
                                label: 'Email',
                                controller: _emailCtrl,
                                hint: 'e.g. marcus@example.com',
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                validator: _validateEmail,
                              ),
                              const SizedBox(height: 16),
                              _Field(
                                label: 'Phone',
                                controller: _phoneCtrl,
                                hint: 'e.g. +1 555 0100',
                                keyboardType: TextInputType.phone,
                                textInputAction: TextInputAction.done,
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                    ? 'Please enter a phone number.'
                                    : null,
                              ),
                              const SizedBox(height: 28),
                              _SaveButton(
                                saving: _saving,
                                onTap: _saving ? null : _save,
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String? _validateEmail(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return 'Please enter an email.';
    // Light client-side check; the backend validates authoritatively.
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
    return ok ? null : 'Please enter a valid email.';
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.textInputAction,
    this.validator,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: AppTextStyles.caption),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          validator: validator,
          cursorColor: AppColors.seafoam,
          style: AppTextStyles.body.copyWith(color: AppColors.white),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: AppColors.cardSurface,
            hintText: hint,
            hintStyle: AppTextStyles.body.copyWith(color: AppColors.muted),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusTile),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusTile),
              borderSide: const BorderSide(color: AppColors.glassBorderSoft),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusTile),
              borderSide: const BorderSide(color: AppColors.seafoam),
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.stormFaint,
        borderRadius: BorderRadius.circular(AppTheme.radiusTile),
        border: Border.all(color: AppColors.stormRed),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off, size: 18, color: AppColors.stormRed),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.caption.copyWith(color: AppColors.cream),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text(
              'Retry',
              style: AppTextStyles.bodyStrong.copyWith(
                color: AppColors.seafoam,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.saving, required this.onTap});

  final bool saving;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusButton),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            offset: Offset(0, 10),
            blurRadius: 12,
          ),
        ],
      ),
      child: Material(
        color: AppColors.seafoam,
        borderRadius: BorderRadius.circular(AppTheme.radiusButton),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusButton),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            child: Center(
              child: saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.onAccent,
                      ),
                    )
                  : Text(
                      'Save Crew Details',
                      style: AppTextStyles.buttonLarge.copyWith(
                        color: AppColors.onAccent,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
