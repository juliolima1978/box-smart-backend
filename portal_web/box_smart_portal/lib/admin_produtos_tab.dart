import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AdminProdutosTab extends StatefulWidget {
  final String baseUrl;

  const AdminProdutosTab({super.key, required this.baseUrl});

  @override
  State<AdminProdutosTab> createState() => _AdminProdutosTabState();
}

class _AdminProdutosTabState extends State<AdminProdutosTab> {
  List<dynamic> _produtos = [];
  List<dynamic> _categorias = []; // 🌟 Lista para armazenar as categorias
  bool _carregando = true;
  String _categoriaSelecionada = 'Todas'; // 🌟 Filtro atual

  @override
  void initState() {
    super.initState();
    _carregarDadosIniciais();
  }

  // 🌟 Carrega produtos e categorias simultaneamente
  Future<void> _carregarDadosIniciais() async {
    setState(() => _carregando = true);
    await Future.wait([
      _buscarProdutos(),
      _buscarCategorias(),
    ]);
  }

  Future<void> _buscarProdutos() async {
    try {
      final response = await http.get(Uri.parse('${widget.baseUrl}/api/produtos/'));
      if (response.statusCode == 200) {
        setState(() {
          _produtos = json.decode(response.body);
        });
      }
    } catch (e) {
      debugPrint('Erro ao buscar produtos no admin: $e');
    } finally {
      if (mounted && _categorias.isNotEmpty) {
        setState(() => _carregando = false);
      }
    }
  }

  // 🌟 Nova função para buscar as categorias cadastradas
  Future<void> _buscarCategorias() async {
    try {
      final response = await http.get(Uri.parse('${widget.baseUrl}/categorias/'));
      if (response.statusCode == 200) {
        setState(() {
          _categorias = json.decode(response.body);
        });
      }
    } catch (e) {
      debugPrint('Erro ao buscar categorias: $e');
    } finally {
      if (mounted) {
        setState(() => _carregando = false);
      }
    }
  }

