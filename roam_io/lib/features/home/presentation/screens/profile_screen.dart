import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../shared/widgets/app_page_header.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/screens/change_password_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().refreshCurrentUser();
    });
  }

  Future<void> _logout() async {
    final auth = context.read<AuthProvider>();
    await auth.signOut();

    if (!mounted) return;

    if (auth.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.errorMessage!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          final profile = auth.currentProfile;

          if (auth.isBusy && profile == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 110),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppPageHeader(
                    title: 'Profile',
                    subtitle: 'Manage your account and preferences.',
                  ),
                  const SizedBox(height: 12),
                  Text('Email: ${auth.currentUser?.email ?? '-'}'),
                  const SizedBox(height: 8),
                  Text('Username: ${profile?.username ?? '-'}'),
                  const SizedBox(height: 8),
                  Text('Display name: ${profile?.displayName ?? '-'}'),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: auth.isBusy
                        ? null
                        : () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const ChangePasswordScreen(),
                              ),
                            );
                          },
                    child: const Text('Change password'),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: auth.isBusy ? null : _logout,
                    child: const Text('Logout'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}