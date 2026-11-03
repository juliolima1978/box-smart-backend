import 'package:flutter/material.dart';

class CustomSupermercadoAppBar extends StatelessWidget implements PreferredSizeWidget {
  final int qtdCarrinho;
  final VoidCallback onPerfilPressed;
  final VoidCallback onCarrinhoPressed;
  final VoidCallback onFavoritosPressed;
  final VoidCallback onNotificacoesPressed;

  const CustomSupermercadoAppBar({
    Key? key,
    required this.qtdCarrinho,
    required this.onPerfilPressed,
    required this.onCarrinhoPressed,
    required this.onFavoritosPressed,
    required this.onNotificacoesPressed,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    // Substitua AppColors.primaria pela cor desejada (ex: Colors.green[800])
    const corPrincipal = Color(0xFF15803D);

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0.5,
      centerTitle: true,
      // Ícones laterais padronizados (estilo Material Icons, mais limpo)
      leading: IconButton(
        icon: const Icon(Icons.person_outline, color: corPrincipal),
        onPressed: onPerfilPressed,
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.favorite_border, color: corPrincipal),
          onPressed: onFavoritosPressed,
        ),
        Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.shopping_cart_outlined, color: corPrincipal),
              onPressed: onCarrinhoPressed,
            ),
            if (qtdCarrinho > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    '$qtdCarrinho',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 8), // Espaçamento final
      ],
      // Logo centralizado (substitua pelo seu asset ou NetworkImage)
      title: SizedBox(
        height: 36,
        child: Image.asset(
          'assets/logogimptesc.png', // Use sua imagem aqui
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}