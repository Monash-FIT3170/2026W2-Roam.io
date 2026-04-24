import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../shared/widgets/app_page_header.dart';
import '../../../../theme/app_colours.dart';
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppPageHeader(
                  title: 'Profile Settings',
                  subtitle:
                      'Manage your identity and exploration preferences.',
                ),

                const SizedBox(height: 16),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Email: ${auth.currentUser?.email ?? '-'}'),
                      const SizedBox(height: 8),
                      Text('Username: ${profile?.username ?? '-'}'),
                      const SizedBox(height: 8),
                      Text('Display name: ${profile?.displayName ?? '-'}'),

                      const SizedBox(height: 32),

                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: auth.isBusy ? null : () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.sage,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          child: const Text(
                            'Save Changes',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton(
                          onPressed: auth.isBusy
                              ? null
                              : () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          const ChangePasswordScreen(),
                                    ),
                                  );
                                },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.ink,
                            side: BorderSide(
                              color: AppColors.ink.withOpacity(0.18),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          child: const Text(
                            'Change Password',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      Center(
                        child: TextButton(
                          onPressed: auth.isBusy ? null : _logout,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.clay,
                          ),
                          child: const Text(
                            'Log Out',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}