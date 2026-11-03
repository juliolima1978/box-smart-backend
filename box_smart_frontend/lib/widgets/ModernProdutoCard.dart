import 'package:flutter/material.dart';

import '../main.dart';

class ModernProdutoCard extends StatelessWidget {
  final Map<String, dynamic> produto;
  final VoidCallback onTap;
  final VoidCallback onComprar;

  const ModernProdutoCard({
    Key? key,
    required this.produto,
    required this.onTap,
    required this.onComprar,
  });

  @override
  Widget build(BuildContext context) {
    // Substitua pelos seus campos reais (produto['...'])
    final nome = produto['nome'] ?? '';
    final unidade = produto['unidade'] ?? '';
    final precoVenda = double.tryParse(produto['preco']?.toString() ?? '0.00') ?? 0.00;
    final precoAnterior = double.tryParse(produto['preco_anterior']?.toString() ?? '0.00') ?? 0.00;
    final descontoPercentual = precoAnterior > 0 ? ((precoAnterior - precoVenda) / precoAnterior * 100).round() : 0;
    final imagemUrl = produto['imagem_url'] ?? '';
    final precoPorKg = produto['preco_kg'] ?? '';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Stack(
          children: [
            // Conteúdo principal do card
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Imagem do produto (com aspect ratio para ficar quadrada)
                AspectRatio(
                  aspectRatio: 1,
                  child: Center(
                    child: Image.network(
                      imagemUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // 2. Nome do produto
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    nome,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                ),
                const SizedBox(height: 4),
                // 3. Unidade e Preço por KG (Ex: (R$ 8,95/KG))
                if (precoPorKg.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      '(R\$ $precoPorKg/KG)',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ),
                const SizedBox(height: 8),
                // 4. Preço Anterior (Riscado)
                if (precoAnterior > precoVenda)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      'R\$ ${precoAnterior.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  ),
                // 5. Preço Atual (Verde e Grande)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    'R\$ ${precoVenda.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF15803D), // Cor Verde
                    ),
                  ),
                ),
                const Spacer(),
                // 6. Botão "Eu quero!"
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: onComprar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF15803D), // Cor Verde
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.add_shopping_cart, size: 18, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'Eu quero!',
                            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Tags de Desconto e Selo (Posicionadas em cima)
            if (descontoPercentual > 0)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '-$descontoPercentual%',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            // Exemplo de selo "bem estar" (você precisaria da imagem ou lógica para isso)
            /*
            Positioned(
              top: 8,
              right: 8,
              child: Image.asset('assets/icones/selo_bem_estar.png', height: 24),
            ),
            */
            // Ícone de Adicionar à Lista/Mais Opções (no canto superior direito do card)
            Positioned(
              top: 8,
              right: 8,
              child: CircleAvatar(
                radius: 12,
                backgroundColor: Colors.grey.shade200,
                child: const Icon(Icons.list_alt_outlined, color: AppColors.primaria),
              ),
            ),
          ],
        ),
      ),
    );
  }
}