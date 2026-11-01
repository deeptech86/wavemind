import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/app_assets.dart';
import '../data/auth_api.dart';
import '../data/auth_token_storage.dart';
import '../data/profile_photo_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../widgets/auth_form.dart';
import '../widgets/back_header.dart';
import 'welcome_screen.dart';

/// Crew profile screen.
///
/// Backed by the real accounts system: it reads the signed-in sailor's account
/// from `GET /auth/me` and saves edits to the editable fields (name / age /
/// sex / fleet name) via `PATCH /auth/me`. Email and password aren't editable
/// here — changing those needs a re-verification flow that's out of scope.
///
/// The network call is deliberately non-blocking: if the backend is
/// unreachable the screen surfaces a clear, retry-able message rather than
/// crashing or hanging. A Logout action clears the stored session token and
/// returns to the Welcome screen.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    AuthApi? api,
    AuthTokenStorage? tokenStorage,
    ProfilePhotoService? photoService,
  }) : _api = api,
       _tokenStorage = tokenStorage,
       _photoService = photoService;

  final AuthApi? _api;
  final AuthTokenStorage? _tokenStorage;

  /// Optional injection point for tests.
  final ProfilePhotoService? _photoService;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final AuthApi _api = widget._api ?? AuthApi();
  late final bool _ownsApi = widget._api == null;
  late final AuthTokenStorage _tokenStorage =
      widget._tokenStorage ?? AuthTokenStorage();
  late final ProfilePhotoService _photoService =
      widget._photoService ?? ProfilePhotoService();

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _sexCtrl = TextEditingController();
  final _fleetCtrl = TextEditingController();

  String _email = '';
  bool _loading = true;
  bool _saving = false;
  bool _loggingOut = false;
  String? _loadError;

  File? _photo;
  bool _pickingPhoto = false;

  @override
  void initState() {
    super.initState();
    _load();
    _loadPhoto();
  }

  Future<void> _loadPhoto() async {
    final photo = await _photoService.currentPhoto();
    if (!mounted) return;
    setState(() => _photo = photo);
  }

  Future<void> _pickPhoto() async {
    if (_pickingPhoto) return;
    setState(() => _pickingPhoto = true);
    try {
      final photo = await _photoService.pickFromGallery();
      if (!mounted) return;
      if (photo != null) setState(() => _photo = photo);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open your photo library. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _pickingPhoto = false);
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    final token = await _tokenStorage.read();
    if (token == null || token.isEmpty) {
      // No session — shouldn't happen behind the auth gate, but handle it by
      // bouncing back to Welcome rather than showing an empty form.
      if (mounted) _returnToWelcome();
      return;
    }
    try {
      final account = await _api.me(token);
      if (!mounted) return;
      _nameCtrl.text = account.name;
      _ageCtrl.text = account.age.toString();
      _sexCtrl.text = account.sex;
      _fleetCtrl.text = account.fleetName ?? '';
      setState(() {
        _email = account.email;
        _loading = false;
      });
    } on AuthApiException catch (e) {
      if (!mounted) return;
      if (e.isAuthFailure) {
        // Stale/expired token — clear it and return to Welcome.
        await _tokenStorage.clear();
        if (mounted) _returnToWelcome();
        return;
      }
      // Transport failure: not fatal — surface a retry-able banner.
      setState(() {
        _loading = false;
        _loadError = e.message;
      });
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final token = await _tokenStorage.read();
    if (!mounted) return;
    if (token == null || token.isEmpty) {
      _returnToWelcome();
      return;
    }
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _api.updateProfile(
        token,
        name: _nameCtrl.text.trim(),
        age: int.parse(_ageCtrl.text.trim()),
        sex: _sexCtrl.text.trim(),
        fleetName: _fleetCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('Crew details saved to the registry.')),
      );
    } on AuthApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      if (e.isAuthFailure && e.message == 'Session expired.') {
        await _tokenStorage.clear();
        if (mounted) _returnToWelcome();
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.stormRed),
      );
    }
  }

  Future<void> _logout() async {
    setState(() => _loggingOut = true);
    final token = await _tokenStorage.read();
    if (token != null && token.isNotEmpty) {
      // Best-effort server-side session delete; the local token is cleared
      // regardless so logout always succeeds from the user's perspective.
      try {
        await _api.logout(token);
      } on AuthApiException {
        // Ignore — we still clear locally below.
      }
    }
    await _tokenStorage.clear();
    if (!mounted) return;
    _returnToWelcome();
  }

  void _returnToWelcome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _sexCtrl.dispose();
    _fleetCtrl.dispose();
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
                              Center(
                                child: _ProfilePhotoPicker(
                                  photo: _photo,
                                  busy: _pickingPhoto,
                                  onTap: _pickPhoto,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'Your crew account. Everything else in Wavemind '
                                'stays private on this device.',
                                style: AppTextStyles.bodySmall,
                              ),
                              if (_loadError != null) ...[
                                const SizedBox(height: 16),
                                InlineErrorBanner(
                                  message: _loadError!,
                                  onRetry: _load,
                                ),
                              ],
                              if (_email.isNotEmpty) ...[
                                const SizedBox(height: 20),
                                _EmailRow(email: _email),
                              ],
                              const SizedBox(height: 20),
                              AuthTextField(
                                label: 'Name',
                                controller: _nameCtrl,
                                hint: 'e.g. Marcus Thorne',
                                textCapitalizationWords: true,
                                textInputAction: TextInputAction.next,
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                    ? 'Please enter a name.'
                                    : null,
                              ),
                              const SizedBox(height: 16),
                              AuthTextField(
                                label: 'Age',
                                controller: _ageCtrl,
                                hint: 'e.g. 34',
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.next,
                                validator: (v) {
                                  final value = v?.trim() ?? '';
                                  if (value.isEmpty) {
                                    return 'Please enter your age.';
                                  }
                                  final age = int.tryParse(value);
                                  if (age == null || age < 0 || age > 150) {
                                    return 'Please enter a valid age.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              AuthTextField(
                                label: 'Sex',
                                controller: _sexCtrl,
                                hint: 'e.g. male, female, …',
                                textInputAction: TextInputAction.next,
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                    ? 'Please enter this field.'
                                    : null,
                              ),
                              const SizedBox(height: 16),
                              AuthTextField(
                                label: 'Fleet Name',
                                controller: _fleetCtrl,
                                hint: 'e.g. Northern Fleet',
                                optional: true,
                                textCapitalizationWords: true,
                                textInputAction: TextInputAction.done,
                              ),
                              const SizedBox(height: 28),
                              AuthPrimaryButton(
                                label: 'Save',
                                busy: _saving,
                                onTap: _save,
                              ),
                              const SizedBox(height: 16),
                              _LogoutButton(
                                busy: _loggingOut,
                                onTap: _loggingOut ? null : _logout,
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
}

/// Read-only display of the account email (not editable here).
class _EmailRow extends StatelessWidget {
  const _EmailRow({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('EMAIL', style: AppTextStyles.caption),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.glassFillFaint,
            borderRadius: BorderRadius.circular(AppTheme.radiusTile),
            border: Border.all(color: AppColors.glassBorderSoft),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  email,
                  style: AppTextStyles.body.copyWith(color: AppColors.muted),
                ),
              ),
              const Icon(Icons.lock_outline, size: 16, color: AppColors.muted),
            ],
          ),
        ),
      ],
    );
  }
}

