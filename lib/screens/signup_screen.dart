import 'package:flutter/material.dart';

import '../core/notifications/notification_provider.dart' as notifications;
import '../core/notifications/notification_service.dart';
import '../data/auth_api.dart';
import '../data/auth_token_storage.dart';
import '../theme/app_colors.dart';
import '../widgets/auth_form.dart';
import 'home_dashboard_screen.dart';
import 'login_screen.dart';

/// First-time sailor signup. Reached from the Welcome screen's "Embark" CTA.
/// On success it stores the session token securely and replaces the whole
/// stack with the Helm dashboard.
class SignupScreen extends StatefulWidget {
  const SignupScreen({
    super.key,
    AuthApi? api,
    AuthTokenStorage? tokenStorage,
    NotificationService? notificationService,
  }) : _api = api,
       _tokenStorage = tokenStorage,
       _notificationService = notificationService;

  final AuthApi? _api;
  final AuthTokenStorage? _tokenStorage;

  /// Optional injection point for tests.
  final NotificationService? _notificationService;

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  late final AuthApi _api = widget._api ?? AuthApi();
  late final bool _ownsApi = widget._api == null;
  late final AuthTokenStorage _tokenStorage =
      widget._tokenStorage ?? AuthTokenStorage();
  late final NotificationService _notificationService =
      widget._notificationService ?? notifications.notificationService;

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _sexCtrl = TextEditingController();
  final _fleetCtrl = TextEditingController();

  bool _submitting = false;
  String? _error;

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final result = await _api.signup(
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        age: int.parse(_ageCtrl.text.trim()),
        sex: _sexCtrl.text.trim(),
        fleetName: _fleetCtrl.text.trim(),
      );
      await _tokenStorage.save(result.token);
      try {
        if (await _notificationService.requestPermission()) {
          await _notificationService.showSignupWelcome();
          await _notificationService.scheduleDailyReminders();
        }
      } catch (_) {
        // Best-effort — a notification-plugin hiccup must never block signup.
      }
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const HomeDashboardScreen()),
        (route) => false,
      );
    } on AuthApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.message;
      });
    }
  }

  void _goToLogin() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
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
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const AuthHeader(
                          title: 'Chart your course',
                          subtitle:
                              'Create your crew account to join the voyage and '
                              'track your wellness at sea.',
                        ),
                        const SizedBox(height: 32),
                        if (_error != null) ...[
                          InlineErrorBanner(message: _error!),
                          const SizedBox(height: 20),
                        ],
                        AuthTextField(
                          label: 'Name',
                          controller: _nameCtrl,
                          hint: 'e.g. Marcus Thorne',
                          textCapitalizationWords: true,
                          textInputAction: TextInputAction.next,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Please enter your name.'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        AuthTextField(
                          label: 'Email',
                          controller: _emailCtrl,
                          hint: 'e.g. marcus@example.com',
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          validator: validateEmail,
                        ),
                        const SizedBox(height: 16),
                        AuthTextField(
                          label: 'Password',
                          controller: _passwordCtrl,
                          hint: 'At least 8 characters',
                          obscureText: true,
                          textInputAction: TextInputAction.next,
                          validator: (v) {
                            final value = v ?? '';
                            if (value.isEmpty) {
                              return 'Please choose a password.';
                            }
                            if (value.length < 8) {
                              return 'Use at least 8 characters.';
                            }
                            return null;
                          },
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
                            if (value.isEmpty) return 'Please enter your age.';
                            final age = int.tryParse(value);
                            if (age == null || age > 150) {
                              return 'Please enter a valid age.';
                            }
                            // Wavemind is a 16+ app — see the Play Store
                            // Target Audience declaration.
                            if (age < 16) {
                              return 'You must be 16 or older to use Wavemind.';
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
                          validator: (v) => (v == null || v.trim().isEmpty)
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
                          onFieldSubmitted: (_) => _submit(),
                        ),
                        const SizedBox(height: 28),
                        AuthPrimaryButton(
                          label: 'Create Account',
                          busy: _submitting,
                          onTap: _submit,
                        ),
                        const SizedBox(height: 20),
                        SwitchAuthLink(
                          lead: 'Already have an account?',
                          action: 'Log in',
                          onTap: _submitting ? null : _goToLogin,
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
