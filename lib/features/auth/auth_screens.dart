import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/widgets/feedback.dart';
import '../../providers/app_providers.dart';

/// Shared frame for sign in, sign up and password reset.
class _AuthScaffold extends StatelessWidget {
  const _AuthScaffold({
    required this.title,
    required this.subtitle,
    required this.children,
    this.showBack = false,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: showBack ? AppBar() : null,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              shrinkWrap: true,
              children: [
                if (!showBack) ...[
                  const AppLogo(size: 64),
                  const SizedBox(height: 22),
                ],
                Text(title, style: context.text.headlineMedium),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: context.text.bodyMedium?.copyWith(
                    color: context.scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 28),
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(authServiceProvider)
          .signIn(email: _email.text, password: _password.text);
      // The router's auth redirect takes over from here.
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      AppToast.error(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AuthScaffold(
      title: 'Balance Book',
      subtitle: 'Know exactly what every client owes you.',
      children: [
        Form(
          key: _formKey,
          child: Column(
            children: [
              _EmailField(controller: _email),
              const SizedBox(height: 12),
              _PasswordField(
                controller: _password,
                obscure: _obscure,
                onToggle: () => setState(() => _obscure = !_obscure),
                onSubmitted: _submit,
                validator: (value) => (value?.isEmpty ?? true)
                    ? 'Enter your password'
                    : null,
              ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => context.push('/forgot-password'),
            child: const Text('Forgot password?'),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Sign in'),
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('New here?', style: context.text.bodySmall),
            TextButton(
              onPressed: () => context.push('/signup'),
              child: const Text('Create an account'),
            ),
          ],
        ),
      ],
    );
  }
}

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscure = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(authServiceProvider)
          .signUp(
            name: _name.text,
            email: _email.text,
            password: _password.text,
          );
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      AppToast.error(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AuthScaffold(
      showBack: true,
      title: 'Create your account',
      subtitle: 'Your clients and balances stay private to you.',
      children: [
        Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                decoration: const InputDecoration(
                  labelText: 'Your name',
                  prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                ),
                validator: (value) =>
                    (value?.trim().isEmpty ?? true) ? 'Enter your name' : null,
              ),
              const SizedBox(height: 12),
              _EmailField(controller: _email),
              const SizedBox(height: 12),
              _PasswordField(
                controller: _password,
                obscure: _obscure,
                onToggle: () => setState(() => _obscure = !_obscure),
                onSubmitted: _submit,
                helperText: 'At least 6 characters',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Choose a password';
                  }
                  return value.length < 6
                      ? 'Use at least 6 characters'
                      : null;
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Create account'),
        ),
        const SizedBox(height: 14),
        Text(
          'Only you can see your clients and their balances.',
          textAlign: TextAlign.center,
          style: context.text.bodySmall,
        ),
      ],
    );
  }
}

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState
    extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _busy = false;
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _busy = true);
    try {
      await ref.read(authServiceProvider).sendPasswordReset(_email.text);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _sent = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      AppToast.error(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_sent) {
      return _AuthScaffold(
        showBack: true,
        title: 'Check your email',
        subtitle:
            'If an account exists for ${_email.text.trim()}, a reset link is '
            'on its way. It can take a minute to arrive.',
        children: [
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
            ),
            onPressed: () => context.go('/login'),
            child: const Text('Back to sign in'),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => setState(() => _sent = false),
            child: const Text('Use a different email'),
          ),
        ],
      );
    }

    return _AuthScaffold(
      showBack: true,
      title: 'Reset your password',
      subtitle: 'We will email you a link to set a new one.',
      children: [
        Form(key: _formKey, child: _EmailField(controller: _email)),
        const SizedBox(height: 20),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Send reset link'),
        ),
      ],
    );
  }
}

class _EmailField extends StatelessWidget {
  const _EmailField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      autocorrect: false,
      autofillHints: const [AutofillHints.email],
      decoration: const InputDecoration(
        labelText: 'Email',
        prefixIcon: Icon(Icons.alternate_email_rounded, size: 20),
      ),
      validator: (value) {
        final text = value?.trim() ?? '';
        if (text.isEmpty) return 'Enter your email';
        final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text);
        return ok ? null : 'That email address does not look right';
      },
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.obscure,
    required this.onToggle,
    required this.onSubmitted,
    required this.validator,
    this.helperText,
  });

  final TextEditingController controller;
  final bool obscure;
  final VoidCallback onToggle;
  final VoidCallback onSubmitted;
  final String? Function(String?) validator;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      textInputAction: TextInputAction.done,
      autofillHints: const [AutofillHints.password],
      decoration: InputDecoration(
        labelText: 'Password',
        helperText: helperText,
        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
        suffixIcon: IconButton(
          tooltip: obscure ? 'Show password' : 'Hide password',
          onPressed: onToggle,
          icon: Icon(
            obscure
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            size: 20,
          ),
        ),
      ),
      onFieldSubmitted: (_) => onSubmitted(),
      validator: validator,
    );
  }
}
