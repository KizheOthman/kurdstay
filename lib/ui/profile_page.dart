import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../data/models.dart';
import '../data/services.dart';
import 'common_widgets.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    required this.user,
    super.key,
  });

  final AppUser user;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final TextEditingController nameController;
  late final TextEditingController phoneController;

  bool loading = false;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.user.name);
    phoneController =
        TextEditingController(text: widget.user.phone);
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  Future<void> saveProfile() async {
    setState(() => loading = true);

    try {
      await AuthService.instance.updateProfile(
        name: nameController.text,
        phone: phoneController.text,
      );

      if (mounted) showMessage(context, 'Profile updated.');
    } catch (error) {
      if (mounted) {
        showMessage(context, error.toString(), error: true);
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> changeEmail() async {
    final currentPassword = TextEditingController();
    final newEmail = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Change email'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: newEmail,
              keyboardType: TextInputType.emailAddress,
              decoration:
                  const InputDecoration(labelText: 'New email'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: currentPassword,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Current password',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (result != true) return;

    try {
      await AuthService.instance.changeEmail(
        currentPassword: currentPassword.text,
        newEmail: newEmail.text,
      );

      if (mounted) {
        showMessage(
          context,
          'Verification was sent to the new email address.',
        );
      }
    } catch (error) {
      if (mounted) {
        showMessage(context, error.toString(), error: true);
      }
    }
  }

  Future<void> changePassword() async {
    final currentPassword = TextEditingController();
    final newPassword = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Change password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentPassword,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Current password',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newPassword,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New password',
                helperText: 'Minimum 8 characters',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != true) return;

    try {
      await AuthService.instance.changePassword(
        currentPassword: currentPassword.text,
        newPassword: newPassword.text,
      );

      if (mounted) showMessage(context, 'Password updated.');
    } catch (error) {
      if (mounted) {
        showMessage(context, error.toString(), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 6),
        CircleAvatar(
          radius: 42,
          backgroundColor: AppColors.blush,
          child: Text(
            widget.user.name.isEmpty
                ? '?'
                : widget.user.name[0].toUpperCase(),
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 32,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          widget.user.name,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          widget.user.role.name.toUpperCase(),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Full name',
            prefixIcon: Icon(Icons.person_outline),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: phoneController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Phone number',
            prefixIcon: Icon(Icons.phone_outlined),
          ),
        ),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: loading ? null : saveProfile,
          child: const Text('Save profile'),
        ),
        const SizedBox(height: 18),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(
                  Icons.email_outlined,
                  color: AppColors.primary,
                ),
                title: const Text('Change email'),
                subtitle: Text(widget.user.email),
                trailing: const Icon(Icons.chevron_right),
                onTap: changeEmail,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(
                  Icons.password_outlined,
                  color: AppColors.primary,
                ),
                title: const Text('Change password'),
                trailing: const Icon(Icons.chevron_right),
                onTap: changePassword,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(
                  Icons.logout_rounded,
                  color: AppColors.danger,
                ),
                title: const Text('Log out'),
                onTap: () async {
                  final confirmed = await confirmAction(
                    context,
                    title: 'Log out',
                    message:
                        'Are you sure you want to leave your account?',
                    confirmText: 'Log out',
                  );

                  if (confirmed) {
                    await AuthService.instance.signOut();
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}