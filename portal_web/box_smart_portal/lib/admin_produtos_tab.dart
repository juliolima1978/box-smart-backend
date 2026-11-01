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
  List<dynamic> _categorias = [];
  bool _carregando = true;
  String _categoriaSelecionada = 'Todas';

  @override
  void initState() {
    super.initState();
    _carregarDadosIniciais();
  }

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

  Future<void> _deletarProduto(int id) async {
    bool confirmar = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: const Text('Deseja realmente excluir este produto do catálogo?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;

    if (!confirmar) return;

    try {
      final response = await http.delete(Uri.parse('${widget.baseUrl}/admin/produtos/$id'));
      if (response.statusCode == 200 || response.statusCode == 204) {
        _carregarDadosIniciais();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Produto excluído com sucesso!'), backgroundColor: Colors.green),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao excluir: ${response.statusCode}'), backgroundColor: Colors.red.shade900),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro de conexão: $e'), backgroundColor: Colors.red.shade900),
      );
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
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A)),
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
                        if (!context.mounted) return;
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

                        if (!context.mounted) return;
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
    final produtosFiltrados = _produtos.where((produto) {
      if (_categoriaSelecionada == 'Todas') return true;
      final catNome = produto['categoria_nome'] ?? produto['categoria']?['nome'] ?? '';
      return catNome == _categoriaSelecionada;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho da Aba
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gestão de Produtos',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: -0.4),
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Controle o catálogo e preços do clube.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                onPressed: () => _exibirFormularioProduto(),
                icon: const Icon(Icons.add, color: Colors.white, size: 16),
                label: const Text('Novo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Barra de filtro por categorias
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 6.0),
                  child: ChoiceChip(
                    label: const Text('Todas', style: TextStyle(fontSize: 11)),
                    selected: _categoriaSelecionada == 'Todas',
                    selectedColor: const Color(0xFF1E3A8A),
                    backgroundColor: const Color(0xFFF1F5F9),
                    labelStyle: TextStyle(
                      color: _categoriaSelecionada == 'Todas' ? Colors.white : const Color(0xFF475569),
                      fontWeight: FontWeight.bold,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide.none),
                    showCheckmark: false,
                    visualDensity: VisualDensity.compact,
                    onSelected: (selected) {
                      setState(() => _categoriaSelecionada = 'Todas');
                    },
                  ),
                ),
                ..._categorias.map((cat) {
                  final nomeCat = cat['nome'] ?? '';
                  final selecionado = _categoriaSelecionada == nomeCat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: ChoiceChip(
                      label: Text(nomeCat, style: const TextStyle(fontSize: 11)),
                      selected: selecionado,
                      selectedColor: const Color(0xFF1E3A8A),
                      backgroundColor: const Color(0xFFF1F5F9),
                      labelStyle: TextStyle(
                        color: selecionado ? Colors.white : const Color(0xFF475569),
                        fontWeight: FontWeight.bold,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide.none),
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact,
                      onSelected: (selected) {
                        setState(() => _categoriaSelecionada = nomeCat);
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Listagem de Produtos com Layout Empilhado (Idêntico ao padrão dos Pedidos)
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: _carregando
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E3A8A)))
                  : produtosFiltrados.isEmpty
                  ? const Center(child: Text('Nenhum produto encontrado.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)))
                  : ListView.separated(
                itemCount: produtosFiltrados.length,
                separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                itemBuilder: (context, index) {
                  final produto = produtosFiltrados[index];
                  final preco = produto['preco'] != null ? double.parse(produto['preco'].toString()).toStringAsFixed(2) : '0.00';
                  final precoClube = produto['preco_clube'] != null ? double.parse(produto['preco_clube'].toString()).toStringAsFixed(2) : null;
                  final estoque = produto['estoque']?.toString() ?? '0';
                  final unidade = produto['unidade'] ?? 'un';
                  final categoriaNome = produto['categoria_nome'] ?? produto['categoria']?['nome'] ?? 'Geral';

                  final estoqueInt = int.tryParse(estoque) ?? 0;
                  final isEstoqueBaixo = estoqueInt <= 5;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Imagem do Produto
                        Container(
                          width: 40,
                          height: 40,
                          margin: const EdgeInsets.only(top: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: produto['imagem_url'] != null && produto['imagem_url'].toString().isNotEmpty
                              ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(produto['imagem_url'], fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 18, color: Colors.grey)),
                          )
                              : const Icon(Icons.inventory_2, color: Color(0xFF64748B), size: 18),
                        ),
                        const SizedBox(width: 12),

                        // 🌟 COLUNA VERTICAL EMPILHADA (Igualzinho à tela de pedidos)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Linha 1: Nome do Produto
                              Text(
                                produto['nome'] ?? 'Sem nome',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),

                              // Linha 2: Preços (Normal e Clube)
                              Row(
                                children: [
                                  Text(
                                    'R\$ $preco',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                  ),
                                  if (precoClube != null) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(4)),
                                      child: Text('Clube: R\$ $precoClube', style: const TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.bold, fontSize: 10)),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),

                              // Linha 3: Categoria / Setor
                              Text(
                                'Setor: $categoriaNome',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),

                              // Linha 4: Estoque à esquerda e Ações (Editar/Excluir) à direita
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isEstoqueBaixo ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
                                      borderRadius: BorderRadius.circular(5),
                                      border: Border.all(color: isEstoqueBaixo ? const Color(0xFFFCA5A5) : const Color(0xFFA7F3D0)),
                                    ),
                                    child: Text(
                                      'Estoque: $estoque $unidade',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isEstoqueBaixo ? const Color(0xFFDC2626) : const Color(0xFF059669),
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: IconButton(
                                          icon: const Icon(Icons.edit_outlined, color: Color(0xFF1E3A8A), size: 16),
                                          tooltip: 'Editar',
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () => _exibirFormularioProduto(produto),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 16),
                                          tooltip: 'Excluir',
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () => _deletarProduto(produto['id']),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
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