import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import 'core/app_theme.dart';
import 'data/models.dart';
import 'data/services.dart';
import 'firebase_options.dart';
import 'ui/admin_app.dart';
import 'ui/auth_pages.dart';
import 'ui/common_widgets.dart';
import 'ui/owner_app.dart';
import 'ui/user_app.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: binding);

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseMessaging.onBackgroundMessage(
    firebaseMessagingBackgroundHandler,
  );

  await NotificationService.instance.initialize();

  runApp(const KurdStayApplication());
  FlutterNativeSplash.remove();
}

class KurdStayApplication extends StatelessWidget {
  const KurdStayApplication({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KurdStay',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const AuthenticationGate(),
    );
  }
}

class AuthenticationGate extends StatefulWidget {
  const AuthenticationGate({super.key});

  @override
  State<AuthenticationGate> createState() =>
      _AuthenticationGateState();
}

class _AuthenticationGateState
    extends State<AuthenticationGate> {
  int refreshVersion = 0;

  void refreshAfterEmailVerification() {
    if (!mounted) return;

    setState(() {
      refreshVersion++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      key: ValueKey(refreshVersion),
      stream: AuthService.instance.userChanges,
      initialData: AuthService.instance.currentUser,
      builder: (context, authenticationSnapshot) {
        if (authenticationSnapshot.connectionState ==
                ConnectionState.waiting &&
            AuthService.instance.currentUser == null) {
          return const Scaffold(
            body: LoadingView(),
          );
        }

        /*
         * Use currentUser first because reload() updates it with
         * the latest emailVerified value.
         */
        final firebaseUser =
            AuthService.instance.currentUser ??
                authenticationSnapshot.data;

        if (firebaseUser == null) {
          return const LoginPage();
        }

        if (!firebaseUser.emailVerified) {
          return VerifyEmailPage(
            onVerified: refreshAfterEmailVerification,
          );
        }

        return StreamBuilder<AppUser?>(
          stream: DatabaseService.instance.userStream(
            firebaseUser.uid,
          ),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState ==
                    ConnectionState.waiting &&
                !profileSnapshot.hasData) {
              return const Scaffold(
                body: LoadingView(),
              );
            }

            if (profileSnapshot.hasError) {
              return Scaffold(
                body: ErrorView(
                  error: profileSnapshot.error!,
                ),
              );
            }

            final profile = profileSnapshot.data;

            if (profile == null) {
              return const MissingProfilePage();
            }

            if (!profile.active) {
              return const SuspendedAccountPage();
            }

            NotificationService.instance.bindToUser(
              profile.id,
            );

            return switch (profile.role) {
              UserRole.admin => AdminApp(user: profile),
              UserRole.owner => OwnerApp(user: profile),
              UserRole.user => UserApp(user: profile),
            };
          },
        );
      },
    );
  }
}

class MissingProfilePage extends StatelessWidget {
  const MissingProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PagePadding(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const EmptyView(
              title: 'Profile record missing',
              message:
                  'The authentication account exists, but its Firestore profile could not be found.',
              icon: Icons.manage_accounts_outlined,
            ),
            FilledButton(
              onPressed: AuthService.instance.signOut,
              child: const Text('Return to login'),
            ),
          ],
        ),
      ),
    );
  }
}

class SuspendedAccountPage extends StatelessWidget {
  const SuspendedAccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PagePadding(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const EmptyView(
              title: 'Account suspended',
              message:
                  'Contact the KurdStay administrator for assistance.',
              icon: Icons.block_outlined,
            ),
            FilledButton(
              onPressed: AuthService.instance.signOut,
              child: const Text('Log out'),
            ),
          ],
        ),
      ),
    );
  }
}