import 'package:flutter/material.dart';
import 'produto_detalhe_screen.dart';
import '../main.dart'; // Importa AppColors

class SearchScreen extends StatefulWidget {
  final int clienteId;
  final String token;
  final Map<int, int> carrinho;
  final Set<int> favoritosIds;
  final List<dynamic> produtosListaGlobal;

  const SearchScreen({
    super.key,
    required this.clienteId,
    required this.token,
    required this.carrinho,
    required this.favoritosIds,
    required this.produtosListaGlobal,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _buscaController = TextEditingController();
  String _termoBusca = '';

  @override
  void initState() {
    super.initState();
    _buscaController.addListener(() {
      setState(() {
        _termoBusca = _buscaController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Filtra os produtos com base no termo digitado
    List<dynamic> resultados = [];
    if (_termoBusca.isNotEmpty) {
      resultados = widget.produtosListaGlobal.where((prod) {
        final nome = (prod['nome'] ?? '').toString().toLowerCase();
        final categoria = (prod['categoria'] ?? '').toString().toLowerCase();
        return nome.contains(_termoBusca) || categoria.contains(_termoBusca);
      }).toList();
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: AppColors.primaria,
        iconTheme: const IconThemeData(color: Colors.white),
        title: TextField(
          controller: _buscaController,
          autofocus: true, // Já abre com o teclado ativado
          style: const TextStyle(color: Colors.white, fontSize: 16),
          cursorColor: Colors.white,
          decoration: const InputDecoration(
            hintText: 'O que você está procurando?',
            hintStyle: TextStyle(color: Colors.white70),
            border: InputBorder.none,
          ),
        ),
        actions: [
          if (_termoBusca.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_rounded, color: Colors.white),
              onPressed: () {
                _buscaController.clear();
              },
            ),
        ],
      ),
      body: _termoBusca.isEmpty
          ? Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Buscas Populares',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildTagSugestao('Arroz'),
                _buildTagSugestao('Feijão'),
                _buildTagSugestao('Carne'),
                _buildTagSugestao('Leite'),
                _buildTagSugestao('Frutas'),
                _buildTagSugestao('Bebidas'),
              ],
            ),
          ],
        ),
      )
          : resultados.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 50, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'Nenhum resultado para "$_termoBusca"',
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: resultados.length,
        itemBuilder: (context, index) {
          final prod = resultados[index];
          final double preco = double.tryParse(prod['preco'].toString().replaceAll(',', '.')) ?? 0.0;

          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Container(
                width: 45,
                height: 45,
                padding: const EdgeInsets.all(4),
                child: prod['imagem_url'] != null && prod['imagem_url'].toString().startsWith('http')
                    ? Image.network(prod['imagem_url'], fit: BoxFit.contain)
                    : const Icon(Icons.shopping_bag, color: Colors.grey),
              ),
              title: Text(
                prod['nome'] ?? '',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                'R\$ ${preco.toStringAsFixed(2).replaceAll('.', ',')}',
                style: TextStyle(fontSize: 12, color: AppColors.primaria, fontWeight: FontWeight.w800),
              ),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProdutoDetalheScreen(
                      clienteId: widget.clienteId,
                      token: widget.token,
                      favoritosIds: widget.favoritosIds,
                      produto: prod,
                      carrinho: widget.carrinho,
                      produtosListaGlobal: widget.produtosListaGlobal,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  // Widget auxiliar para termos populares clicáveis
  Widget _buildTagSugestao(String termo) {
    return ActionChip(
      backgroundColor: Colors.white,
      side: BorderSide(color: Colors.grey.shade300),
      label: Text(termo, style: const TextStyle(fontSize: 12, color: Colors.black87)),
      onPressed: () {
        _buscaController.text = termo;
        _buscaController.selection = TextSelection.fromPosition(
          TextPosition(offset: termo.length),
        );
      },
    );
  }
}