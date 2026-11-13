import 'package:flutter/material.dart';
import '../main.dart';
import '../services/session_service.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _animationController.forward();
    _inicializarApp();
  }

  Future<void> _inicializarApp() async {
    final resultados = await Future.wait([
      SessionService.carregarSessao(),
      Future.delayed(const Duration(seconds: 2)),
    ]);

    final Map<String, dynamic> sessao = resultados[0] as Map<String, dynamic>;

    final int clienteId = sessao['clienteId'] ?? 0;
    final String clienteNome =
    (sessao['clienteNome'] ?? '').toString().isNotEmpty
        ? sessao['clienteNome']
        : 'Visitante';
    final String token = sessao['token'] ?? '';

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => HomeScreen(
          clienteId: clienteId,
          clienteNome: clienteNome,
          token: token,
        ),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaria,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Image.asset(
            'assets/icon_tesca1.png', // Ou 'assets/logogimptesc.png'
            width: 200,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}