  void _exibirFormularioProduto([Map<String, dynamic>? produto]) {
    final bool isEdicao = produto != null;

    final nomeCtrl = TextEditingController(text: produto?['nome'] ?? '');
    final descricaoCtrl = TextEditingController(text: produto?['descricao'] ?? '');
    final precoCtrl = TextEditingController(text: produto?['preco']?.toString() ?? '');
    final precoClubeCtrl = TextEditingController(text: produto?['preco_clube']?.toString() ?? '');
    final unidadeCtrl = TextEditingController(text: produto?['unidade'] ?? 'un');
    final estoqueCtrl = TextEditingController(text: produto?['estoque']?.toString() ?? '50');
    final imagemCtrl = TextEditingController(text: produto?['imagem_url'] ?? '');
    final categoriaCtrl = TextEditingController(text: produto?['categoria_id']?.toString() ?? '1');

    bool isDestaque = produto?['destaque'] ?? false;
    bool isMaisVendido = produto?['mais_vendido'] ?? false;
    bool isAtivo = produto?['ativo'] ?? true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return AlertDialog(
              title: Text(isEdicao ? 'Editar Produto' : 'Novo Produto', style: const TextStyle(fontWeight: FontWeight.bold)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              content: SizedBox(
                width: 600,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nomeCtrl,
                        decoration: const InputDecoration(labelText: 'Nome do Produto', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: descricaoCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Descrição do Produto',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: TextField(controller: precoCtrl, decoration: const InputDecoration(labelText: 'Preço Normal (R\$)', border: OutlineInputBorder()))),
                          const SizedBox(width: 12),
                          Expanded(child: TextField(controller: precoClubeCtrl, decoration: const InputDecoration(labelText: 'Preço Clube (R\$)', border: OutlineInputBorder()))),
                          const SizedBox(width: 12),
                          Expanded(child: TextField(controller: unidadeCtrl, decoration: const InputDecoration(labelText: 'Unidade (un, kg)', border: OutlineInputBorder()))),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: TextField(controller: estoqueCtrl, decoration: const InputDecoration(labelText: 'Estoque', border: OutlineInputBorder()))),
                          const SizedBox(width: 12),
                          Expanded(child: TextField(controller: categoriaCtrl, decoration: const InputDecoration(labelText: 'ID da Categoria', border: OutlineInputBorder()))),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: imagemCtrl,
                        decoration: const InputDecoration(labelText: 'URL da Imagem', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Wrap(
                          spacing: 20,
                          runSpacing: 10,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Switch(
                                  value: isDestaque,
                                  onChanged: (val) => setStateModal(() => isDestaque = val),
                                  activeColor: Colors.amber.shade700,
                                ),
                                const Text('Destaque', style: TextStyle(fontWeight: FontWeight.w600)),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Switch(
                                  value: isMaisVendido,
                                  onChanged: (val) => setStateModal(() => isMaisVendido = val),
                                  activeColor: Colors.deepOrange,
                                ),
                                const Text('Mais Vendido', style: TextStyle(fontWeight: FontWeight.w600)),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Switch(
                                  value: isAtivo,
                                  onChanged: (val) => setStateModal(() => isAtivo = val),
                                  activeColor: Colors.green,
                                ),
                                const Text('Ativo', style: TextStyle(fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  onPressed: () async {
                    final payload = {
                      "nome": nomeCtrl.text,
                      "descricao": descricaoCtrl.text,
                      "preco": double.tryParse(precoCtrl.text.replaceAll(',', '.')) ?? 0.0,
                      "preco_clube": precoClubeCtrl.text.isEmpty ? null : double.tryParse(precoClubeCtrl.text.replaceAll(',', '.')),
                      "unidade": unidadeCtrl.text,
                      "estoque": int.tryParse(estoqueCtrl.text) ?? 0,
                      "imagem_url": imagemCtrl.text,
                      "categoria_id": int.tryParse(categoriaCtrl.text) ?? 1,
                      "destaque": isDestaque,
                      "mais_vendido": isMaisVendido,
                      "ativo": isAtivo
                    };

                    try {
                      http.Response response;
                      if (isEdicao) {
                        response = await http.put(
                          Uri.parse('${widget.baseUrl}/admin/produtos/${produto['id']}'),
                          headers: {'Content-Type': 'application/json'},
                          body: jsonEncode(payload),
                        );
                      } else {
                        response = await http.post(
                          Uri.parse('${widget.baseUrl}/admin/produtos/'),
                          headers: {'Content-Type': 'application/json'},
                          body: jsonEncode(payload),
                        );
                      }

                      if (response.statusCode == 200 || response.statusCode == 201) {
                        Navigator.pop(context);
                        _carregarDadosIniciais();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(isEdicao ? 'Produto atualizado!' : 'Produto criado!'), backgroundColor: Colors.green),
                        );
                      } else {
                        String mensagemErro = 'Erro HTTP ${response.statusCode}';
                        try {
                          final erroJson = jsonDecode(response.body);
                          mensagemErro = erroJson['detail'] != null ? erroJson['detail'].toString() : erroJson.toString();
                        } catch (_) {
                          if (response.body.isNotEmpty) mensagemErro = response.body;
                        }

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(mensagemErro), backgroundColor: Colors.red.shade900, duration: const Duration(seconds: 5)),
                        );
                      }
                    } catch (e) {
                      debugPrint('Erro crítico ao salvar: $e');
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Erro de conexão: $e'), backgroundColor: Colors.red.shade900),
                        );
                      }
                    }
                  },
                  child: const Text('Salvar Produto', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // 🌟 Filtra os produtos com base na categoria selecionada
    final produtosFiltrados = _produtos.where((produto) {
      if (_categoriaSelecionada == 'Todas') return true;
      // Compara pelo nome da categoria (garanta que o JSON do produto traga o 'categoria_nome' ou 'categoria')
      // Caso o seu backend retorne apenas o ID, podemos comparar com o ID da categoria correspondente.
      final catNome = produto['categoria_nome'] ?? produto['categoria']?['nome'] ?? '';
      return catNome == _categoriaSelecionada;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho da Aba
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Gestão de Produtos', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
                  SizedBox(height: 4),
                  Text('Controle o catálogo, estoque e os preços exclusivos do clube Box Prime.', style: TextStyle(color: Colors.grey)),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _exibirFormularioProduto(),
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('Novo Produto', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 🌟 BARRA DE FILTRO POR CATEGORIAS (Horizontal)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: const Text('Todas'),
                    selected: _categoriaSelecionada == 'Todas',
                    selectedColor: const Color(0xFF1E3A8A),
                    labelStyle: TextStyle(
                      color: _categoriaSelecionada == 'Todas' ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
                    onSelected: (selected) {
                      setState(() => _categoriaSelecionada = 'Todas');
                    },
                  ),
                ),
                ..._categorias.map((cat) {
                  final nomeCat = cat['nome'] ?? '';
                  final selecionado = _categoriaSelecionada == nomeCat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(nomeCat),
                      selected: selecionado,
                      selectedColor: const Color(0xFF1E3A8A),
                      labelStyle: TextStyle(
                        color: selecionado ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                      onSelected: (selected) {
                        setState(() => _categoriaSelecionada = nomeCat);
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Tabela de Dados Atualizada com os Produtos Filtrados
          Expanded(
            child: _carregando
                ? const Center(child: CircularProgressIndicator())
                : produtosFiltrados.isEmpty
                ? const Center(child: Text('Nenhum produto encontrado para esta categoria.'))
                : Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.resolveWith((states) => Colors.grey.shade50),
                    columns: const [
                      DataColumn(label: Text('ID', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Produto', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Preço Padrão', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Preço Prime', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Unidade', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Ações', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: produtosFiltrados.map((produto) {
                      final preco = produto['preco'] != null ? double.parse(produto['preco'].toString()).toStringAsFixed(2) : '0.00';
                      final precoClube = produto['preco_clube'] != null ? double.parse(produto['preco_clube'].toString()).toStringAsFixed(2) : '-';

                      return DataRow(
                        cells: [
                          DataCell(Text(produto['id'].toString(), style: const TextStyle(color: Colors.grey))),
                          DataCell(
                            Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  margin: const EdgeInsets.only(right: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: produto['imagem_url'] != null && produto['imagem_url'].toString().isNotEmpty
                                      ? Image.network(produto['imagem_url'], fit: BoxFit.contain, errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 20, color: Colors.grey))
                                      : const Icon(Icons.inventory_2, color: Colors.grey, size: 20),
                                ),
                                SizedBox(
                                  width: 250,
                                  child: Text(produto['nome'] ?? 'Sem nome', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500)),
                                ),
                              ],
                            ),
                          ),
                          DataCell(Text('R\$ $preco')),
                          DataCell(
                            produto['preco_clube'] != null
                                ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(4)),
                              child: Text('R\$ $precoClube', style: TextStyle(color: Colors.amber.shade900, fontWeight: FontWeight.bold)),
                            )
                                : const Text('-', style: TextStyle(color: Colors.grey)),
                          ),
                          DataCell(Text(produto['unidade'] ?? 'un')),
                          DataCell(
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                                  tooltip: 'Editar Produto',
                                  onPressed: () => _exibirFormularioProduto(produto),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  tooltip: 'Remover Produto',
                                  onPressed: () {
                                    // Função de deletar
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}