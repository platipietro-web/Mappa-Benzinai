import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mappa_prezzi_benzina/core/services/service_locator.dart';
import 'package:mappa_prezzi_benzina/presentation/bloc/auth_bloc.dart';
import 'package:mappa_prezzi_benzina/presentation/bloc/user_profile_bloc.dart';
import 'package:mappa_prezzi_benzina/presentation/pages/legal_page.dart';
import 'package:mappa_prezzi_benzina/presentation/pages/main_screen.dart'
    show vehiclesTabIndex;
import 'package:mappa_prezzi_benzina/presentation/theme/app_theme.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;

    final isAnonymous =
        authState is Authenticated ? authState.isAnonymous : true;

    context.watch<UserProfileBloc>();

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: AppTheme.textPrimaryColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Profilo',
          style: GoogleFonts.poppins(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimaryColor,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 16),

            // Avatar
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: isAnonymous
                    ? AppTheme.borderColor
                    : AppTheme.primaryColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isAnonymous ? Icons.person_outline : Icons.person,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),

            // Tipo account
            Text(
              isAnonymous ? 'Ospite' : 'Account registrato',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimaryColor,
              ),
            ),
            if (!isAnonymous) ...[
              const SizedBox(height: 4),
              Builder(builder: (context) {
                final profile = context.watch<UserProfileBloc>().state.profile;
                final name = profile?.displayName?.isNotEmpty == true
                    ? profile!.displayName!
                    : profile?.email ?? '';
                if (name.isEmpty) return const SizedBox.shrink();
                return Text(
                  name,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: AppTheme.textSecondaryColor,
                  ),
                );
              }),
            ],

            const SizedBox(height: 32),

            // Sezione utente registrato
            if (!isAnonymous) ...[
              // Dashboard link
              _InfoCard(
                icon: Icons.bar_chart_rounded,
                iconColor: AppTheme.primaryColor,
                title: 'La tua dashboard',
                value: '',
                onTap: () => Navigator.pushNamed(context, '/dashboard'),
              ),
              const SizedBox(height: 12),

              // Auto
              _InfoCard(
                icon: Icons.directions_car_rounded,
                iconColor: AppTheme.primaryColor,
                title: 'Le tue auto',
                value: '',
                onTap: () {
                  getIt<ValueNotifier<int>>(instanceName: 'mainTabIndex')
                      .value = vehiclesTabIndex;
                  Navigator.of(context).popUntil((r) => r.isFirst);
                },
              ),
              const SizedBox(height: 12),
            ],

            // Sezione ospite: invito a registrarsi o accedere
            if (isAnonymous) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppTheme.primaryColor.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: AppTheme.primaryColor, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Account ospite',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Registrati per salvare le stazioni preferite e accedere alla tua area personale.',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.of(context)
                                  .popUntil((r) => r.isFirst);
                              context
                                  .read<AuthBloc>()
                                  .add(const SignOutEvent());
                            },
                            child: Text('Accedi',
                                style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(context)
                                  .popUntil((r) => r.isFirst);
                              context.read<AuthBloc>().add(
                                    const SignOutEvent(signUpMode: true),
                                  );
                            },
                            child: Text('Registrati',
                                style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Privacy Policy
            _InfoCard(
              icon: Icons.privacy_tip_outlined,
              iconColor: AppTheme.textSecondaryColor,
              title: 'Informativa sulla Privacy',
              value: '',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LegalPage()),
              ),
            ),
            const SizedBox(height: 12),

            // Elimina account (solo utenti registrati)
            if (!isAnonymous) ...[
              _InfoCard(
                icon: Icons.delete_forever_rounded,
                iconColor: AppTheme.errorColor,
                title: 'Elimina account',
                value: '',
                onTap: () => _confirmDeleteAccount(context),
              ),
              const SizedBox(height: 12),
            ],

            // Logout
            _InfoCard(
              icon: Icons.logout_rounded,
              iconColor: AppTheme.errorColor,
              title: 'Esci',
              value: '',
              onTap: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text('Esci',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600)),
                    content: Text(
                      'Sei sicuro di voler uscire?',
                      style: GoogleFonts.poppins(fontSize: 14),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Annulla'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.errorColor),
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.pop(context);
                          context
                              .read<AuthBloc>()
                              .add(const SignOutEvent());
                        },
                        child: const Text('Esci'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteAccount(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Elimina account',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text(
          'Questa azione è irreversibile. Tutti i tuoi dati (preferiti, veicoli, rifornimenti) '
          'saranno eliminati definitivamente.',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
              context.read<AuthBloc>().add(const DeleteAccountEvent());
            },
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final VoidCallback onTap;

  const _InfoCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
            ),
            if (value.isNotEmpty)
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded,
                color: AppTheme.textSecondaryColor, size: 20),
          ],
        ),
      ),
    );
  }
}
