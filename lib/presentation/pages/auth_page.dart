import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mappa_prezzi_benzina/presentation/bloc/auth_bloc.dart';
import 'package:mappa_prezzi_benzina/presentation/pages/legal_page.dart';
import 'package:mappa_prezzi_benzina/presentation/theme/app_theme.dart';

class AuthPage extends StatefulWidget {
  final bool initialSignUp;
  const AuthPage({Key? key, this.initialSignUp = false}) : super(key: key);

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage>
    with SingleTickerProviderStateMixin {
  late bool _isSignUp;
  late TabController _tabController;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _privacyAccepted = false;

  static const _gradientTop = Color(0xFF0F2167);
  static const _gradientMid = Color(0xFF1A3FA8);
  static const _gradientBot = Color(0xFF2563EB);

  @override
  void initState() {
    super.initState();
    _isSignUp = widget.initialSignUp;
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: _isSignUp ? 1 : 0,
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _isSignUp = _tabController.index == 1);
      }
    });
  }

  @override
  void didUpdateWidget(AuthPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSignUp != oldWidget.initialSignUp) {
      final newIdx = widget.initialSignUp ? 1 : 0;
      setState(() => _isSignUp = widget.initialSignUp);
      _tabController.animateTo(newIdx);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _submit(BuildContext context) {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (_isSignUp && name.isEmpty) {
      _showSnackbar(context, 'Inserisci nome e cognome');
      return;
    }
    if (_isSignUp && !_privacyAccepted) {
      _showSnackbar(
          context, 'Devi accettare la Privacy Policy per registrarti');
      return;
    }
    if (email.isEmpty || !email.contains('@')) {
      _showSnackbar(context, 'Inserisci un\'email valida');
      return;
    }
    if (password.length < 6) {
      _showSnackbar(context, 'La password deve avere almeno 6 caratteri');
      return;
    }
    if (_isSignUp && password != _confirmPasswordController.text) {
      _showSnackbar(context, 'Le password non coincidono');
      return;
    }

    if (_isSignUp) {
      context.read<AuthBloc>().add(
            SignUpEvent(email: email, password: password, displayName: name),
          );
    } else {
      context.read<AuthBloc>().add(SignInEvent(email: email, password: password));
    }
  }

  void _forgotPassword(BuildContext context) {
    final email = _emailController.text.trim();
    final controller = TextEditingController(text: email);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reset password',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Inserisci la tua email per ricevere le istruzioni.',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: 'Email',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppTheme.borderColor),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Annulla',
                          style: GoogleFonts.poppins(fontSize: 14)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        final e = controller.text.trim();
                        if (e.isNotEmpty && e.contains('@')) {
                          context.read<AuthBloc>().add(ResetPasswordEvent(e));
                          _showSnackbar(context, 'Email di reset inviata ✓');
                        } else {
                          _showSnackbar(context, 'Inserisci un\'email valida');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _gradientBot,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Invia',
                          style: GoogleFonts.poppins(
                              fontSize: 14, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSnackbar(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
                child: Text(msg, style: GoogleFonts.poppins(fontSize: 13))),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1E293B),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthError) {
            _showSnackbar(context, state.message);
          }
        },
        builder: (context, state) {
          final isLoading = state is AuthLoading;

          return Stack(
            children: [
              // ── Sfondo gradiente ──────────────────────────────────
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_gradientTop, _gradientMid, _gradientBot],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),

              // ── Cerchi decorativi ─────────────────────────────────
              Positioned(
                top: -60,
                right: -60,
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.06),
                  ),
                ),
              ),
              Positioned(
                top: 40,
                right: 40,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.06),
                  ),
                ),
              ),
              Positioned(
                bottom: 260,
                left: -40,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.04),
                  ),
                ),
              ),

              // ── Contenuto principale ──────────────────────────────
              SafeArea(
                child: Column(
                  children: [
                    // Hero: logo + titolo
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
                      child: Column(
                        children: [
                          // Badge logo
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Image.asset(
                                'assets/icons/logo.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Prezzi Benzina',
                            style: GoogleFonts.poppins(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Trova i prezzi migliori vicino a te',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.75),
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Card bianca con il form
                    Expanded(
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Color(0xFFF8FAFF),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(32),
                            topRight: Radius.circular(32),
                          ),
                        ),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // ── Tab Login / Registrati ──────────────
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEEF2FF),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                padding: const EdgeInsets.all(4),
                                child: TabBar(
                                  controller: _tabController,
                                  indicator: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            _gradientBot.withOpacity(0.12),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  indicatorSize: TabBarIndicatorSize.tab,
                                  labelColor: _gradientTop,
                                  unselectedLabelColor:
                                      AppTheme.textSecondaryColor,
                                  labelStyle: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  unselectedLabelStyle: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  dividerColor: Colors.transparent,
                                  tabs: const [
                                    Tab(text: 'Accedi'),
                                    Tab(text: 'Registrati'),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 28),

                              // ── Campi del form ──────────────────────
                              AnimatedSize(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                                child: Column(
                                  children: [
                                    // Nome (solo signup)
                                    if (_isSignUp) ...[
                                      _buildField(
                                        controller: _nameController,
                                        hint: 'Nome e cognome',
                                        icon: Icons.person_outline_rounded,
                                        enabled: !isLoading,
                                        keyboardType: TextInputType.name,
                                        textCapitalization:
                                            TextCapitalization.words,
                                      ),
                                      const SizedBox(height: 14),
                                    ],

                                    // Email
                                    _buildField(
                                      controller: _emailController,
                                      hint: 'Indirizzo email',
                                      icon: Icons.email_outlined,
                                      enabled: !isLoading,
                                      keyboardType:
                                          TextInputType.emailAddress,
                                    ),
                                    const SizedBox(height: 14),

                                    // Password
                                    _buildField(
                                      controller: _passwordController,
                                      hint: 'Password',
                                      icon: Icons.lock_outline_rounded,
                                      enabled: !isLoading,
                                      obscure: _obscurePassword,
                                      onToggleObscure: () => setState(() =>
                                          _obscurePassword =
                                              !_obscurePassword),
                                    ),

                                    // Conferma password (solo signup)
                                    if (_isSignUp) ...[
                                      const SizedBox(height: 14),
                                      _buildField(
                                        controller:
                                            _confirmPasswordController,
                                        hint: 'Conferma password',
                                        icon: Icons.lock_outline_rounded,
                                        enabled: !isLoading,
                                        obscure: _obscureConfirmPassword,
                                        onToggleObscure: () => setState(() =>
                                            _obscureConfirmPassword =
                                                !_obscureConfirmPassword),
                                      ),
                                      const SizedBox(height: 16),
                                      _buildPrivacyRow(isLoading),
                                    ] else ...[
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton(
                                          onPressed: isLoading
                                              ? null
                                              : () =>
                                                  _forgotPassword(context),
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets.only(
                                                top: 6),
                                          ),
                                          child: Text(
                                            'Password dimenticata?',
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              color: _gradientBot,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                              const SizedBox(height: 24),

                              // ── Bottone principale ──────────────────
                              SizedBox(
                                height: 52,
                                child: ElevatedButton(
                                  onPressed:
                                      isLoading ? null : () => _submit(context),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _gradientTop,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: isLoading
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Text(
                                          _isSignUp ? 'Crea account' : 'Accedi',
                                          style: GoogleFonts.poppins(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                ),
                              ),

                              const SizedBox(height: 20),

                              // ── Divisore "oppure" ───────────────────
                              Row(
                                children: [
                                  Expanded(
                                    child: Divider(
                                      color: AppTheme.borderColor,
                                      thickness: 1,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12),
                                    child: Text(
                                      'oppure',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: AppTheme.textSecondaryColor,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Divider(
                                      color: AppTheme.borderColor,
                                      thickness: 1,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 16),

                              // ── Bottone ospite ──────────────────────
                              SizedBox(
                                height: 52,
                                child: OutlinedButton.icon(
                                  onPressed: isLoading
                                      ? null
                                      : () => context
                                          .read<AuthBloc>()
                                          .add(
                                              const SignInAnonymouslyEvent()),
                                  icon: const Icon(
                                      Icons.person_off_outlined,
                                      size: 18),
                                  label: Text(
                                    'Continua come ospite',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor:
                                        AppTheme.textSecondaryColor,
                                    side: BorderSide(
                                        color: AppTheme.borderColor,
                                        width: 1.5),
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(14),
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 20),

                              // ── Footer note ospite ──────────────────
                              Center(
                                child: Text(
                                  'Come ospite non potrai salvare preferiti o storico',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: AppTheme.textSecondaryColor
                                        .withOpacity(0.7),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool enabled = true,
    bool? obscure,
    VoidCallback? onToggleObscure,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        enabled: enabled,
        obscureText: obscure ?? false,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppTheme.textPrimaryColor,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.poppins(
            fontSize: 14,
            color: AppTheme.textSecondaryColor.withOpacity(0.6),
          ),
          prefixIcon: Icon(icon, color: _gradientBot, size: 20),
          suffixIcon: onToggleObscure != null
              ? IconButton(
                  onPressed: onToggleObscure,
                  icon: Icon(
                    obscure! ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: AppTheme.textSecondaryColor,
                    size: 20,
                  ),
                )
              : null,
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _gradientBot, width: 1.8),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildPrivacyRow(bool isLoading) {
    return GestureDetector(
      onTap: isLoading
          ? null
          : () => setState(() => _privacyAccepted = !_privacyAccepted),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: _privacyAccepted,
              onChanged: isLoading
                  ? null
                  : (v) => setState(() => _privacyAccepted = v ?? false),
              activeColor: _gradientBot,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5)),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppTheme.textSecondaryColor,
                ),
                children: [
                  const TextSpan(text: 'Ho letto e accetto la '),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LegalPage()),
                      ),
                      child: Text(
                        'Privacy Policy',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _gradientBot,
                          decoration: TextDecoration.underline,
                          decorationColor: _gradientBot,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
