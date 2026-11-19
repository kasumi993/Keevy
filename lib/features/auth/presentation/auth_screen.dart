import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/dialogs.dart';
import '../application/auth_providers.dart';

/// Passwordless sign-in: email → 6-digit code. The router redirects once signed in.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key, this.from});
  final String? from;

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;
  String? _error;
  int _cooldown = 0;
  Timer? _timer;

  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$');

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _cooldown = 45);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _cooldown = _cooldown > 0 ? _cooldown - 1 : 0);
      if (_cooldown == 0) t.cancel();
    });
  }

  Future<void> _send({bool resend = false}) async {
    final s = S.of(context);
    final email = _email.text.trim();
    if (!_emailRe.hasMatch(email)) {
      setState(() => _error = s.emailInvalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).sendCode(email, locale: s.isFr ? 'fr' : 'en');
      if (!mounted) return;
      setState(() => _codeSent = true);
      _startCooldown();
      if (resend) showSnack(context, s.codeResent);
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) handleError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    final s = S.of(context);
    final code = _code.text.replaceAll(RegExp(r'\D'), '');
    if (code.length < 6) {
      setState(() => _error = s.codeInvalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).verifyCode(_email.text, code);
      // The router redirects on the auth state change.
    } on AuthException {
      if (mounted) setState(() => _error = s.codeInvalid);
    } catch (e) {
      if (mounted) handleError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(KSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Keevy', style: t.displayLarge?.copyWith(fontSize: 40)),
                  const SizedBox(height: KSpacing.xs),
                  Text(s.tagline, style: t.bodyLarge?.copyWith(color: KColors.t2, fontStyle: FontStyle.italic, fontFamily: KFonts.serif)),
                  const SizedBox(height: KSpacing.xxl),
                  Text(_codeSent ? s.codeTitle : s.authTitle, style: t.displaySmall),
                  const SizedBox(height: KSpacing.sm),
                  Text(_codeSent ? s.codeSubtitle(_email.text.trim()) : s.authSubtitle, style: t.bodyMedium),
                  const SizedBox(height: KSpacing.xl),
                  if (!_codeSent)
                    TextField(
                      controller: _email,
                      autofocus: true,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(labelText: s.emailLabel, errorText: _error),
                    )
                  else
                    TextField(
                      controller: _code,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      textInputAction: TextInputAction.done,
                      maxLength: 6,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontFamily: KFonts.sans, fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: 10),
                      onChanged: (v) {
                        if (v.length == 6) _verify();
                      },
                      onSubmitted: (_) => _verify(),
                      decoration: InputDecoration(counterText: '', hintText: '••••••', errorText: _error),
                    ),
                  const SizedBox(height: KSpacing.lg),
                  BusyButton(
                    label: _codeSent ? s.verify : s.sendCode,
                    busy: _busy,
                    onPressed: _codeSent ? _verify : _send,
                  ),
                  if (_codeSent) ...[
                    const SizedBox(height: KSpacing.sm),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => setState(() {
                                    _codeSent = false;
                                    _code.clear();
                                    _error = null;
                                  }),
                          child: Text(s.changeEmail),
                        ),
                        TextButton(
                          onPressed: _busy || _cooldown > 0 ? null : () => _send(resend: true),
                          child: Text(_cooldown > 0 ? '${s.resendCode} (${_cooldown}s)' : s.resendCode),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: KSpacing.xl),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.lock_outline_rounded, size: 14, color: KColors.t3),
                      const SizedBox(width: 6),
                      Text(s.privacyNotice, style: t.bodySmall),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
