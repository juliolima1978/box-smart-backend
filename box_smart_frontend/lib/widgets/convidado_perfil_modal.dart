import 'package:flutter/material.dart';
import '../main.dart'; // Para acessar AppColors
import '../auth_screen.dart';

class ConvidadoPerfilModal extends StatelessWidget {
  const ConvidadoPerfilModal({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 32,
        bottom: MediaQuery.of(context).padding.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Ícone ilustrativo no topo
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaria.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Image.asset(
                'assets/icones/circle-user (2).png',
                color: AppColors.primaria,
                height: 48,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Título amigável
          const Text(
            'Acesse sua conta',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // Subtítulo explicando os benefícios
          const Text(
            'Entre ou cadastre-se para acompanhar seus pedidos, salvar favoritos e aproveitar todas as vantagens exclusivas do Supermercado Tescarollo.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),

          // Botão principal de Acesso
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaria,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            onPressed: () {
              Navigator.pop(context); // Fecha o modal
              // Redireciona para a tela oficial de login/cadastro
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AuthScreen()),
              );
            },
            child: const Text(
              'Entrar ou Cadastrar-se',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Opção de fechar/voltar a navegar
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Continuar navegando',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}