import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class GerenciarSecoesTab extends StatefulWidget {
  final String baseUrl;
  final String token;

  const GerenciarSecoesTab({
    super.key,
    required this.baseUrl,
    required this.token,
  });

  @override
  State<GerenciarSecoesTab> createState() => _GerenciarSecoesTabState();
}

class _GerenciarSecoesTabState extends State<GerenciarSecoesTab> {
  List<dynamic> _secoes = [];
  List<dynamic> _produtosLista = [];
  bool _isLoading = true;
  bool _mostrarFiltros = true; // 👁️ Estado para alternar a visibilidade do topo

  final TextEditingController _buscaController = TextEditingController();
  String _termoBusca = '';

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
      final resSecoes = await http.get(
        Uri.parse('${widget.baseUrl}/admin/secoes/'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      final String uriSecoes = resSecoes.statusCode == 200
          ? '${widget.baseUrl}/admin/secoes/'
          : '${widget.baseUrl}/api/home';

      final resFinalSecoes = await http.get(
        Uri.parse(uriSecoes),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      final resProds = await http.get(
        Uri.parse('${widget.baseUrl}/api/produtos/'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      if (mounted) {
        setState(() {
          if (resFinalSecoes.statusCode == 200) {
            _secoes = jsonDecode(resFinalSecoes.body) ?? [];
          }
          if (resProds.statusCode == 200) {
            _produtosLista = jsonDecode(resProds.body) ?? [];
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      _mostrarErro('Erro ao carregar dados: $e');
    }
  }

  Future<void> _deletarSecao(int id, String titulo) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Excluir Seção'),
          ],
        ),
        content: Text('Tem certeza que deseja apagar a seção "$titulo"?'),
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
        Uri.parse('${widget.baseUrl}/admin/secoes/$id'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        _mostrarSucesso('Seção excluída com sucesso!');
        _carregarDados();
      } else {
        _mostrarErro('Erro ao excluir seção: ${response.body}');
      }
    } catch (e) {
      _mostrarErro('Erro de conexão: $e');
    }
  }

  void _exibirFormularioSecao([Map<String, dynamic>? secao]) {
    showDialog(
      context: context,
      builder: (context) {
        return _FormularioSecaoDialog(
          secao: secao,
          produtosLista: _produtosLista,
          baseUrl: widget.baseUrl,
          token: widget.token,
          onSucesso: (mensagem) {
            _mostrarSucesso(mensagem);
            _carregarDados();
          },
          onError: _mostrarErro,
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

  int get _totalSecoes => _secoes.length;
  int get _totalAtivas => _secoes.where((s) => (s['ativa'] ?? true) == true).length;

  @override
  Widget build(BuildContext context) {
    final secoesFiltradas = _secoes.where((s) {
      if (_termoBusca.isEmpty) return true;
      String titulo = (s['titulo'] ?? '').toString().toLowerCase();
      return titulo.contains(_termoBusca.toLowerCase());
    }).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 👁️ PAINEL SUPERIOR COLAPSÁVEL (Cabeçalho, KPIs e Filtros)
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
                            'Curadoria & Seções Promocionais',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: -0.4),
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Crie vitrines personalizadas e escolha a dedo os produtos.',
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
                          onPressed: () => _exibirFormularioSecao(),
                          icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                          label: const Text('Nova Seção', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 2. CARDS KPIs
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
                            hintText: 'Buscar seção por título...',
                            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                            prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B)),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1E3A8A), width: 1.5)),
                          ),
                          onChanged: (valor) => setState(() => _termoBusca = valor.trim()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded, color: Color(0xFF334155)),
                        onPressed: _carregarDados,
                        tooltip: 'Atualizar Lista',
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

          // 4. LISTAGEM DE SEÇÕES EMPILHADA (Blindada contra overflow)
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E3A8A)))
                  : secoesFiltradas.isEmpty
                  ? const Center(child: Text('Nenhuma seção promocional cadastrada.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 15)))
                  : ListView.separated(
                itemCount: secoesFiltradas.length,
                separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                itemBuilder: (context, index) {
                  final s = secoesFiltradas[index];
                  final int id = s['id'] ?? 0;
                  final String titulo = s['titulo'] ?? 'Seção';
                  final String tipo = s['tipo'] ?? 'livre';
                  final int ordem = s['ordem'] ?? 0;
                  final bool ativa = s['ativa'] ?? true;

                  List prodsVinculados = s['produtos'] ?? [];
                  int qtdProds = prodsVinculados.isNotEmpty
                      ? prodsVinculados.length
                      : (s['produto_ids'] as List?)?.length ?? 0;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: const Icon(Icons.grid_view_rounded, color: Color(0xFF1E3A8A), size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                titulo,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4)),
                                    child: Text('Ordem: $ordem', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                                  ),
                                  if (tipo != 'departamentos' && tipo != 'banner_com_titulo')
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(4)),
                                      child: Text('$qtdProds produtos', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
                                    ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(4), border: Border.all(color: const Color(0xFFE2E8F0))),
                                    child: Text('Tipo: $tipo', style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
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
                                      ativa ? 'Ativa' : 'Inativa',
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
                                          onPressed: () => _exibirFormularioSecao(s),
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
                                          onPressed: () => _deletarSecao(id, titulo),
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
        bool isPequeno = constraints.maxWidth < 900;
        final cards = [
          _buildKpiCard('Total de Seções', '$_totalSecoes vitrines', 'Cadastradas', Icons.view_carousel_rounded, const Color(0xFF1E3A8A), const Color(0xFFEFF6FF)),
          _buildKpiCard('Seções Ativas', '$_totalAtivas visíveis', 'Na Home', Icons.visibility_rounded, const Color(0xFF10B981), const Color(0xFFECFDF5)),
          _buildKpiCard('Catálogo', '${_produtosLista.length} prods', 'Disponíveis', Icons.inventory_2_rounded, const Color(0xFFD97706), const Color(0xFFFEF3C7)),
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
              Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color, size: 18)),
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

class _FormularioSecaoDialog extends StatefulWidget {
  final Map<String, dynamic>? secao;
  final List<dynamic> produtosLista;
  final String baseUrl;
  final String token;
  final Function(String) onSucesso;
  final Function(String) onError;

  const _FormularioSecaoDialog({
    super.key,
    this.secao,
    required this.produtosLista,
    required this.baseUrl,
    required this.token,
    required this.onSucesso,
    required this.onError,
  });

  @override
  State<_FormularioSecaoDialog> createState() => _FormularioSecaoDialogState();
}

class _FormularioSecaoDialogState extends State<_FormularioSecaoDialog> {
  late TextEditingController tituloCtrl;
  late TextEditingController ordemCtrl;
  late TextEditingController bannerUrlCtrl;

  late String tipoSelecionado;
  late bool ativa;
  late Set<int> produtosSelecionados;
  String buscaProdutoModal = '';
  bool salvando = false;

  final List<dynamic> tiposDisponiveis = [
    {'value': 'livre', 'label': 'Seção Livre / Curadoria'},
    {'value': 'ofertas_clube', 'label': 'Ofertas do Clube Prime'},
    {'value': 'destaques', 'label': 'Mais Vendidos / Destaques'},
    {'value': 'departamentos', 'label': 'Posicionador de Departamentos'},
    {'value': 'banner_com_titulo', 'label': 'Banner com Título Superior'},
  ];

  @override
  void initState() {
    super.initState();
    final secao = widget.secao;

    tituloCtrl = TextEditingController(text: secao?['titulo'] ?? '');
    ordemCtrl = TextEditingController(text: secao?['ordem']?.toString() ?? '0');
    bannerUrlCtrl = TextEditingController(text: secao?['banner_url'] ?? secao?['imagem_url'] ?? '');

    String tipoBanco = secao?['tipo'] ?? 'livre';
    if (tipoBanco == 'grade_produtos' || tipoBanco == 'padrao' || tipoBanco == 'carrossel' || tipoBanco == 'banner_secundario') {
      tipoBanco = 'livre';
    } else if (tipoBanco == 'ofertas') {
      tipoBanco = 'ofertas_clube';
    }

    tipoSelecionado = tiposDisponiveis.any((t) => t['value'] == tipoBanco)
        ? tipoBanco
        : 'livre';

    ativa = secao?['ativa'] ?? true;

    List<dynamic> prodsAtuais = secao?['produtos'] ?? [];
    List<dynamic> idsIniciais = secao?['produto_ids'] ?? prodsAtuais.map((p) => p['id']).toList();

    produtosSelecionados = Set<int>.from(
      idsIniciais.map((e) => int.tryParse(e.toString()) ?? 0).where((id) => id != 0),
    );
  }

  @override
  void dispose() {
    tituloCtrl.dispose();
    ordemCtrl.dispose();
    bannerUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (tituloCtrl.text.trim().isEmpty) {
      widget.onError('O título da seção é obrigatório.');
      return;
    }

    setState(() => salvando = true);

    final isEdicao = widget.secao != null;
    final payload = {
      "titulo": tituloCtrl.text.trim(),
      "tipo": tipoSelecionado,
      "ordem": int.tryParse(ordemCtrl.text) ?? 0,
      "ativa": ativa,
      "banner_url": tipoSelecionado == 'banner_com_titulo' ? bannerUrlCtrl.text.trim() : null,
      "produto_ids": (tipoSelecionado == 'departamentos' || tipoSelecionado == 'banner_com_titulo')
          ? []
          : produtosSelecionados.toList(),
    };

    try {
      final uri = isEdicao
          ? Uri.parse('${widget.baseUrl}/admin/secoes/${widget.secao!['id']}')
          : Uri.parse('${widget.baseUrl}/admin/secoes/');

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${widget.token}',
      };

      final response = isEdicao
          ? await http.put(uri, headers: headers, body: jsonEncode(payload))
          : await http.post(uri, headers: headers, body: jsonEncode(payload));

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        Navigator.pop(context);
        widget.onSucesso(isEdicao ? 'Seção atualizada!' : 'Seção criada com sucesso!');
      } else {
        widget.onError('Erro ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      widget.onError('Erro de conexão: $e');
    } finally {
      if (mounted) setState(() => salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdicao = widget.secao != null;
    final prodsFiltradosModal = widget.produtosLista.where((p) {
      if (buscaProdutoModal.isEmpty) return true;
      final String nome = (p['nome'] ?? '').toString().toLowerCase();
      return nome.contains(buscaProdutoModal.toLowerCase());
    }).toList();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        isEdicao ? 'Editar Seção Promocional' : 'Nova Seção Promocional',
        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
      ),
      content: Container(
        constraints: BoxConstraints(
          maxWidth: 650,
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        width: MediaQuery.of(context).size.width * 0.9,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: tituloCtrl,
                decoration: const InputDecoration(
                  labelText: 'Título da Seção *',
                  hintText: 'Ex: Kits de Churrasco, Ofertas do Dia',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title_rounded),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: tipoSelecionado,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Tipo de Exibição *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.grid_view_rounded),
                      ),
                      items: tiposDisponiveis.map((item) {
                        return DropdownMenuItem<String>(
                          value: item['value'],
                          child: Text(
                            item['label']!,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => tipoSelecionado = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: ordemCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Ordem na Home (0, 1...)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.format_list_numbered_rounded),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                activeColor: const Color(0xFF1E3A8A),
                title: const Text('Seção Ativa na Tela Inicial', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                value: ativa,
                onChanged: (val) => setState(() => ativa = val),
                contentPadding: EdgeInsets.zero,
              ),
              if (tipoSelecionado == 'banner_com_titulo') ...[
                const SizedBox(height: 16),
                TextField(
                  controller: bannerUrlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'URL da Imagem do Banner *',
                    hintText: 'https://exemplo.com/imagens/banner.png',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.image_rounded),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '💡 Dica: Insira o link direto de uma imagem hospedada para exibição abaixo do título.',
                  style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
                ),
              ],
              if (tipoSelecionado != 'departamentos' && tipoSelecionado != 'banner_com_titulo') ...[
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Produtos da Seção (Seleção Manual)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Text(
                        '${produtosSelecionados.length} selecionados',
                        style: const TextStyle(color: Color(0xFF1E3A8A), fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Filtrar produto por nome...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  onChanged: (val) => setState(() => buscaProdutoModal = val),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: prodsFiltradosModal.isEmpty
                      ? const Center(child: Text('Nenhum produto encontrado.', style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
                    itemCount: prodsFiltradosModal.length,
                    itemBuilder: (context, index) {
                      final p = prodsFiltradosModal[index];
                      final int pId = int.tryParse(p['id'].toString()) ?? 0;
                      final bool marcado = produtosSelecionados.contains(pId);
                      final double preco = double.tryParse(p['preco']?.toString() ?? '0') ?? 0.0;

                      return CheckboxListTile(
                        activeColor: const Color(0xFF1E3A8A),
                        dense: true,
                        value: marcado,
                        title: Text(p['nome'] ?? 'Produto', style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('ID: $pId | R\$ ${preco.toStringAsFixed(2)}'),
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              produtosSelecionados.add(pId);
                            } else {
                              produtosSelecionados.remove(pId);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
              ] else if (tipoSelecionado == 'departamentos') ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Color(0xFF1E3A8A)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'A seção "Posicionador de Departamentos" define a altura do carrossel de categorias. Não exige seleção de produtos.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF1E3A8A)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: salvando ? null : () => Navigator.pop(context),
          child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E3A8A),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: salvando ? null : _salvar,
          child: salvando
              ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
          )
              : const Text('Salvar Seção', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}