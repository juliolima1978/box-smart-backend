import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

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
  List<dynamic> _subcategorias = [];
  bool _isLoading = true;
  bool _mostrarKpis = true; // 🌟 Controle para expandir/colapsar os KPIs e maximizar a área dos produtos

  final TextEditingController _buscaController = TextEditingController();
  String _termoBusca = '';

  // 🌟 Filtros
  int? _categoriaFiltroId;
  bool _filtroSemFoto = false;
  bool _filtroComClube = false;

  final NumberFormat _formatoMoeda = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$',
  );

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  Future<void> _carregarDados() async {
    setState(() => _isLoading = true);
    try {
      final responses = await Future.wait([
        http.get(
          Uri.parse('${widget.baseUrl}/api/produtos/?sem_foto=$_filtroSemFoto'),
          headers: {'Authorization': 'Bearer ${widget.token}'},
        ),
        http.get(
          Uri.parse('${widget.baseUrl}/admin/categorias/'),
          headers: {'Authorization': 'Bearer ${widget.token}'},
        ),
        http.get(
          Uri.parse('${widget.baseUrl}/admin/subcategorias/'),
          headers: {'Authorization': 'Bearer ${widget.token}'},
        ),
      ]);

      if (!mounted) return;

      if (responses[0].statusCode == 200 && responses[1].statusCode == 200) {
        setState(() {
          _produtos = jsonDecode(responses[0].body) ?? [];
          _categorias = jsonDecode(responses[1].body) ?? [];
          if (responses[2].statusCode == 200) {
            _subcategorias = jsonDecode(responses[2].body) ?? [];
          }
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        _mostrarErro('Erro ao carregar dados do servidor.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _mostrarErro('Erro de conexão: $e');
      }
    }
  }

  Future<void> _deletarProduto(int id, String nome) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Confirmar Exclusão'),
          ],
        ),
        content: Text('Deseja realmente remover o produto "$nome"? Esta ação não poderá ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () {
              FocusScope.of(context).unfocus();
              Navigator.pop(context);
            },
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              FocusScope.of(context).unfocus();
              Navigator.pop(context);
              try {
                final response = await http.delete(
                  Uri.parse('${widget.baseUrl}/admin/produtos/$id'),
                  headers: {'Authorization': 'Bearer ${widget.token}'},
                );

                if (response.statusCode == 200 || response.statusCode == 204) {
                  _mostrarSucesso('Produto excluído com sucesso!');
                  _carregarDados();
                } else {
                  _mostrarErro('Erro ao excluir produto.');
                }
              } catch (e) {
                _mostrarErro('Erro de conexão: $e');
              }
            },
            child: const Text('Excluir', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _exibirFormularioProduto({Map<String, dynamic>? produtoExistente}) {
    final nomeCtrl = TextEditingController(text: produtoExistente?['nome'] ?? '');
    final descCtrl = TextEditingController(text: produtoExistente?['descricao'] ?? '');
    final precoCtrl = TextEditingController(
      text: produtoExistente?['preco'] != null ? produtoExistente!['preco'].toString().replaceAll('.', ',') : '',
    );
    final precoClubeCtrl = TextEditingController(
      text: produtoExistente?['preco_clube'] != null ? produtoExistente!['preco_clube'].toString().replaceAll('.', ',') : '',
    );
    final estoqueCtrl = TextEditingController(text: produtoExistente?['estoque']?.toString() ?? '50');
    final imagemCtrl = TextEditingController(text: produtoExistente?['imagem_url'] ?? '');

    int? categoriaIdSelecionada = produtoExistente?['categoria_id'] ?? (_categorias.isNotEmpty ? _categorias[0]['id'] : null);
    int? subcategoriaIdSelecionada = produtoExistente?['subcategoria_id'];

    String unidadeSelecionada = produtoExistente?['unidade'] ?? 'un';
    bool destaque = produtoExistente?['destaque'] ?? false;
    bool maisVendido = produtoExistente?['mais_vendido'] ?? false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            final subcategoriasFiltradas = _subcategorias.where((sub) => sub['categoria_id'] == categoriaIdSelecionada).toList();

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                produtoExistente == null ? 'Cadastrar Novo Produto' : 'Editar Produto e Imagem',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              content: SizedBox(
                width: 620,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nomeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nome do Produto *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.shopping_bag_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Descrição',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.description_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: precoCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Preço Normal (R\$) *',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.attach_money_rounded),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: precoClubeCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Preço Clube (R\$)',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.workspace_premium_rounded),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: estoqueCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Estoque *',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.inventory_2_outlined),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: unidadeSelecionada,
                              decoration: const InputDecoration(
                                labelText: 'Unidade de Medida',
                                border: OutlineInputBorder(),
                              ),
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
                      DropdownButtonFormField<int>(
                        value: categoriaIdSelecionada,
                        decoration: const InputDecoration(
                          labelText: 'Categoria *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.category_outlined),
                        ),
                        items: _categorias.map<DropdownMenuItem<int>>((cat) {
                          return DropdownMenuItem<int>(
                            value: cat['id'],
                            child: Text(cat['nome']),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setStateModal(() {
                            categoriaIdSelecionada = val;
                            subcategoriaIdSelecionada = null;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int?>(
                        value: subcategoriaIdSelecionada,
                        decoration: const InputDecoration(
                          labelText: 'Subcategoria (Segmento)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.segment_outlined),
                        ),
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
                      TextField(
                        controller: imagemCtrl,
                        decoration: const InputDecoration(
                          labelText: 'URL da Imagem do Produto (Imgur, etc.)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.image_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        activeColor: const Color(0xFF1E3A8A),
                        title: const Text('Produto em Destaque', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: const Text('Exibir na seção de produtos em destaque na Home'),
                        value: destaque,
                        onChanged: (val) => setStateModal(() => destaque = val),
                      ),
                      SwitchListTile(
                        activeColor: const Color(0xFF1E3A8A),
                        title: const Text('Mais Vendido', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: const Text('Destacar badge de mais procurado pelos clientes'),
                        value: maisVendido,
                        onChanged: (val) => setStateModal(() => maisVendido = val),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    FocusScope.of(context).unfocus();
                    Navigator.pop(context);
                  },
                  child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    FocusScope.of(context).unfocus();

                    if (nomeCtrl.text.trim().isEmpty || precoCtrl.text.trim().isEmpty || categoriaIdSelecionada == null) {
                      _mostrarErro('Preencha os campos obrigatórios (Nome, Preço e Categoria).');
                      return;
                    }

                    final double? precoParsed = double.tryParse(precoCtrl.text.replaceAll(',', '.'));
                    final double? precoClubeParsed = precoClubeCtrl.text.trim().isNotEmpty
                        ? double.tryParse(precoClubeCtrl.text.replaceAll(',', '.'))
                        : null;

                    if (precoParsed == null || precoParsed <= 0) {
                      _mostrarErro('Informe um preço válido.');
                      return;
                    }

                    final payload = {
                      "nome": nomeCtrl.text.trim(),
                      "descricao": descCtrl.text.trim(),
                      "preco": precoParsed,
                      "preco_clube": precoClubeParsed,
                      "unidade": unidadeSelecionada,
                      "estoque": int.tryParse(estoqueCtrl.text) ?? 50,
                      "imagem_url": imagemCtrl.text.trim().isNotEmpty ? imagemCtrl.text.trim() : null,
                      "categoria_id": categoriaIdSelecionada,
                      "subcategoria_id": subcategoriaIdSelecionada,
                      "destaque": destaque,
                      "mais_vendido": maisVendido,
                      "ativo": true,
                    };

                    try {
                      final url = produtoExistente == null
                          ? '${widget.baseUrl}/admin/produtos/'
                          : '${widget.baseUrl}/admin/produtos/${produtoExistente['id']}';

                      final response = produtoExistente == null
                          ? await http.post(
                        Uri.parse(url),
                        headers: {
                          'Content-Type': 'application/json',
                          'Authorization': 'Bearer ${widget.token}',
                        },
                        body: jsonEncode(payload),
                      )
                          : await http.put(
                        Uri.parse(url),
                        headers: {
                          'Content-Type': 'application/json',
                          'Authorization': 'Bearer ${widget.token}',
                        },
                        body: jsonEncode(payload),
                      );

                      if (response.statusCode == 200 || response.statusCode == 201) {
                        if (!mounted) return;
                        Navigator.pop(context);
                        _mostrarSucesso('Produto salvo com sucesso!');
                        _carregarDados();
                      } else {
                        _mostrarErro('Erro ao salvar produto.');
                      }
                    } catch (e) {
                      _mostrarErro('Erro de conexão: $e');
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

  void _mostrarErro(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem), backgroundColor: const Color(0xFFB91C1C)),
    );
  }

  void _mostrarSucesso(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem), backgroundColor: const Color(0xFF10B981)),
    );
  }

  int get _totalProdutos => _produtos.length;
  int get _totalEstoqueCritico => _produtos.where((p) => (int.tryParse(p['estoque']?.toString() ?? '0') ?? 0) <= 5).length;
  int get _totalOfertasClube => _produtos.where((p) {
    final rawClube = p['preco_clube'];
    if (rawClube == null) return false;
    final double val = double.tryParse(rawClube.toString().replaceAll(',', '.')) ?? 0.0;
    return val > 0;
  }).length;

  double get _valorTotalEstoque {
    double total = 0.0;
    for (var p in _produtos) {
      double preco = double.tryParse(p['preco']?.toString() ?? '0') ?? 0.0;
      int qtd = int.tryParse(p['estoque']?.toString() ?? '0') ?? 0;
      total += (preco * qtd);
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final produtosFiltrados = _produtos.where((p) {
      bool atendeBusca = true;
      if (_termoBusca.isNotEmpty) {
        String nome = (p['nome'] ?? '').toString().toLowerCase();
        atendeBusca = nome.contains(_termoBusca.toLowerCase());
      }

      bool atendeCategoria = true;
      if (_categoriaFiltroId != null) {
        atendeCategoria = p['categoria_id'] == _categoriaFiltroId;
      }

      bool atendeClube = true;
      if (_filtroComClube) {
        final rawClube = p['preco_clube'];
        final double valClube = rawClube != null ? (double.tryParse(rawClube.toString().replaceAll(',', '.')) ?? 0.0) : 0.0;
        atendeClube = valClube > 0;
      }

      return atendeBusca && atendeCategoria && atendeClube;
    }).toList();

    return Padding(
      // Padding externo levemente reduzido para aproveitar mais espaço
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. CABEÇALHO
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gestão de Produtos e Curadoria',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.4,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Organize preços, estoque e faça a curadoria visual do catálogo.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                onPressed: () => _exibirFormularioProduto(),
                icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                label: const Text(
                  'Novo Produto',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 2. CARDS KPIS (Agora colapsáveis para maximizar a área de produtos)
          if (_mostrarKpis) ...[
            _buildKpiGrid(),
            const SizedBox(height: 14),
          ],

          // 3. PAINEL DE FERRAMENTAS E FILTROS
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _buscaController,
                        decoration: InputDecoration(
                          hintText: 'Buscar produto por nome...',
                          hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B)),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFF1E3A8A), width: 1.5),
                          ),
                        ),
                        onChanged: (valor) {
                          setState(() => _termoBusca = valor.trim());
                        },
                      ),
                    ),
                    const SizedBox(width: 12),

                    // 🌟 BOTÃO DE FILTRO DE PREÇO CLUBE
                    FilterChip(
                      avatar: Icon(
                        Icons.workspace_premium_rounded,
                        size: 16,
                        color: _filtroComClube ? Colors.white : const Color(0xFFD97706),
                      ),
                      label: Text(_filtroComClube ? 'Com Preço Clube ($_totalOfertasClube)' : 'Apenas Preço Clube'),
                      selected: _filtroComClube,
                      selectedColor: const Color(0xFFD97706),
                      backgroundColor: const Color(0xFFFEF3C7),
                      labelStyle: TextStyle(
                        color: _filtroComClube ? Colors.white : const Color(0xFF92400E),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      showCheckmark: false,
                      onSelected: (selected) {
                        setState(() => _filtroComClube = selected);
                      },
                    ),
                    const SizedBox(width: 8),

                    // 🌟 BOTÃO DE CURADORIA RÁPIDA (FILTRO DE SEM FOTO)
                    FilterChip(
                      avatar: Icon(
                        Icons.image_not_supported_outlined,
                        size: 16,
                        color: _filtroSemFoto ? Colors.white : const Color(0xFF1E3A8A),
                      ),
                      label: const Text('Apenas Sem Foto / Pendentes'),
                      selected: _filtroSemFoto,
                      selectedColor: const Color(0xFF1E3A8A),
                      backgroundColor: const Color(0xFFEFF6FF),
                      labelStyle: TextStyle(
                        color: _filtroSemFoto ? Colors.white : const Color(0xFF1E3A8A),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      showCheckmark: false,
                      onSelected: (selected) {
                        setState(() => _filtroSemFoto = selected);
                        _carregarDados();
                      },
                    ),
                    const SizedBox(width: 8),

                    // 🌟 BOTÃO PARA OCULTAR/MOSTRAR OS KPIS (MAXIMIZAR ESPAÇO)
                    IconButton(
                      style: IconButton.styleFrom(
                        backgroundColor: _mostrarKpis ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
                      ),
                      icon: Icon(
                        _mostrarKpis ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: const Color(0xFF1E3A8A),
                        size: 20,
                      ),
                      onPressed: () => setState(() => _mostrarKpis = !_mostrarKpis),
                      tooltip: _mostrarKpis ? 'Ocultar Resumo e Expandir Produtos' : 'Mostrar Resumo (KPIs)',
                    ),
                    const SizedBox(width: 4),

                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: Color(0xFF334155)),
                      onPressed: _carregarDados,
                      tooltip: 'Atualizar Lista',
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Chips de Categorias
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: const Text('Todas'),
                          selected: _categoriaFiltroId == null,
                          selectedColor: const Color(0xFF1E3A8A),
                          backgroundColor: const Color(0xFFF1F5F9),
                          labelStyle: TextStyle(
                            color: _categoriaFiltroId == null ? Colors.white : const Color(0xFF475569),
                            fontWeight: _categoriaFiltroId == null ? FontWeight.bold : FontWeight.w500,
                            fontSize: 12,
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide.none),
                          showCheckmark: false,
                          onSelected: (selected) {
                            setState(() => _categoriaFiltroId = null);
                          },
                        ),
                      ),
                      ..._categorias.map((cat) {
                        final bool selecionado = _categoriaFiltroId == cat['id'];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(cat['nome']),
                            selected: selecionado,
                            selectedColor: const Color(0xFF1E3A8A),
                            backgroundColor: const Color(0xFFF1F5F9),
                            labelStyle: TextStyle(
                              color: selecionado ? Colors.white : const Color(0xFF475569),
                              fontWeight: selecionado ? FontWeight.bold : FontWeight.w500,
                              fontSize: 12,
                            ),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide.none),
                            showCheckmark: false,
                            onSelected: (selected) {
                              setState(() => _categoriaFiltroId = cat['id']);
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 4. TABELA / LISTAGEM DE PRODUTOS (Área Expandida)
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E3A8A)))
                  : produtosFiltrados.isEmpty
                  ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_off_rounded, size: 48, color: Color(0xFF94A3B8)),
                    SizedBox(height: 12),
                    Text(
                      'Nenhum produto encontrado com os filtros aplicados.',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              )
                  : ListView.separated(
                itemCount: produtosFiltrados.length,
                separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                itemBuilder: (context, index) {
                  final produto = produtosFiltrados[index];
                  final double preco = double.tryParse(produto['preco']?.toString() ?? '0') ?? 0.0;
                  final double? precoClube = produto['preco_clube'] != null
                      ? double.tryParse(produto['preco_clube'].toString().replaceAll(',', '.'))
                      : null;
                  final int estoque = int.tryParse(produto['estoque']?.toString() ?? '0') ?? 0;
                  final bool estoqueCritico = estoque <= 5;
                  final String imgUrl = produto['imagem_url'] ?? '';
                  final bool semFoto = imgUrl.isEmpty || imgUrl.contains('6tJyuYb.png');

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      children: [
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                width: 60,
                                height: 60,
                                color: const Color(0xFFF8FAFC),
                                child: !semFoto
                                    ? Image.network(
                                  imgUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.broken_image_outlined, color: Colors.grey),
                                )
                                    : const Icon(Icons.add_a_photo_outlined, color: Color(0xFF94A3B8), size: 26),
                              ),
                            ),
                            if (semFoto)
                              Positioned(
                                top: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                  child: const Icon(Icons.priority_high, size: 10, color: Colors.white),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 16),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                produto['nome'] ?? 'Produto',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Color(0xFF1E293B),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    _formatoMoeda.format(preco),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0F172A),
                                      fontSize: 13,
                                    ),
                                  ),
                                  if (precoClube != null && precoClube > 0) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEF3C7),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Clube: ${_formatoMoeda.format(precoClube)}',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFFD97706),
                                        ),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(width: 12),
                                  Text(
                                    'Setor: ${produto['categoria'] ?? 'Geral'}',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),

                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: estoqueCritico ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: estoqueCritico ? const Color(0xFFFCA5A5) : const Color(0xFFA7F3D0),
                                ),
                              ),
                              child: Text(
                                '$estoque ${produto['unidade'] ?? 'un'}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: estoqueCritico ? const Color(0xFFB91C1C) : const Color(0xFF047857),
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            IconButton(
                              style: IconButton.styleFrom(backgroundColor: const Color(0xFFEFF6FF)),
                              icon: const Icon(Icons.edit_outlined, color: Color(0xFF1E3A8A), size: 20),
                              tooltip: 'Editar Produto/Imagem',
                              onPressed: () => _exibirFormularioProduto(produtoExistente: produto),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              style: IconButton.styleFrom(backgroundColor: const Color(0xFFFEF2F2)),
                              icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 20),
                              tooltip: 'Excluir',
                              onPressed: () => _deletarProduto(produto['id'], produto['nome']),
                            ),
                          ],
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

  Widget _buildKpiGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        bool isPequeno = constraints.maxWidth < 900;
        final cards = [
          _buildKpiCard(
            'Total Cadastrados',
            '$_totalProdutos itens',
            'Produtos ativos no catálogo',
            Icons.inventory_2_rounded,
            const Color(0xFF1E3A8A),
            const Color(0xFFEFF6FF),
          ),
          _buildKpiCard(
            'Ofertas Clube',
            '$_totalOfertasClube ofertas',
            'Com preço especial ativado',
            Icons.workspace_premium_rounded,
            const Color(0xFFD97706),
            const Color(0xFFFEF3C7),
          ),
          _buildKpiCard(
            'Estoque Crítico',
            '$_totalEstoqueCritico itens',
            'Produtos com ≤ 5 unidades',
            Icons.warning_amber_rounded,
            const Color(0xFFEF4444),
            const Color(0xFFFEF2F2),
          ),
          _buildKpiCard(
            'Valor em Estoque',
            _formatoMoeda.format(_valorTotalEstoque),
            'Patrimônio em estoque',
            Icons.attach_money_rounded,
            const Color(0xFF10B981),
            const Color(0xFFECFDF5),
          ),
        ];

        if (isPequeno) {
          return Column(
            children: [
              Row(children: [Expanded(child: cards[0]), const SizedBox(width: 12), Expanded(child: cards[1])]),
              const SizedBox(height: 10),
              Row(children: [Expanded(child: cards[2]), const SizedBox(width: 12), Expanded(child: cards[3])]),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: cards[0]), const SizedBox(width: 12),
            Expanded(child: cards[1]), const SizedBox(width: 12),
            Expanded(child: cards[2]), const SizedBox(width: 12),
            Expanded(child: cards[3]),
          ],
        );
      },
    );
  }

  Widget _buildKpiCard(String title, String value, String subtitle, IconData icon, Color color, Color bgColor) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w600)),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color, letterSpacing: -0.4)),
          ),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
        ],
      ),
    );
  }
}