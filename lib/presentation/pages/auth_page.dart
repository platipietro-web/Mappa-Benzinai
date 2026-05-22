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

class _AuthPageState extends State<AuthPage> {
  late bool _isSignUp;
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _privacyAccepted = false;

  @override
  void initState() {
    super.initState();
    _isSignUp = widget.initialSignUp;
  }

  @override
  void didUpdateWidget(AuthPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSignUp != oldWidget.initialSignUp) {
      setState(() => _isSignUp = widget.initialSignUp);
    }
  }

  @override
  void dispose() {
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
      _showSnackbar(context, 'Devi accettare la Privacy Policy per registrarti');
      return;
    }
    if (email.isEmpty || !email.contains('@')) {
      _showSnackbar(context, 'Inserisci un\'email valida');
      return;
    }
    if (password.length < 6) {
      _showSnackbar(context, 'La password deve essere di almeno 6 caratteri');
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
      builder: (ctx) => AlertDialog(
        title: Text('Reset password',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(hintText: 'La tua email'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              final e = controller.text.trim();
              if (e.isNotEmpty && e.contains('@')) {
                context.read<AuthBloc>().add(ResetPasswordEvent(e));
                _showSnackbar(context, 'Email di reset inviata');
              } else {
                _showSnackbar(context, 'Inserisci un\'email valida');
              }
            },
            child: const Text('Invia'),
          ),
        ],
      ),
    );
  }

  void _showSnackbar(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.poppins(fontSize: 13)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthError) {
            _showSnackbar(context, state.message);
          }
        },
        builder: (context, state) {
          final isLoading = state is AuthLoading;

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),
                  Image.asset(
                    'assets/icons/logo.png',
                    width: 100,
                    height: 100,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Prezzi Benzina',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Trova i prezzi migliori vicino a te',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                  const SizedBox(height: 40),

                  Text(
                    _isSignUp ? 'Crea account' : 'Bentornato',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Nome e cognome (solo registrazione)
                  if (_isSignUp) ...[
                    TextField(
                      controller: _nameController,
                      enabled: !isLoading,
                      keyboardType: TextInputType.name,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        hintText: 'Nome e cognome',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Email
                  TextField(
                    controller: _emailController,
                    enabled: !isLoading,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      hintText: 'Indirizzo email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Password
                  TextField(
                    controller: _passwordController,
                    enabled: !isLoading,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      hintText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Conferma password (solo registrazione)
                  if (_isSignUp) ...[
                    TextField(
                      controller: _confirmPasswordController,
                      enabled: !isLoading,
                      obscureText: true,
                      decoration: const InputDecoration(
                        hintText: 'Conferma password',
                        prefixIcon: Icon(Icons.lock_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Consenso Privacy Policy (GDPR)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: _privacyAccepted,
                          onChanged: isLoading
                              ? null
                              : (v) => setState(
                                  () => _privacyAccepted = v ?? false),
                          activeColor: AppTheme.primaryColor,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: isLoading
                                ? null
                                : () => setState(() =>
                                    _privacyAccepted = !_privacyAccepted),
                            child: Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: RichText(
                                text: TextSpan(
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: AppTheme.textSecondaryColor,
                                  ),
                                  children: [
                                    const TextSpan(
                                        text: 'Ho letto e accetto la '),
                                    WidgetSpan(
                                      child: GestureDetector(
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (_) =>
                                                  const LegalPage()),
                                        ),
                                        child: Text(
                                          'Privacy Policy',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.primaryColor,
                                            decoration:
                                                TextDecoration.underline,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed:
                            isLoading ? null : () => _forgotPassword(context),
                        child: Text(
                          'Password dimenticata?',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Pulsante principale
                  ElevatedButton(
                    onPressed: isLoading ? null : () => _submit(context),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _isSignUp ? 'Crea account' : 'Accedi',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Continua come ospite
                  OutlinedButton(
                    onPressed: isLoading
                        ? null
                        : () => context
                            .read<AuthBloc>()
                            .add(const SignInAnonymouslyEvent()),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Text(
                        'Continua come ospite',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Toggle registrazione/login
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isSignUp
                            ? 'Hai già un account? '
                            : 'Non hai un account? ',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                      TextButton(
                        onPressed: isLoading
                            ? null
                            : () =>
                                setState(() => _isSignUp = !_isSignUp),
                        style: TextButton.styleFrom(padding: EdgeInsets.zero),
                        child: Text(
                          _isSignUp ? 'Accedi' : 'Registrati',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    ],
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
