import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import 'package:restart_app/restart_app.dart';

class AtualizadorScreen extends StatefulWidget {
  final Widget proximaTela;

  const AtualizadorScreen({
    super.key,
    required this.proximaTela,
  });

  @override
  State<AtualizadorScreen> createState() => _AtualizadorScreenState();
}

class _AtualizadorScreenState extends State<AtualizadorScreen> {
  final _shorebirdUpdater = ShorebirdUpdater();
  bool _baixandoAtualizacao = false;

  // Trava em memória: impede qualquer loop de reinicialização
  static bool _jaReiniciouNestaSessao = false;

  @override
  void initState() {
    super.initState();
    _verificarEAtualizar();
  }

  Future<void> _verificarEAtualizar() async {
    // Se já reiniciou agora há pouco ou não é build Shorebird, abre o app direto
    if (_jaReiniciouNestaSessao || !_shorebirdUpdater.isAvailable) {
      _irParaApp();
      return;
    }

    try {
      final status = await _shorebirdUpdater
          .checkForUpdate()
          .timeout(const Duration(seconds: 6));

      if (status == UpdateStatus.outdated) {
        if (mounted) {
          setState(() => _baixandoAtualizacao = true);
        }

        // Baixa o patch
        await _shorebirdUpdater.update().timeout(const Duration(seconds: 20));

        // Marca a trava antes de reiniciar para não repetir caso a VM Dart persista
        _jaReiniciouNestaSessao = true;

        if (mounted) {
          await Restart.restartApp();
          return;
        }
      } else if (status == UpdateStatus.restartRequired) {
        // Só reinicia se ainda não tiver tentado nesta sessão
        _jaReiniciouNestaSessao = true;
        await Restart.restartApp();
        return;
      }
    } on TimeoutException {
      debugPrint('Shorebird: timeout na verificação.');
    } catch (e) {
      debugPrint('Shorebird: erro ao verificar atualização ($e).');
    }

    _irParaApp();
  }

  void _irParaApp() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => widget.proximaTela,
        transitionDuration: const Duration(milliseconds: 250),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF186B4D),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              /*Image.asset(
                'assets/icon_tesca1.png',
                width: 140,
                height: 140,
                fit: BoxFit.contain,
              ),*/
              const SizedBox(height: 32),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _baixandoAtualizacao
                    ? 'Aplicando novidades...'
                    : 'Carregando...',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}