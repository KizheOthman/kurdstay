import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import '../core/app_theme.dart';
import '../data/services.dart';
import 'common_widgets.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool obscure = true;
  bool loading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!(formKey.currentState?.validate() ?? false)) return;

    setState(() => loading = true);

    try {
      await AuthService.instance.signIn(
        email: emailController.text,
        password: passwordController.text,
      );
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        showMessage(
          context,
          error.message ?? 'Login failed.',
          error: true,
        );
      }
    } catch (error) {
      if (mounted) {
        showMessage(context, error.toString(), error: true);
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NetworkStatusBanner(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 42, 24, 30),
            child: Form(
              key: formKey,
              child: Column(
                children: [
                  const KurdStayLogo(),
                  const SizedBox(height: 36),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Welcome back',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Log in to find and book your next stay.',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'Email address',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (value) {
                      final email = value?.trim() ?? '';
                      if (!email.contains('@')) {
                        return 'Enter a valid email address.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: passwordController,
                    obscureText: obscure,
                    autofillHints: const [AutofillHints.password],
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setState(() => obscure = !obscure),
                        icon: Icon(
                          obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    validator: (value) =>
                        (value?.isEmpty ?? true)
                            ? 'Enter your password.'
                            : null,
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              const ForgotPasswordPage(),
                        ),
                      ),
                      child: const Text('Forgot password?'),
                    ),
                  ),
                  FilledButton(
                    onPressed: loading ? null : submit,
                    child: loading
                        ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Log in'),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Do not have an account?'),
                      TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => const RegisterPage(),
                          ),
                        ),
                        child: const Text('Register'),
                      ),
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

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();

  bool obscure = true;
  bool loading = false;

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!(formKey.currentState?.validate() ?? false)) return;

    setState(() => loading = true);

    try {
      await AuthService.instance.register(
        name: nameController.text,
        email: emailController.text,
        phone: phoneController.text,
        password: passwordController.text,
      );

      if (mounted) {
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        showMessage(
          context,
          error.message ?? 'Registration failed.',
          error: true,
        );
      }
    } catch (error) {
      if (mounted) {
        showMessage(context, error.toString(), error: true);
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: formKey,
            child: Column(
              children: [
                const KurdStayLogo(size: 64, showName: false),
                const SizedBox(height: 24),
                TextFormField(
                  controller: nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Full name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (value) =>
                      (value?.trim().length ?? 0) < 3
                          ? 'Enter your full name.'
                          : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone number',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: (value) =>
                      (value?.trim().length ?? 0) < 7
                          ? 'Enter a valid phone number.'
                          : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email address',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (value) =>
                      !(value?.contains('@') ?? false)
                          ? 'Enter a valid email address.'
                          : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: passwordController,
                  obscureText: obscure,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => obscure = !obscure),
                      icon: Icon(
                        obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: (value) =>
                      (value?.length ?? 0) < 8
                          ? 'Use at least 8 characters.'
                          : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: confirmController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm password',
                    prefixIcon:
                        Icon(Icons.lock_reset_outlined),
                  ),
                  validator: (value) =>
                      value != passwordController.text
                          ? 'Passwords do not match.'
                          : null,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: loading ? null : submit,
                  child: loading
                      ? const CircularProgressIndicator(
                          color: Colors.white,
                        )
                      : const Text('Register'),
                ),
                const SizedBox(height: 10),
                const Text(
                  'New registrations receive the User role. '
                  'An administrator can promote an account to Hotel Owner.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() =>
      _ForgotPasswordPageState();
}

class _ForgotPasswordPageState
    extends State<ForgotPasswordPage> {
  final emailController = TextEditingController();
  bool loading = false;

  Future<void> submit() async {
    if (!emailController.text.contains('@')) {
      showMessage(context, 'Enter a valid email address.', error: true);
      return;
    }

    setState(() => loading = true);

    try {
      await AuthService.instance
          .sendPasswordReset(emailController.text);

      if (mounted) {
        showMessage(
          context,
          'Password-reset email sent. Check your inbox.',
        );
      }
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        showMessage(
          context,
          error.message ?? 'Unable to send email.',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset password')),
      body: PagePadding(
        child: Column(
          children: [
            const SizedBox(height: 24),
            const Icon(
              Icons.mark_email_read_outlined,
              size: 72,
              color: AppColors.primary,
            ),
            const SizedBox(height: 18),
            const Text(
              'Enter your account email. We will send you a secure reset link.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email address',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: loading ? null : submit,
              child: const Text('Send reset email'),
            ),
          ],
        ),
      ),
    );
  }
}

class VerifyEmailPage extends StatefulWidget {
  const VerifyEmailPage({
    required this.onVerified,
    super.key,
  });

  final VoidCallback onVerified;

  @override
  State<VerifyEmailPage> createState() =>
      _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage>
    with WidgetsBindingObserver {
  Timer? verificationTimer;

  bool checking = false;
  bool resending = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    /*
     * Check periodically. This also handles verification being
     * completed on another device or while using split screen.
     */
    verificationTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => checkVerification(silent: true),
    );
  }

  @override
  void didChangeAppLifecycleState(
    AppLifecycleState state,
  ) {
    /*
     * When the user returns from Gmail or the browser,
     * check immediately.
     */
    if (state == AppLifecycleState.resumed) {
      checkVerification(silent: true);
    }
  }

  Future<void> checkVerification({
    bool silent = false,
  }) async {
    if (checking) return;

    if (mounted) {
      setState(() => checking = true);
    }

    try {
      final verified = await AuthService.instance
          .reloadAndCheckEmailVerification();

      if (!mounted) return;

      if (verified) {
        verificationTimer?.cancel();

        /*
         * Rebuild AuthenticationGate. It will now see that
         * emailVerified is true and open the appropriate app.
         */
        widget.onVerified();
        return;
      }

      if (!silent) {
        showMessage(
          context,
          'Your email is not verified yet. Open the verification '
          'link in your email and return to KurdStay.',
          error: true,
        );
      }
    } on FirebaseAuthException catch (error) {
      if (!mounted || silent) return;

      showMessage(
        context,
        error.message ??
            'Unable to check your verification status.',
        error: true,
      );
    } catch (error, stackTrace) {
      debugPrint(
        'Email verification check failed: $error',
      );
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted || silent) return;

      showMessage(
        context,
        'Unable to check verification. Please try again.',
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() => checking = false);
      }
    }
  }

  Future<void> resendVerificationEmail() async {
    if (resending) return;

    setState(() => resending = true);

    try {
      final user = AuthService.instance.currentUser;

      if (user == null) {
        throw StateError('No authenticated user.');
      }

      await user.sendEmailVerification();

      if (!mounted) return;

      showMessage(
        context,
        'A new verification email was sent.',
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;

      showMessage(
        context,
        error.message ??
            'Unable to resend the verification email.',
        error: true,
      );
    } catch (error) {
      if (!mounted) return;

      showMessage(
        context,
        error.toString(),
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() => resending = false);
      }
    }
  }

  @override
  void dispose() {
    verificationTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final email =
        AuthService.instance.currentUser?.email ?? '';

    return Scaffold(
      body: SafeArea(
        child: PagePadding(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const KurdStayLogo(
                size: 70,
                showName: false,
              ),
              const SizedBox(height: 26),
              const Text(
                'Verify your email',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'A verification link was sent to\n$email',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'After verifying, return to KurdStay. '
                'The app will check automatically.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: checking
                    ? null
                    : () => checkVerification(),
                child: checking
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'I have verified my email',
                      ),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: resending
                    ? null
                    : resendVerificationEmail,
                child: resending
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Resend verification email',
                      ),
              ),
              TextButton(
                onPressed: checking
                    ? null
                    : AuthService.instance.signOut,
                child: const Text('Use another account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}