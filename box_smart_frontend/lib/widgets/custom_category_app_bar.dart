import 'package:flutter/material.dart';

class CustomCategoryAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? tituloCategoria;
  final VoidCallback? onCarrinhoPressed;
  final int qtdCarrinho;

  const CustomCategoryAppBar({
    super.key,
    this.tituloCategoria,
    this.onCarrinhoPressed,
    this.qtdCarrinho = 0,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0.5,
      scrolledUnderElevation: 0.5,
      centerTitle: true,

      // Botão de voltar padrão para telas secundárias
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 20),
        onPressed: () => Navigator.of(context).pop(),
      ),

      // Logo central clicável apontando para a Home
      title: GestureDetector(
        onTap: () {
          // Retorna até a primeira rota (Home) se ela estiver na pilha
          Navigator.of(context).popUntil((route) => route.isFirst);
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Image.asset(
            'assets/logo.png', // Substitua pelo caminho exato da sua imagem/logo
            height: 32,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const Text(
              'BOX SMART',
              style: TextStyle(
                color: Color(0xFF1E3A8A),
                fontWeight: FontWeight.w900,
                fontSize: 18,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ),
      ),

      // Ações do lado direito (ex: ícone do Carrinho com Badge)
      actions: [
        Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.shopping_cart_outlined, color: Color(0xFF0F172A), size: 22),
              onPressed: onCarrinhoPressed ?? () {},
            ),
            if (qtdCarrinho > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    '$qtdCarrinho',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}