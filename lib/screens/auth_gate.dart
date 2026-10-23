import 'package:flutter/material.dart';

import '../data/auth_api.dart';
import '../data/auth_token_storage.dart';
import '../theme/app_colors.dart';
import 'home_dashboard_screen.dart';
import 'welcome_screen.dart';

/// App-launch auth gate — the root route.
///
/// On launch it checks secure storage for a session token. If one is present it
/// validates it against `GET /auth/me`:
///   * valid    -> skip Welcome, go straight to the Helm dashboard;
///   * 401 / invalid -> clear the stale token, fall through to Welcome;
///   * backend unreachable -> keep the token (it may still be good) and fall
///     through to Welcome rather than hanging or crashing on a dead server.
///
/// While the check runs it shows the app's gradient splash. The decision uses
/// `pushReplacement`, so this gate replaces itself with the chosen screen and
/// leaves no empty route behind.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key, AuthApi? api, AuthTokenStorage? tokenStorage})
    : _api = api,
      _tokenStorage = tokenStorage;

  final AuthApi? _api;
  final AuthTokenStorage? _tokenStorage;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final AuthApi _api = widget._api ?? AuthApi();
  late final bool _ownsApi = widget._api == null;
  late final AuthTokenStorage _tokenStorage =
      widget._tokenStorage ?? AuthTokenStorage();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _decide());
  }

  Future<void> _decide() async {
    var authenticated = false;
    final token = await _tokenStorage.read();
    if (token != null && token.isNotEmpty) {
      try {
        await _api.me(token);
        authenticated = true;
      } on AuthApiException catch (e) {
        // A rejected token is stale — drop it. A transport failure leaves the
        // token in place (the server may just be down) but still falls through
        // to Welcome so the app never hangs on an unreachable backend.
        if (e.isAuthFailure) {
          await _tokenStorage.clear();
        }
      }
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => authenticated
            ? const HomeDashboardScreen()
            : const WelcomeScreen(),
      ),
    );
  }

  @override
  void dispose() {
    if (_ownsApi) _api.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: AppColors.appBackgroundGradient),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.seafoam),
        ),
      ),
    );
  }
}
