import 'package:flutter/material.dart';

import '../data/auth_api.dart';
import '../data/auth_token_storage.dart';
import '../theme/app_colors.dart';
import '../widgets/auth_form.dart';
import 'home_dashboard_screen.dart';
import 'signup_screen.dart';

/// Returning-sailor login. Reached from the Signup screen ("Already have an
/// account? Log in"). On success it stores the session token securely and
/// replaces the whole stack with the Helm dashboard.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, AuthApi? api, AuthTokenStorage? tokenStorage})
    : _api = api,
      _tokenStorage = tokenStorage;

  final AuthApi? _api;
  final AuthTokenStorage? _tokenStorage;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final AuthApi _api = widget._api ?? AuthApi();
  late final bool _ownsApi = widget._api == null;
  late final AuthTokenStorage _tokenStorage =
      widget._tokenStorage ?? AuthTokenStorage();

  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

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
      final result = await _api.login(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      await _tokenStorage.save(result.token);
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

  void _goToSignup() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const SignupScreen()),
    );
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
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
                          title: 'Welcome back aboard',
                          subtitle:
                              'Log in to pick up where you left off on the '
                              'voyage.',
                        ),
                        const SizedBox(height: 32),
                        if (_error != null) ...[
                          InlineErrorBanner(message: _error!),
                          const SizedBox(height: 20),
                        ],
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
                          hint: 'Your password',
                          obscureText: true,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          validator: (v) => (v == null || v.isEmpty)
                              ? 'Please enter your password.'
                              : null,
                        ),
                        const SizedBox(height: 28),
                        AuthPrimaryButton(
                          label: 'Log In',
                          busy: _submitting,
                          onTap: _submit,
                        ),
                        const SizedBox(height: 20),
                        SwitchAuthLink(
                          lead: 'New here?',
                          action: 'Sign up',
                          onTap: _submitting ? null : _goToSignup,
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
