import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class GerenciarSubcategoriasTab extends StatefulWidget {
  final String baseUrl;
  final String token;

  const GerenciarSubcategoriasTab({
    super.key,
    required this.baseUrl,
    required this.token,
  });

  @override
  State<GerenciarSubcategoriasTab> createState() => _GerenciarSubcategoriasTabState();
}

class _GerenciarSubcategoriasTabState extends State<GerenciarSubcategoriasTab> {
  List<dynamic> _subcategorias = [];
  List<dynamic> _categorias = [];
  bool _isLoading = true;

  final TextEditingController _buscaController = TextEditingController();
  String _termoBusca = '';

  // 🌟 Filtro por Categoria Pai (null = "Todas")
  int? _categoriaFiltroId;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    setState(() => _isLoading = true);
    try {
      final responses = await Future.wait([
        http.get(
          Uri.parse('${widget.baseUrl}/admin/subcategorias/'),
          headers: {'Authorization': 'Bearer ${widget.token}'},
        ),
        http.get(
          Uri.parse('${widget.baseUrl}/admin/categorias/'),
          headers: {'Authorization': 'Bearer ${widget.token}'},
        ),
      ]);

      if (responses[0].statusCode == 200 && responses[1].statusCode == 200) {
        setState(() {
          _subcategorias = jsonDecode(responses[0].body) ?? [];
          _categorias = jsonDecode(responses[1].body) ?? [];
          _isLoading = false;
        });
      } else {
        _mostrarErro('Erro ao carregar dados do servidor.');
      }
    } catch (e) {
      _mostrarErro('Erro de conexão: $e');
    }
  }

  Future<void> _deletarSubcategoria(int id, String nome) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Excluir Subcategoria'),
          ],
        ),
        content: Text('Tem certeza que deseja apagar a subcategoria "$nome"?'),
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
        Uri.parse('${widget.baseUrl}/admin/subcategorias/$id'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      if (response.statusCode == 204 || response.statusCode == 200) {
        _mostrarSucesso('Subcategoria "$nome" excluída com sucesso!');
        _carregarDados();
      } else {
        _mostrarErro('Erro ao excluir subcategoria.');
      }
    } catch (e) {
      _mostrarErro('Erro de conexão: $e');
    }
  }

  void _exibirFormularioSubcategoria([Map<String, dynamic>? subcategoria]) {
    final bool isEdicao = subcategoria != null;
    final nomeCtrl = TextEditingController(text: subcategoria?['nome'] ?? '');
    final ordemCtrl = TextEditingController(text: subcategoria?['ordem']?.toString() ?? '0');

    int? categoriaIdSelecionada = subcategoria?['categoria_id'] ?? (_categorias.isNotEmpty ? _categorias[0]['id'] : null);
    bool ativa = subcategoria?['ativo'] ?? true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                isEdicao ? 'Editar Subcategoria' : 'Nova Subcategoria',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              content: SizedBox(
                width: 450,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nomeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nome da Subcategoria (Ex: Frutas, Aves, Bovina) *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.segment_outlined),
                        ),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<int>(
                        value: categoriaIdSelecionada,
                        decoration: const InputDecoration(
                          labelText: 'Categoria Pai (Departamento) *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.category_outlined),
                        ),
                        items: _categorias.map<DropdownMenuItem<int>>((cat) {
                          return DropdownMenuItem<int>(
                            value: cat['id'],
                            child: Text(cat['nome']),
                          );
                        }).toList(),
                        onChanged: (val) => setStateModal(() => categoriaIdSelecionada = val),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: ordemCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Ordem de Exibição',
                          hintText: '0, 1, 2...',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.format_list_numbered_rounded),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SwitchListTile(
                        activeColor: const Color(0xFF1E3A8A),
                        title: const Text('Subcategoria Ativa', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: const Text('Exibir como opção de filtro nos produtos da loja.'),
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
                    if (nomeCtrl.text.trim().isEmpty || categoriaIdSelecionada == null) {
                      _mostrarErro('Preencha o nome e selecione a categoria pai.');
                      return;
                    }

                    final payload = {
                      "nome": nomeCtrl.text.trim(),
                      "categoria_id": categoriaIdSelecionada,
                      "ordem": int.tryParse(ordemCtrl.text) ?? 0,
                      "ativo": ativa,
                    };

                    try {
                      http.Response response;
                      if (isEdicao) {
                        response = await http.put(
                          Uri.parse('${widget.baseUrl}/admin/subcategorias/${subcategoria['id']}'),
                          headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${widget.token}'},
                          body: jsonEncode(payload),
                        );
                      } else {
                        response = await http.post(
                          Uri.parse('${widget.baseUrl}/admin/subcategorias/'),
                          headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${widget.token}'},
                          body: jsonEncode(payload),
                        );
                      }

                      if (response.statusCode == 200 || response.statusCode == 201) {
                        if (!mounted) return;
                        Navigator.pop(context);
                        _mostrarSucesso(isEdicao ? 'Subcategoria atualizada com sucesso!' : 'Subcategoria criada com sucesso!');
                        _carregarDados();
                      } else {
                        _mostrarErro('Erro ao salvar subcategoria.');
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensagem), backgroundColor: const Color(0xFFB91C1C)));
  }

  void _mostrarSucesso(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensagem), backgroundColor: const Color(0xFF10B981)));
  }

  int get _totalSubcategorias => _subcategorias.length;
  int get _totalAtivas => _subcategorias.where((s) => (s['ativo'] ?? true) == true).length;
  int get _totalOcultas => _subcategorias.where((s) => (s['ativo'] ?? true) == false).length;

  @override
  Widget build(BuildContext context) {
    final subcategoriasFiltradas = _subcategorias.where((sub) {
      bool atendeBusca = true;
      if (_termoBusca.isNotEmpty) {
        String nome = (sub['nome'] ?? '').toString().toLowerCase();
        atendeBusca = nome.contains(_termoBusca.toLowerCase());
      }

      bool atendeCategoria = true;
      if (_categoriaFiltroId != null) {
        atendeCategoria = sub['categoria_id'] == _categoriaFiltroId;
      }

      return atendeBusca && atendeCategoria;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(24.0),
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
                    'Gestão de Subcategorias (Segmentos)',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: -0.4),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Subdivida suas categorias principais para facilitar a busca de produtos pelos clientes.',
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
                onPressed: () => _exibirFormularioSubcategoria(),
                icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                label: const Text('Nova Subcategoria', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 2. CARDS KPIs
          _buildKpiGrid(),
          const SizedBox(height: 20),

          // 3. BARRA DE FERRAMENTAS E FILTROS
          Container(
            padding: const EdgeInsets.all(18),
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
                          hintText: 'Buscar subcategoria por nome...',
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
                      onPressed: _carregarDados,
                      tooltip: 'Atualizar Subcategorias',
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // ChoiceChips de Categoria Pai
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: const Text('Todas as Categorias'),
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
          const SizedBox(height: 20),

          // 4. TABELA / LISTAGEM DE SUBCATEGORIAS
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E3A8A)))
                  : subcategoriasFiltradas.isEmpty
                  ? const Center(child: Text('Nenhuma subcategoria encontrada.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 15)))
                  : ListView.separated(
                itemCount: subcategoriasFiltradas.length,
                separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                itemBuilder: (context, index) {
                  final sub = subcategoriasFiltradas[index];
                  final int id = sub['id'] ?? 0;
                  final int ordem = sub['ordem'] ?? 0;
                  final bool ativa = sub['ativo'] ?? true;

                  final categoriaPai = _categorias.firstWhere(
                        (cat) => cat['id'] == sub['categoria_id'],
                    orElse: () => {'nome': 'Geral'},
                  );

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Icon(Icons.subdirectory_arrow_right_rounded, color: Color(0xFF1E3A8A), size: 22),
                    ),
                    title: Text(
                      sub['nome'] ?? 'Subcategoria',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B)),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Categoria Pai: ${categoriaPai['nome']}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
                            ),
                          ),
                          const SizedBox(width: 6),
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
                          const SizedBox(width: 6),
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
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Badge de Status
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: ativa ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: ativa ? const Color(0xFFA7F3D0) : const Color(0xFFFCA5A5)),
                          ),
                          child: Text(
                            ativa ? 'Ativo' : 'Inativo',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: ativa ? const Color(0xFF047857) : const Color(0xFFB91C1C),
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, color: Color(0xFF1E3A8A), size: 20),
                          tooltip: 'Editar',
                          onPressed: () => _exibirFormularioSubcategoria(sub),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 20),
                          tooltip: 'Excluir',
                          onPressed: () => _deletarSubcategoria(id, sub['nome'] ?? ''),
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
          _buildKpiCard('Total Subcategorias', '$_totalSubcategorias registradas', 'Segmentos cadastrados', Icons.segment_rounded, const Color(0xFF1E3A8A), const Color(0xFFEFF6FF)),
          _buildKpiCard('Subcategorias Ativas', '$_totalAtivas visíveis', 'Disponíveis no aplicativo', Icons.visibility_rounded, const Color(0xFF10B981), const Color(0xFFECFDF5)),
          _buildKpiCard('Subcategorias Ocultas', '$_totalOcultas inativas', 'Ocultadas da navegação', Icons.visibility_off_rounded, const Color(0xFFEF4444), const Color(0xFFFEF2F2)),
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