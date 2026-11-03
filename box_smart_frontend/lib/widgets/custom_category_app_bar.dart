import 'package:flutter/material.dart';

class CustomCategoryAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? tituloCategoria;
  final VoidCallback? onCarrinhoPressed;
  final int qtdCarrinho;
  final Map<String, dynamic> configAppbar; // 🌟 Parâmetro dinâmico do portal

  const CustomCategoryAppBar({
    super.key,
    this.tituloCategoria,
    this.onCarrinhoPressed,
    this.qtdCarrinho = 0,
    this.configAppbar = const {}, // 🌟 Fallback seguro caso venha vazio
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  // 🌟 Auxiliar seguro para converter cor hexadecimal
  Color _parseCorHex(dynamic hexColor) {
    try {
      if (hexColor == null || hexColor.toString().isEmpty) {
        return const Color(0xFF0F172A); // Cor padrão de segurança
      }
      String corStr = hexColor.toString().replaceAll('#', '');
      if (corStr.length == 6) {
        corStr = 'FF$corStr';
      }
      return Color(int.parse(corStr, radix: 16));
    } catch (_) {
      return const Color(0xFF0F172A);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Lê as configurações vindas do mapa (com fallbacks seguros)
    final corFundo = _parseCorHex(configAppbar['appbar_cor_fundo'] ?? '#FFFFFF');
    final corIcones = _parseCorHex(configAppbar['appbar_cor_icones'] ?? '#0F172A');
    final tituloTexto = configAppbar['appbar_titulo_texto'] ?? 'BOX SMART';
    final exibirLogo = configAppbar['appbar_exibir_logo'] == true;
    final logoUrl = configAppbar['appbar_logo_url']?.toString() ?? '';

    return AppBar(
      backgroundColor: corFundo,
      elevation: 0.5,
      scrolledUnderElevation: 0.5,
      centerTitle: true,

      // Botão de voltar padrão para telas secundárias
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded, color: corIcones, size: 20),
        onPressed: () => Navigator.of(context).pop(),
      ),

      // Logo ou Título Central Clicável
      title: GestureDetector(
        onTap: () {
          Navigator.of(context).popUntil((route) => route.isFirst);
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: SizedBox(
            height: 36,
            child: (exibirLogo && logoUrl.isNotEmpty && logoUrl.startsWith('http'))
                ? Image.network(
              logoUrl,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Text(
                tituloTexto,
                style: TextStyle(
                  color: corIcones,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            )
                : Text(
              tituloTexto,
              style: TextStyle(
                color: corIcones,
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ),
      ),

      // Ações do lado direito (Carrinho com Badge)
      actions: [
        Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: Icon(Icons.shopping_cart_outlined, color: corIcones, size: 22),
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