/// Secondary, outlined logout action beneath the primary save button.
class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppTheme.radiusButton),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusButton),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusButton),
            border: Border.all(color: AppColors.white),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          child: Center(
            child: busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.white,
                    ),
                  )
                : Text(
                    'Log Out',
                    style: AppTextStyles.buttonLarge.copyWith(
                      color: AppColors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// The circular avatar at the top of the profile form. Tapping it (or the
/// "Change Photo" / "Add Photo" link beneath it) opens the gallery picker
/// via [ProfilePhotoService] — the photo is copied into local app storage
/// and never leaves the device.
class _ProfilePhotoPicker extends StatelessWidget {
  const _ProfilePhotoPicker({
    required this.photo,
    required this.busy,
    required this.onTap,
  });

  final File? photo;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: busy ? null : onTap,
          child: Semantics(
            button: true,
            label: photo == null ? 'Add a profile photo' : 'Change profile photo',
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: const BoxDecoration(
                    color: AppColors.cream,
                    shape: BoxShape.circle,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: photo != null
                      ? Image.file(photo!, fit: BoxFit.cover)
                      : SvgPicture.asset(AppAssets.avatar, fit: BoxFit.cover),
                ),
                if (busy)
                  Container(
                    width: 96,
                    height: 96,
                    decoration: const BoxDecoration(
                      color: AppColors.overlayDark,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.seafoam,
                      ),
                    ),
                  ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      color: AppColors.seafoam,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.photo_camera,
                      size: 15,
                      color: AppColors.onAccent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: busy ? null : onTap,
          child: Text(
            photo == null ? 'Add Photo' : 'Change Photo',
            style: AppTextStyles.bodyStrong.copyWith(color: AppColors.seafoam),
          ),
        ),
      ],
    );
  }
}
