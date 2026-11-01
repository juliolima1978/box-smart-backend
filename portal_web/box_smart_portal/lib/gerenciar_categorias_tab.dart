import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class GerenciarCategoriasTab extends StatefulWidget {
  final String baseUrl;
  final String token;

  const GerenciarCategoriasTab({
    super.key,
    required this.baseUrl,
    required this.token,
  });

  @override
  State<GerenciarCategoriasTab> createState() => _GerenciarCategoriasTabState();
}

class _GerenciarCategoriasTabState extends State<GerenciarCategoriasTab> {
  List<dynamic> _categorias = [];
  bool _isLoading = true;
  bool _mostrarFiltros = true; // 👁️ Estado para alternar a visibilidade do topo

  final TextEditingController _buscaController = TextEditingController();
  String _termoBusca = '';

  @override
  void initState() {
    super.initState();
    _carregarCategorias();
  }

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  Future<void> _carregarCategorias() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('${widget.baseUrl}/admin/categorias/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _categorias = jsonDecode(response.body) ?? [];
          _isLoading = false;
        });
      } else {
        _mostrarErro('Erro ao carregar categorias: ${response.statusCode}');
      }
    } catch (e) {
      _mostrarErro('Erro de conexão: $e');
    }
  }

  Future<void> _deletarCategoria(int id, String nome) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Excluir Categoria'),
          ],
        ),
        content: Text('Tem certeza que deseja apagar a categoria "$nome"? Isso pode afetar os produtos vinculados a ela.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      final response = await http.delete(
        Uri.parse('${widget.baseUrl}/admin/categorias/$id'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      if (response.statusCode == 204 || response.statusCode == 200) {
        _mostrarSucesso('Categoria "$nome" excluída com sucesso!');
        _carregarCategorias();
      } else {
        _mostrarErro('Erro ao excluir: ${response.body}');
      }
    } catch (e) {
      _mostrarErro('Erro de conexão: $e');
    }
  }

  void _exibirFormularioCategoria([Map<String, dynamic>? categoria]) {
    final bool isEdicao = categoria != null;
    final nomeCtrl = TextEditingController(text: categoria?['nome'] ?? '');
    final imagemUrlCtrl = TextEditingController(text: categoria?['imagem_url'] ?? '');
    final corCtrl = TextEditingController(text: categoria?['cor_icone'] ?? '');
    final corFundoCtrl = TextEditingController(text: categoria?['cor_fundo'] ?? '');
    final corTextoCtrl = TextEditingController(text: categoria?['cor_texto'] ?? '');
    final ordemCtrl = TextEditingController(text: categoria?['ordem']?.toString() ?? '0');
    bool ativa = categoria?['ativo'] ?? true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                isEdicao ? 'Editar Categoria' : 'Nova Categoria',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nomeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nome da Categoria *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.category_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: ordemCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Posição no Menu (Ex: 0, 1, 2...)',
                          hintText: '0 é a primeira posição',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.format_list_numbered_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: imagemUrlCtrl,
                        decoration: const InputDecoration(
                          labelText: 'URL da Imagem (Opcional)',
                          hintText: 'https://exemplo.com/icone.png',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.image_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: corCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Cor do Ícone (Hex)',
                                hintText: '#1E3A8A',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.palette_outlined),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: corFundoCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Cor de Fundo (Hex)',
                                hintText: '#E3F2FD',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.format_color_fill_outlined),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: corTextoCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Cor do Texto (Hex, ex: #333333)',
                          hintText: '#333333',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.text_fields_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        activeColor: const Color(0xFF1E3A8A),
                        title: const Text('Categoria Ativa no Menu', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: const Text('Se desativado, o botão não aparecerá no aplicativo do cliente.'),
                        value: ativa,
                        onChanged: (val) => setStateModal(() => ativa = val),
                        contentPadding: EdgeInsets.zero,
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    if (nomeCtrl.text.trim().isEmpty) {
                      _mostrarErro('O nome da categoria é obrigatório.');
                      return;
                    }

                    final payload = {
                      "nome": nomeCtrl.text.trim(),
                      "imagem_url": imagemUrlCtrl.text.trim().isEmpty ? null : imagemUrlCtrl.text.trim(),
                      "cor_icone": corCtrl.text.trim().isEmpty ? null : corCtrl.text.trim(),
                      "cor_fundo": corFundoCtrl.text.trim().isEmpty ? null : corFundoCtrl.text.trim(),
                      "cor_texto": corTextoCtrl.text.trim().isEmpty ? null : corTextoCtrl.text.trim(),
                      "ativo": ativa,
                      "ordem": int.tryParse(ordemCtrl.text) ?? 0,
                    };

                    try {
                      http.Response response;
                      if (isEdicao) {
                        response = await http.put(
                          Uri.parse('${widget.baseUrl}/admin/categorias/${categoria['id']}'),
                          headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${widget.token}'},
                          body: jsonEncode(payload),
                        );
                      } else {
                        response = await http.post(
                          Uri.parse('${widget.baseUrl}/admin/categorias/'),
                          headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${widget.token}'},
                          body: jsonEncode(payload),
                        );
                      }

                      if (response.statusCode == 200 || response.statusCode == 201) {
                        if (!mounted) return;
                        Navigator.pop(context);
                        _mostrarSucesso(isEdicao ? 'Categoria atualizada com sucesso!' : 'Categoria criada com sucesso!');
                        _carregarCategorias();
                      } else {
                        _mostrarErro('Erro ${response.statusCode}: ${response.body}');
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

  Color _parseCor(String? hexColor, Color corPadrao) {
    if (hexColor == null || hexColor.isEmpty) return corPadrao;
    try {
      String hex = hexColor.replaceAll('#', '').trim();
      var buffer = StringBuffer();

      if (hex.length == 6) {
        buffer.write('ff');
        buffer.write(hex);
        return Color(int.parse(buffer.toString(), radix: 16));
      } else if (hex.length == 8) {
        buffer.write(hex);
        return Color(int.parse(buffer.toString(), radix: 16));
      }
    } catch (_) {}

    return corPadrao;
  }

  void _mostrarErro(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensagem), backgroundColor: const Color(0xFFB91C1C)));
  }

  void _mostrarSucesso(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensagem), backgroundColor: const Color(0xFF10B981)));
  }

  int get _totalCategorias => _categorias.length;
  int get _totalAtivas => _categorias.where((c) => (c['ativo'] ?? true) == true).length;
  int get _totalOcultas => _categorias.where((c) => (c['ativo'] ?? true) == false).length;

  @override
  Widget build(BuildContext context) {
    final categoriasFiltradas = _categorias.where((cat) {
      if (_termoBusca.isEmpty) return true;
      String nome = (cat['nome'] ?? '').toString().toLowerCase();
      return nome.contains(_termoBusca.toLowerCase());
    }).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 👁️ PAINEL SUPERIOR COLAPSÁVEL (Cabeçalho, KPIs e Busca)
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 250),
            crossFadeState: _mostrarFiltros ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            firstChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. CABEÇALHO 100% RESPONSIVO
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Gerenciar Categorias',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: -0.4),
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Organize os departamentos e seções exibidos no aplicativo.',
                            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      children: [
                        // 👁️ BOTÃO DE OLHO
                        IconButton(
                          icon: Icon(
                            _mostrarFiltros ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                            color: const Color(0xFF334155),
                          ),
                          tooltip: _mostrarFiltros ? 'Ocultar Cabeçalho/Filtros' : 'Mostrar Cabeçalho/Filtros',
                          onPressed: () {
                            setState(() {
                              _mostrarFiltros = !_mostrarFiltros;
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E3A8A),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                          onPressed: () => _exibirFormularioCategoria(),
                          icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                          label: const Text('Nova Categoria', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 2. CARDS KPIS
                _buildKpiGrid(),
                const SizedBox(height: 14),

                // 3. BARRA DE BUSCA
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _buscaController,
                          decoration: InputDecoration(
                            hintText: 'Buscar categoria por nome...',
                            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                            prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B)),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1E3A8A), width: 1.5)),
                          ),
                          onChanged: (valor) {
                            setState(() => _termoBusca = valor.trim());
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded, color: Color(0xFF334155)),
                        onPressed: _carregarCategorias,
                        tooltip: 'Atualizar Categorias',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],
            ),
            secondChild: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // 👁️ Botão de olho flutuante quando o topo estiver oculto
                TextButton.icon(
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                  onPressed: () {
                    setState(() {
                      _mostrarFiltros = !_mostrarFiltros;
                    });
                  },
                  icon: const Icon(Icons.visibility_rounded, color: Color(0xFF1E3A8A), size: 18),
                  label: const Text('Mostrar Cabeçalho e Filtros', style: TextStyle(color: Color(0xFF1E3A8A), fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),

          // 4. LISTAGEM DE CATEGORIAS EMPILHADA (Expandida para ocupar o espaço livre)
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E3A8A)))
                  : categoriasFiltradas.isEmpty
                  ? const Center(child: Text('Nenhuma categoria encontrada.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 15)))
                  : ListView.separated(
                itemCount: categoriasFiltradas.length,
                separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                itemBuilder: (context, index) {
                  final cat = categoriasFiltradas[index];
                  final int id = cat['id'] ?? 0;
                  final String? imagemUrl = cat['imagem_url'];
                  final String? corHex = cat['cor_icone'];
                  final String? corFundoHex = cat['cor_fundo'];

                  final Color corIcone = _parseCor(corHex, const Color(0xFF1E3A8A));
                  final Color corFundo = _parseCor(corFundoHex, const Color(0xFFEFF6FF));

                  final int ordem = cat['ordem'] ?? 0;
                  final bool ativa = cat['ativo'] ?? true;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Ícone / Imagem da Categoria
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: corFundo,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: (imagemUrl != null && imagemUrl.startsWith('http'))
                              ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              imagemUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(Icons.storefront_rounded, color: corIcone, size: 22),
                            ),
                          )
                              : Icon(Icons.storefront_rounded, color: corIcone, size: 22),
                        ),
                        const SizedBox(width: 12),

                        // 🌟 ESTRUTURA VERTICAL EMPILHADA SEGURA
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                cat['nome'] ?? 'Categoria',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Color(0xFF1E293B),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),

                              // Linha de Detalhes (ID e Ordem)
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'ID: $id',
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Ordem: $ordem',
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // Linha Inferior: Badge de Status e Botões de Ação
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: ativa ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: ativa ? const Color(0xFFA7F3D0) : const Color(0xFFFCA5A5)),
                                    ),
                                    child: Text(
                                      ativa ? 'Ativo' : 'Oculto',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: ativa ? const Color(0xFF047857) : const Color(0xFFB91C1C),
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        height: 28,
                                        width: 28,
                                        child: IconButton(
                                          style: IconButton.styleFrom(
                                            backgroundColor: const Color(0xFFEFF6FF),
                                            padding: EdgeInsets.zero,
                                          ),
                                          icon: const Icon(Icons.edit_outlined, color: Color(0xFF1E3A8A), size: 15),
                                          tooltip: 'Editar',
                                          onPressed: () => _exibirFormularioCategoria(cat),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      SizedBox(
                                        height: 28,
                                        width: 28,
                                        child: IconButton(
                                          style: IconButton.styleFrom(
                                            backgroundColor: const Color(0xFFFEF2F2),
                                            padding: EdgeInsets.zero,
                                          ),
                                          icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 15),
                                          tooltip: 'Excluir',
                                          onPressed: () => _deletarCategoria(id, cat['nome'] ?? ''),
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

  Widget _buildKpiGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        bool isPequeno = constraints.maxWidth < 800;
        final cards = [
          _buildKpiCard('Total Categorias', '$_totalCategorias registradas', 'Departamentos cadastrados', Icons.category_rounded, const Color(0xFF1E3A8A), const Color(0xFFEFF6FF)),
          _buildKpiCard('Categorias Ativas', '$_totalAtivas visíveis', 'Exibidas no aplicativo', Icons.visibility_rounded, const Color(0xFF10B981), const Color(0xFFECFDF5)),
          _buildKpiCard('Categorias Ocultas', '$_totalOcultas ocultas', 'Desativadas no menu', Icons.visibility_off_rounded, const Color(0xFFEF4444), const Color(0xFFFEF2F2)),
        ];

        if (isPequeno) {
          return Column(
            children: [
              Row(children: [Expanded(child: cards[0]), const SizedBox(width: 12), Expanded(child: cards[1])]),
              const SizedBox(height: 12),
              cards[2],
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: cards[0]), const SizedBox(width: 12),
            Expanded(child: cards[1]), const SizedBox(width: 12),
            Expanded(child: cards[2]),
          ],
        );
      },
    );
  }

  Widget _buildKpiCard(String title, String value, String subtitle, IconData icon, Color color, Color bgColor) {
    return Container(
      padding: const EdgeInsets.all(16),
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
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
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