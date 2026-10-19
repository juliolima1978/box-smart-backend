import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class GerenciarBannersTab extends StatefulWidget {
  final String baseUrl;
  final String token;

  const GerenciarBannersTab({
    super.key,
    required this.baseUrl,
    required this.token,
  });

  @override
  State<GerenciarBannersTab> createState() => _GerenciarBannersTabState();
}

class _GerenciarBannersTabState extends State<GerenciarBannersTab> {
  List<dynamic> _banners = [];
  bool _isLoading = true;

  final TextEditingController _buscaController = TextEditingController();
  String _termoBusca = '';

  // 🌟 Filtro por Tipo de Banner (null = "Todos")
  String? _tipoFiltro;

  @override
  void initState() {
    super.initState();
    _carregarBanners();
  }

  Future<void> _carregarBanners() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('${widget.baseUrl}/banners/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _banners = jsonDecode(response.body) ?? [];
          _isLoading = false;
        });
      } else {
        _mostrarErro('Erro ao carregar banners: ${response.statusCode}');
      }
    } catch (e) {
      _mostrarErro('Erro de conexão: $e');
    }
  }

  Future<void> _deletarBanner(int id, String titulo) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Excluir Banner'),
          ],
        ),
        content: Text('Tem certeza que deseja remover o banner "$titulo" do carrossel?'),
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
        Uri.parse('${widget.baseUrl}/admin/banners/$id'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        _mostrarSucesso('Banner "$titulo" excluído com sucesso!');
        _carregarBanners();
      } else {
        _mostrarErro('Erro ao excluir: ${response.body}');
      }
    } catch (e) {
      _mostrarErro('Erro de conexão: $e');
    }
  }

  void _exibirFormularioBanner([Map<String, dynamic>? bannerExistente]) {
    final bool isEdicao = bannerExistente != null;
    final tituloCtrl = TextEditingController(text: bannerExistente?['titulo'] ?? '');
    final imagemUrlCtrl = TextEditingController(text: bannerExistente?['imagem_url'] ?? '');
    final acaoValorCtrl = TextEditingController(text: bannerExistente?['acao_valor'] ?? '');
    final ordemCtrl = TextEditingController(text: bannerExistente?['ordem']?.toString() ?? '0');

    String tipoSelecionado = bannerExistente?['tipo'] ?? 'principal';
    String? acaoTipoSelecionado = bannerExistente?['acao_tipo'];
    bool ativo = bannerExistente?['ativo'] ?? true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                isEdicao ? 'Editar Banner' : 'Novo Banner para a Home',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: tituloCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Título do Banner *',
                          hintText: 'Ex: Ofertas Especiais de Fim de Semana',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.title_rounded),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: imagemUrlCtrl,
                        decoration: const InputDecoration(
                          labelText: 'URL da Imagem (Proporção 16:9) *',
                          hintText: 'https://exemplo.com/banner.jpg',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.image_outlined),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: tipoSelecionado,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Tipo de Banner *',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.view_carousel_outlined),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'principal',
                                  child: Text('Principal (Topo)', overflow: TextOverflow.ellipsis),
                                ),
                                DropdownMenuItem(
                                  value: 'secundario',
                                  child: Text('Secundário (Meio)', overflow: TextOverflow.ellipsis),
                                ),
                              ],
                              onChanged: (val) {
                                if (val != null) setStateModal(() => tipoSelecionado = val);
                              },
                            ),
                          ),
                          if (tipoSelecionado == 'secundario') ...[
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: ordemCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Posição na Home (Ordem)',
                                  hintText: 'Ex: 2 ou 3',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.format_list_numbered_rounded),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String?>(
                        value: acaoTipoSelecionado,
                        decoration: const InputDecoration(
                          labelText: 'Comportamento ao Clicar',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.touch_app_outlined),
                        ),
                        items: const [
                          DropdownMenuItem(value: null, child: Text('Meramente Informativo (Sem Ação)')),
                          DropdownMenuItem(value: 'categoria', child: Text('Abrir Categoria Específica')),
                          DropdownMenuItem(value: 'clube_prime', child: Text('Abrir Clube Box Prime')),
                        ],
                        onChanged: (val) {
                          setStateModal(() {
                            acaoTipoSelecionado = val;
                            if (val != 'categoria') {
                              acaoValorCtrl.clear();
                            }
                          });
                        },
                      ),
                      if (acaoTipoSelecionado == 'categoria') ...[
                        const SizedBox(height: 14),
                        TextField(
                          controller: acaoValorCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Nome Exato da Categoria *',
                            hintText: 'Ex: Bebidas, Hortifrúti, Limpeza',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.category_outlined),
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      SwitchListTile(
                        activeColor: const Color(0xFF1E3A8A),
                        title: const Text('Banner Ativo', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: const Text('Exibir imediatamente na página inicial do aplicativo.'),
                        value: ativo,
                        onChanged: (val) => setStateModal(() => ativo = val),
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
                    if (tituloCtrl.text.trim().isEmpty || imagemUrlCtrl.text.trim().isEmpty) {
                      _mostrarErro('Preencha o título e a URL da imagem.');
                      return;
                    }

                    if (acaoTipoSelecionado == 'categoria' && acaoValorCtrl.text.trim().isEmpty) {
                      _mostrarErro('Informe o nome da categoria para a ação.');
                      return;
                    }

                    final payload = {
                      "titulo": tituloCtrl.text.trim(),
                      "imagem_url": imagemUrlCtrl.text.trim(),
                      "tipo": tipoSelecionado,
                      "ordem": int.tryParse(ordemCtrl.text.trim()) ?? 0,
                      "ativo": ativo,
                      "acao_tipo": acaoTipoSelecionado,
                      "acao_valor": acaoTipoSelecionado == 'categoria' ? acaoValorCtrl.text.trim() : null,
                    };

                    try {
                      final url = isEdicao
                          ? '${widget.baseUrl}/admin/banners/${bannerExistente['id']}'
                          : '${widget.baseUrl}/admin/banners/';

                      final response = isEdicao
                          ? await http.put(Uri.parse(url), headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${widget.token}'}, body: jsonEncode(payload))
                          : await http.post(Uri.parse(url), headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${widget.token}'}, body: jsonEncode(payload));

                      if (response.statusCode == 200 || response.statusCode == 201) {
                        if (!mounted) return;
                        Navigator.pop(context);
                        _mostrarSucesso(isEdicao ? 'Banner atualizado com sucesso!' : 'Banner criado com sucesso!');
                        _carregarBanners();
                      } else {
                        _mostrarErro('Erro ${response.statusCode}: ${response.body}');
                      }
                    } catch (e) {
                      _mostrarErro('Erro de conexão: $e');
                    }
                  },
                  child: const Text('Salvar Banner', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

  int get _totalBanners => _banners.length;
  int get _totalPrincipais => _banners.where((b) => (b['tipo'] ?? 'principal') == 'principal').length;
  int get _totalSecundarios => _banners.where((b) => b['tipo'] == 'secundario').length;
  int get _totalAtivos => _banners.where((b) => (b['ativo'] ?? true) == true).length;

  @override
  Widget build(BuildContext context) {
    final bannersFiltrados = _banners.where((b) {
      bool atendeBusca = true;
      if (_termoBusca.isNotEmpty) {
        String titulo = (b['titulo'] ?? '').toString().toLowerCase();
        atendeBusca = titulo.contains(_termoBusca.toLowerCase());
      }

      bool atendeTipo = true;
      if (_tipoFiltro != null) {
        atendeTipo = (b['tipo'] ?? 'principal') == _tipoFiltro;
      }

      return atendeBusca && atendeTipo;
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
                    'Gestão de Banners do Carrossel',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: -0.4),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Cadastre e gerencie os banners promocionais exibidos no aplicativo.',
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
                onPressed: () => _exibirFormularioBanner(),
                icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                label: const Text('Novo Banner', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
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
                          hintText: 'Buscar banner por título...',
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
                      onPressed: _carregarBanners,
                      tooltip: 'Atualizar Banners',
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // ChoiceChips de Filtro por Tipo
                Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Todos os Tipos'),
                      selected: _tipoFiltro == null,
                      selectedColor: const Color(0xFF1E3A8A),
                      backgroundColor: const Color(0xFFF1F5F9),
                      labelStyle: TextStyle(
                        color: _tipoFiltro == null ? Colors.white : const Color(0xFF475569),
                        fontWeight: _tipoFiltro == null ? FontWeight.bold : FontWeight.w500,
                        fontSize: 12,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide.none),
                      showCheckmark: false,
                      onSelected: (selected) => setState(() => _tipoFiltro = null),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Principais (Topo)'),
                      selected: _tipoFiltro == 'principal',
                      selectedColor: const Color(0xFF1E3A8A),
                      backgroundColor: const Color(0xFFF1F5F9),
                      labelStyle: TextStyle(
                        color: _tipoFiltro == 'principal' ? Colors.white : const Color(0xFF475569),
                        fontWeight: _tipoFiltro == 'principal' ? FontWeight.bold : FontWeight.w500,
                        fontSize: 12,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide.none),
                      showCheckmark: false,
                      onSelected: (selected) => setState(() => _tipoFiltro = selected ? 'principal' : null),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Secundários'),
                      selected: _tipoFiltro == 'secundario',
                      selectedColor: const Color(0xFF1E3A8A),
                      backgroundColor: const Color(0xFFF1F5F9),
                      labelStyle: TextStyle(
                        color: _tipoFiltro == 'secundario' ? Colors.white : const Color(0xFF475569),
                        fontWeight: _tipoFiltro == 'secundario' ? FontWeight.bold : FontWeight.w500,
                        fontSize: 12,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide.none),
                      showCheckmark: false,
                      onSelected: (selected) => setState(() => _tipoFiltro = selected ? 'secundario' : null),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 4. TABELA / LISTAGEM DE BANNERS
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E3A8A)))
                  : bannersFiltrados.isEmpty
                  ? const Center(child: Text('Nenhum banner cadastrado.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 15)))
                  : ListView.separated(
                itemCount: bannersFiltrados.length,
                separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                itemBuilder: (context, index) {
                  final banner = bannersFiltrados[index];
                  final int id = banner['id'] ?? 0;
                  final String tipo = banner['tipo'] ?? 'principal';
                  final int ordem = banner['ordem'] ?? 0;
                  final bool ativo = banner['ativo'] == true;
                  final String? acaoTipo = banner['acao_tipo'];
                  final String? acaoValor = banner['acao_valor'];
                  final String imgUrl = banner['imagem_url'] ?? '';

                  String acaoDescricao = 'Informativo';
                  if (acaoTipo == 'categoria') {
                    acaoDescricao = 'Categoria: ${acaoValor ?? 'Não especificada'}';
                  } else if (acaoTipo == 'clube_prime') {
                    acaoDescricao = 'Clube Box Prime';
                  }

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 90,
                        height: 50,
                        color: const Color(0xFFF1F5F9),
                        child: imgUrl.isNotEmpty
                            ? Image.network(
                          imgUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image_outlined, color: Color(0xFF94A3B8)),
                        )
                            : const Icon(Icons.image_not_supported_outlined, color: Color(0xFF94A3B8)),
                      ),
                    ),
                    title: Text(
                      banner['titulo'] ?? 'Sem Título',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B)),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: tipo == 'principal' ? const Color(0xFFEFF6FF) : const Color(0xFFF5F3FF),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              tipo == 'principal' ? 'Principal' : 'Secundário',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: tipo == 'principal' ? const Color(0xFF1E3A8A) : const Color(0xFF7C3AED),
                              ),
                            ),
                          ),
                          if (tipo == 'secundario') ...[
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
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Ação: $acaoDescricao',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
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
                            color: ativo ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: ativo ? const Color(0xFFA7F3D0) : const Color(0xFFFCA5A5)),
                          ),
                          child: Text(
                            ativo ? 'Ativo' : 'Inativo',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: ativo ? const Color(0xFF047857) : const Color(0xFFB91C1C),
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, color: Color(0xFF1E3A8A), size: 20),
                          tooltip: 'Editar',
                          onPressed: () => _exibirFormularioBanner(banner),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 20),
                          tooltip: 'Excluir',
                          onPressed: () => _deletarBanner(id, banner['titulo'] ?? ''),
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
          _buildKpiCard('Total Banners', '$_totalBanners cadastrados', 'Banners na plataforma', Icons.view_carousel_rounded, const Color(0xFF1E3A8A), const Color(0xFFEFF6FF)),
          _buildKpiCard('Principais (Topo)', '$_totalPrincipais itens', 'Exibidos no topo da Home', Icons.star_rounded, const Color(0xFF7C3AED), const Color(0xFFF5F3FF)),
          _buildKpiCard('Secundários', '$_totalSecundarios itens', 'Exibidos nas seções', Icons.collections_rounded, const Color(0xFF0284C7), const Color(0xFFE0F2FE)),
          _buildKpiCard('Banners Ativos', '$_totalAtivos visíveis', 'Exibidos aos clientes', Icons.visibility_rounded, const Color(0xFF10B981), const Color(0xFFECFDF5)),
        ];

        if (isPequeno) {
          return Column(
            children: [
              Row(children: [Expanded(child: cards[0]), const SizedBox(width: 12), Expanded(child: cards[1])]),
              const SizedBox(height: 12),
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