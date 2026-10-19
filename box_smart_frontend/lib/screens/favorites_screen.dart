import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../main.dart';

class FavoritesScreen extends StatefulWidget {
  final int clienteId;
  final String token;
  final String baseUrl;
  final Map<int, int> carrinho;
  final Set<int> favoritosIds;
  final List<dynamic> produtosListaGlobal;
  final VoidCallback onAtualizouCarrinho;

  const FavoritesScreen({
    super.key,
    required this.clienteId,
    required this.token,
    required this.baseUrl,
    required this.carrinho,
    required this.favoritosIds,
    required this.produtosListaGlobal,
    required this.onAtualizouCarrinho,
  });

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  late Set<int> _favoritosLocais;
  bool _carregando = false;

  @override
  void initState() {
    super.initState();
    _favoritosLocais = Set.from(widget.favoritosIds);
  }

  Future<void> _removerFavorito(int produtoId) async {
    setState(() {
      _favoritosLocais.remove(produtoId);
      widget.favoritosIds.remove(produtoId);
    });

    try {
      await http.post(
        Uri.parse('${widget.baseUrl}/clientes/${widget.clienteId}/favoritos/$produtoId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
      );
    } catch (e) {
      debugPrint('Erro ao remover favorito: $e');
    }
  }

  void _adicionarTudoAoCarrinho(List<dynamic> produtosFavoritos) {
    setState(() {
      for (var prod in produtosFavoritos) {
        final int produtoId = prod['id'];
        final int estoque = prod['estoque'] ?? 50;

        if (estoque > 0) {
          final atual = widget.carrinho[produtoId] ?? 0;
          widget.carrinho[produtoId] = atual + 1;
        }
      }
    });

    widget.onAtualizouCarrinho();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Todos os produtos disponíveis foram adicionados ao carrinho!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Filtra a lista global de produtos para manter apenas os que estão nos favoritos do usuário
    final produtosFavoritos = widget.produtosListaGlobal
        .where((prod) => _favoritosLocais.contains(prod['id']))
        .toList();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Meus Favoritos',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: produtosFavoritos.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border_rounded, size: 70, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'Sua lista de favoritos está vazia',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black54),
            ),
            const SizedBox(height: 6),
            const Text(
              'Toque no coração dos produtos para salvá-los aqui.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      )
          : Column(
        children: [
          // Barra de Ação em Massa (Adicionar Tudo)
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: SizedBox(
              width: double.infinity,
              height: 45,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaria,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: () => _adicionarTudoAoCarrinho(produtosFavoritos),
                icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white, size: 18),
                label: const Text(
                  'Adicionar tudo ao carrinho',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          // Lista de Produtos
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: produtosFavoritos.length,
              itemBuilder: (context, index) {
                final prod = produtosFavoritos[index];
                final int produtoId = prod['id'];
                final String nome = prod['nome'] ?? '';
                final double preco = double.tryParse(prod['preco'].toString()) ?? 0.0;
                final dynamic precoClubeRaw = prod['preco_clube'];
                final bool temPrecoClube = precoClubeRaw != null;
                final double precoClube = temPrecoClube
                    ? (double.tryParse(precoClubeRaw.toString()) ?? 0.0)
                    : 0.0;
                final String? imagemUrl = prod['imagem_url'];
                final int estoque = prod['estoque'] ?? 50;
                final bool esgotado = estoque <= 0;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      // Imagem do Produto
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: 70,
                          height: 70,
                          color: Colors.grey.shade100,
                          child: imagemUrl != null && imagemUrl.startsWith('http')
                              ? Image.network(imagemUrl, fit: BoxFit.contain)
                              : const Icon(Icons.shopping_bag, color: Colors.grey),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Informações
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nome,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 6),
                            if (temPrecoClube)
                              Row(
                                children: [
                                  Text(
                                    'R\$ ${precoClube.toStringAsFixed(2).replaceFirst('.', ',')}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.green,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'R\$ ${preco.toStringAsFixed(2).replaceFirst('.', ',')}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),
                                ],
                              )
                            else
                              Text(
                                'R\$ ${preco.toStringAsFixed(2).replaceFirst('.', ',')}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black87,
                                ),
                              ),
                            if (esgotado)
                              const Text(
                                'Indisponível no momento',
                                style: TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold),
                              ),
                          ],
                        ),
                      ),
                      // Ações (Adicionar unitário e Remover favorito)
                      Column(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.favorite_rounded, color: Colors.red, size: 22),
                            onPressed: () => _removerFavorito(produtoId),
                            tooltip: 'Remover dos favoritos',
                          ),
                          if (!esgotado)
                            InkWell(
                              onTap: () {
                                setState(() {
                                  widget.carrinho[produtoId] = (widget.carrinho[produtoId] ?? 0) + 1;
                                });
                                widget.onAtualizouCarrinho();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('$nome adicionado!'),
                                    duration: const Duration(milliseconds: 600),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.primaria.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.add_shopping_cart, size: 18, color: AppColors.primaria),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}