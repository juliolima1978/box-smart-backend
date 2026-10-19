import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class GerenciarProdutosTab extends StatefulWidget {
  final String baseUrl;
  final String token;

  const GerenciarProdutosTab({
    super.key,
    required this.baseUrl,
    required this.token,
  });

  @override
  State<GerenciarProdutosTab> createState() => _GerenciarProdutosTabState();
}

class _GerenciarProdutosTabState extends State<GerenciarProdutosTab> {
  List<dynamic> _produtos = [];
  List<dynamic> _categorias = [];
  List<dynamic> _subcategorias = []; // 🌟 Lista completa de subcategorias vindas do admin
  bool _isLoading = true;

  final TextEditingController _buscaController = TextEditingController();
  String _termoBusca = '';

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    setState(() => _isLoading = true);
    try {
      final responses = await Future.wait([
        http.get(Uri.parse('${widget.baseUrl}/api/produtos/'), headers: {'Authorization': 'Bearer ${widget.token}'}),
        http.get(Uri.parse('${widget.baseUrl}/admin/categorias/'), headers: {'Authorization': 'Bearer ${widget.token}'}),
        http.get(Uri.parse('${widget.baseUrl}/admin/subcategorias/'), headers: {'Authorization': 'Bearer ${widget.token}'}), // 🌟 Carrega subcategorias
      ]);

      if (responses[0].statusCode == 200 && responses[1].statusCode == 200) {
        setState(() {
          _produtos = jsonDecode(responses[0].body);
          _categorias = jsonDecode(responses[1].body);
          if (responses[2].statusCode == 200) {
            _subcategorias = jsonDecode(responses[2].body);
          }
          _isLoading = false;
        });
      } else {
        _mostrarErro('Erro ao carregar dados do servidor.');
      }
    } catch (e) {
      _mostrarErro('Erro de conexão: $e');
    }
  }

  Future<void> _deletarProduto(int id, String nome) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Produto'),
        content: Text('Deseja realmente excluir o produto "$nome"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              try {
                final response = await http.delete(
                  Uri.parse('${widget.baseUrl}/admin/produtos/$id'),
                  headers: {'Authorization': 'Bearer ${widget.token}'},
                );

                if (response.statusCode == 200 || response.statusCode == 204) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Produto excluído com sucesso!'), backgroundColor: Colors.green));
                  _carregarDados();
                } else {
                  _mostrarErro('Erro ao excluir produto.');
                }
              } catch (e) {
                _mostrarErro('Erro de conexão: $e');
              }
            },
            child: const Text('Excluir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _exibirFormularioProduto({Map<String, dynamic>? produtoExistente}) {
    final nomeCtrl = TextEditingController(text: produtoExistente?['nome'] ?? '');
    final descCtrl = TextEditingController(text: produtoExistente?['descricao'] ?? '');
    final precoCtrl = TextEditingController(text: produtoExistente?['preco']?.toString() ?? '');
    final precoClubeCtrl = TextEditingController(text: produtoExistente?['preco_clube']?.toString() ?? '');
    final estoqueCtrl = TextEditingController(text: produtoExistente?['estoque']?.toString() ?? '50');
    final imagemCtrl = TextEditingController(text: produtoExistente?['imagem_url'] ?? '');

    int? categoriaIdSelecionada = produtoExistente?['categoria_id'] ?? (_categorias.isNotEmpty ? _categorias[0]['id'] : null);

    // 🌟 Subcategoria selecionada inicialmente (se houver)
    int? subcategoriaIdSelecionada = produtoExistente?['subcategoria_id'];

    String unidadeSelecionada = produtoExistente?['unidade'] ?? 'un';
    bool destaque = produtoExistente?['destaque'] ?? false;
    bool maisVendido = produtoExistente?['mais_vendido'] ?? false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            // 🌟 Filtra as subcategorias apenas da categoria atualmente selecionada
            final subcategoriasFiltradas = _subcategorias.where((sub) => sub['categoria_id'] == categoriaIdSelecionada).toList();

            return AlertDialog(
              title: Text(produtoExistente == null ? 'Novo Produto' : 'Editar Produto', style: const TextStyle(fontWeight: FontWeight.bold)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              content: SizedBox(
                width: 600,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(controller: nomeCtrl, decoration: const InputDecoration(labelText: 'Nome do Produto', border: OutlineInputBorder())),
                      const SizedBox(height: 12),
                      TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Descrição', border: OutlineInputBorder())),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: TextField(controller: precoCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Preço (R\$)', border: OutlineInputBorder()))),
                          const SizedBox(width: 12),
                          Expanded(child: TextField(controller: precoClubeCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Preço Clube (R\$)', border: OutlineInputBorder()))),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: TextField(controller: estoqueCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Estoque', border: OutlineInputBorder()))),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: unidadeSelecionada,
                              decoration: const InputDecoration(labelText: 'Unidade', border: OutlineInputBorder()),
                              items: const [
                                DropdownMenuItem(value: 'un', child: Text('Unidade (un)')),
                                DropdownMenuItem(value: 'kg', child: Text('Quilograma (kg)')),
                                DropdownMenuItem(value: 'g', child: Text('Gramas (g)')),
                                DropdownMenuItem(value: 'l', child: Text('Litros (l)')),
                              ],
                              onChanged: (val) => setStateModal(() => unidadeSelecionada = val ?? 'un'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // 🌟 Dropdown de Categoria
                      DropdownButtonFormField<int>(
                        value: categoriaIdSelecionada,
                        decoration: const InputDecoration(labelText: 'Categoria', border: OutlineInputBorder()),
                        items: _categorias.map<DropdownMenuItem<int>>((cat) {
                          return DropdownMenuItem<int>(
                            value: cat['id'],
                            child: Text(cat['nome']),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setStateModal(() {
                            categoriaIdSelecionada = val;
                            // Reseta a subcategoria ao trocar de categoria para evitar inconsistências
                            subcategoriaIdSelecionada = null;
                          });
                        },
                      ),
                      const SizedBox(height: 12),

                      // 🌟 Dropdown Dinâmico de Subcategoria
                      DropdownButtonFormField<int?>(
                        value: subcategoriaIdSelecionada,
                        decoration: const InputDecoration(labelText: 'Subcategoria (Segmento)', border: OutlineInputBorder()),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('Nenhuma / Geral', style: TextStyle(color: Colors.grey)),
                          ),
                          ...subcategoriasFiltradas.map<DropdownMenuItem<int?>>((sub) {
                            return DropdownMenuItem<int?>(
                              value: sub['id'],
                              child: Text(sub['nome']),
                            );
                          }),
                        ],
                        onChanged: (val) => setStateModal(() => subcategoriaIdSelecionada = val),
                      ),

                      const SizedBox(height: 12),
                      TextField(controller: imagemCtrl, decoration: const InputDecoration(labelText: 'URL da Imagem', border: OutlineInputBorder())),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        title: const Text('Produto em Destaque'),
                        value: destaque,
                        onChanged: (val) => setStateModal(() => destaque = val),
                      ),
                      SwitchListTile(
                        title: const Text('Mais Vendido'),
                        value: maisVendido,
                        onChanged: (val) => setStateModal(() => maisVendido = val),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A)),
                  onPressed: () async {
                    if (nomeCtrl.text.trim().isEmpty || precoCtrl.text.trim().isEmpty || categoriaIdSelecionada == null) {
                      _mostrarErro('Preencha os campos obrigatórios (Nome, Preço e Categoria).');
                      return;
                    }

                    final payload = {
                      "nome": nomeCtrl.text.trim(),
                      "descricao": descCtrl.text.trim(),
                      "preco": double.tryParse(precoCtrl.text.replaceAll(',', '.')) ?? 0.0,
                      "preco_clube": precoClubeCtrl.text.isNotEmpty ? double.tryParse(precoClubeCtrl.text.replaceAll(',', '.')) : null,
                      "unidade": unidadeSelecionada,
                      "estoque": int.tryParse(estoqueCtrl.text) ?? 50,
                      "imagem_url": imagemCtrl.text.trim().isNotEmpty ? imagemCtrl.text.trim() : null,
                      "categoria_id": categoriaIdSelecionada,
                      "subcategoria_id": subcategoriaIdSelecionada, // 🌟 Enviado para o backend
                      "destaque": destaque,
                      "mais_vendido": maisVendido,
                      "ativo": true,
                    };

                    try {
                      final url = produtoExistente == null
                          ? '${widget.baseUrl}/admin/produtos/'
                          : '${widget.baseUrl}/admin/produtos/${produtoExistente['id']}';

                      final response = produtoExistente == null
                          ? await http.post(Uri.parse(url), headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${widget.token}'}, body: jsonEncode(payload))
                          : await http.put(Uri.parse(url), headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${widget.token}'}, body: jsonEncode(payload));

                      if (response.statusCode == 200 || response.statusCode == 201) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Produto salvo com sucesso!'), backgroundColor: Colors.green));
                        _carregarDados();
                      } else {
                        _mostrarErro('Erro ao salvar: ${response.body}');
                      }
                    } catch (e) {
                      _mostrarErro('Erro de conexão: $e');
                    }
                  },
                  child: const Text('Salvar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _mostrarErro(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensagem), backgroundColor: Colors.red.shade900));
  }

  @override
  Widget build(BuildContext context) {
    final produtosFiltrados = _produtos.where((p) {
      if (_termoBusca.isEmpty) return true;
      String nome = (p['nome'] ?? '').toString().toLowerCase();
      return nome.contains(_termoBusca.toLowerCase());
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Gestão de Produtos e Estoque', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
                onPressed: () => _exibirFormularioProduto(),
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('Novo Produto', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: 300,
            child: TextField(
              controller: _buscaController,
              decoration: InputDecoration(
                hintText: 'Buscar produto por nome...',
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              onChanged: (valor) {
                setState(() {
                  _termoBusca = valor.trim();
                });
              },
            ),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : produtosFiltrados.isEmpty
                ? const Center(child: Text('Nenhum produto encontrado.', style: TextStyle(color: Colors.grey, fontSize: 16)))
                : Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListView.separated(
                itemCount: produtosFiltrados.length,
                separatorBuilder: (context, index) => Divider(color: Colors.grey.shade200, height: 1),
                itemBuilder: (context, index) {
                  final produto = produtosFiltrados[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        produto['imagem_url'] ?? '',
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 50,
                          height: 50,
                          color: Colors.grey.shade300,
                          child: const Icon(Icons.inventory_2, size: 24, color: Colors.grey),
                        ),
                      ),
                    ),
                    title: Text(produto['nome'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                    subtitle: Text('Preço: R\$ ${produto['preco'].toStringAsFixed(2)} | Estoque: ${produto['estoque']} ${produto['unidade']}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, color: Color(0xFF1E3A8A)),
                          tooltip: 'Editar',
                          onPressed: () => _exibirFormularioProduto(produtoExistente: produto),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          tooltip: 'Excluir',
                          onPressed: () => _deletarProduto(produto['id'], produto['nome']),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}