import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../auth/presentation/providers/auth_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          Consumer<AuthProvider>(
            builder: (context, auth, _) {
              return IconButton(
                onPressed: auth.isBusy ? null : _logout,
                icon: const Icon(Icons.logout),
                tooltip: 'Logout',
              );
            },
          ),
        ],
      ),
      body: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          final profile = auth.currentProfile;
          if (auth.isBusy && profile == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome ${profile?.displayName ?? 'User'}',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text('Email: ${auth.currentUser?.email ?? '-'}'),
                const SizedBox(height: 8),
                Text('Username: ${profile?.username ?? '-'}'),
                const SizedBox(height: 8),
                Text('Display name: ${profile?.displayName ?? '-'}'),
                const SizedBox(height: 24),
                const Text(
                  'This is the MVP profile placeholder shown after login.',
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
