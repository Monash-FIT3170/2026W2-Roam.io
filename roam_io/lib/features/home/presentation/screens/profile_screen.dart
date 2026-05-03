import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../shared/widgets/app_page_header.dart';
import '../../../../shared/widgets/app_toast.dart';
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

  Future<void> _changeProfilePhoto() async {
    final auth = context.read<AuthProvider>();
    if (auth.isBusy) return;

    final XFile? pickedFile;
    try {
      pickedFile = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
      );
    } catch (_) {
      if (!mounted) return;
      AppToast.error(
        context,
        'Could not open photo library. Please check photo permissions and try again.',
      );
      return;
    }
    if (pickedFile == null) return;

    await auth.uploadProfilePicture(pickedFile);
    if (!mounted) return;

    if (auth.errorMessage != null) {
      AppToast.error(context, auth.errorMessage!);
      return;
    }

    AppToast.success(context, 'Profile picture updated successfully.');
  }

  Future<void> _logout() async {
    final auth = context.read<AuthProvider>();
    await auth.signOut();

    if (!mounted) return;

    if (auth.errorMessage != null) {
      AppToast.error(context, auth.errorMessage!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.cream,
      child: SafeArea(
        child: Consumer<AuthProvider>(
          builder: (context, auth, _) {
            final profile = auth.currentProfile;

            if (auth.isBusy && profile == null) {
              return const Center(child: CircularProgressIndicator());
            }

            final email = auth.currentUser?.email ?? '-';
            final username = profile?.username ?? '-';
            final displayName = profile?.displayName ?? '-';

            return SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 110),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppPageHeader(
                    title: 'Profile Settings',
                    subtitle: 'Manage your identity and account preferences.',
                  ),

                  const SizedBox(height: 16),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        // 🟫 Profile Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppColors.sand,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: AppColors.sage.withOpacity(0.12),
                            ),
                          ),
                          child: Column(
                            children: [
                              // 🔥 Avatar (NOW CREAM)
                              SizedBox(
                                width: 92,
                                height: 92,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    GestureDetector(
                                      onTap: auth.isBusy
                                          ? null
                                          : _changeProfilePhoto,
                                      child: Container(
                                        width: 92,
                                        height: 92,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: AppColors.cream,
                                          border: Border.all(
                                            color: AppColors.sage,
                                            width: 2,
                                          ),
                                        ),
                                        child: ClipOval(
                                          child: profile?.photoUrl != null
                                              ? Image.network(
                                                  profile!.photoUrl!,
                                                  fit: BoxFit.cover,
                                                  width: 92,
                                                  height: 92,
                                                  errorBuilder:
                                                      (
                                                        context,
                                                        error,
                                                        stackTrace,
                                                      ) => Icon(
                                                        Icons.person_rounded,
                                                        size: 48,
                                                        color: AppColors.sage,
                                                      ),
                                                )
                                              : Icon(
                                                  Icons.person_rounded,
                                                  size: 48,
                                                  color: AppColors.sage,
                                                ),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      right: -4,
                                      bottom: -4,
                                      child: Material(
                                        color: AppColors.sand,
                                        shape: const CircleBorder(),
                                        child: InkWell(
                                          customBorder: const CircleBorder(),
                                          onTap: auth.isBusy
                                              ? null
                                              : _changeProfilePhoto,
                                          child: Padding(
                                            padding: const EdgeInsets.all(8),
                                            child: Icon(
                                              Icons.camera_alt_rounded,
                                              size: 18,
                                              color: AppColors.ink,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 14),

                              Text(
                                displayName,
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.ink,
                                ),
                              ),

                              const SizedBox(height: 4),

                              Text(
                                '@$username',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.ink.withOpacity(0.45),
                                ),
                              ),

                              const SizedBox(height: 20),

                              _ProfileInfoTile(
                                icon: Icons.email_outlined,
                                label: 'Email',
                                value: email,
                              ),

                              const SizedBox(height: 10),

                              _ProfileInfoTile(
                                icon: Icons.alternate_email_rounded,
                                label: 'Username',
                                value: username,
                              ),

                              const SizedBox(height: 10),

                              _ProfileInfoTile(
                                icon: Icons.badge_outlined,
                                label: 'Display Name',
                                value: displayName,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // 🔥 PRIMARY CTA (SAGE BUTTON)
                        _SecondaryProfileButton(
                          label: 'Change Password',
                          icon: Icons.lock_outline_rounded,
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
                        ),

                        const SizedBox(height: 18),

                        // 🔴 Minimal logout
                        TextButton.icon(
                          onPressed: auth.isBusy ? null : _logout,
                          icon: Icon(
                            Icons.logout_rounded,
                            size: 16,
                            color: AppColors.clay,
                          ),
                          label: Text(
                            'Log out',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.clay.withOpacity(0.85),
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
      ),
    );
  }
}

// 🧾 Info tile
class _ProfileInfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileInfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.sage.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: AppColors.sage),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink.withOpacity(0.45),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// 🔥 SAGE BUTTON (primary)
class _SecondaryProfileButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  const _SecondaryProfileButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 220,
        height: 48,
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 18),
          label: Text(label),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.sage,
            foregroundColor: Colors.white,
            elevation: 0,
            textStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }
}
