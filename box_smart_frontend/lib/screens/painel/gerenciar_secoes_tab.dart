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
  List<dynamic> _categoriasDisponiveis = [];
  bool _isLoading = true;

  final TextEditingController _buscaController = TextEditingController();
  String _termoBusca = '';

  @override
  void initState() {
    super.initState();
    _carregarDadosIniciais();
  }

  Future<void> _carregarDadosIniciais() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _carregarSecoes(),
      _carregarCategorias(),
    ]);
  }

  Future<void> _carregarSecoes() async {
    try {
      final response = await http.get(
        Uri.parse('${widget.baseUrl}/admin/secoes/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _secoes = jsonDecode(response.body);
        });
      } else {
        _mostrarErro('Erro ao carregar seções: ${response.statusCode}');
      }
    } catch (e) {
      _mostrarErro('Erro de conexão: $e');
    }
  }

  Future<void> _carregarCategorias() async {
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
          _categoriasDisponiveis = jsonDecode(response.body);
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar categorias para o dropdown: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deletarSecao(int id) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Seção'),
        content: const Text('Tem certeza que deseja remover esta seção da Home?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir', style: TextStyle(color: Colors.white)),
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

      if (response.statusCode == 204 || response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seção excluída!'), backgroundColor: Colors.green));
        _carregarSecoes();
      } else {
        _mostrarErro('Erro ao excluir: ${response.body}');
      }
    } catch (e) {
      _mostrarErro('Erro de conexão: $e');
    }
  }

  void _exibirFormularioSecao([Map<String, dynamic>? secao]) {
    final bool isEdicao = secao != null;
    final tituloCtrl = TextEditingController(text: secao?['titulo'] ?? '');
    final ordemCtrl = TextEditingController(text: secao?['ordem']?.toString() ?? '0');
    final bannerUrlCtrl = TextEditingController(text: secao?['banner_url'] ?? '');

    // 🌟 Novos controladores de Ação para Seções
    String? acaoTipoSelecionado = secao?['acao_tipo'];
    final acaoValorCtrl = TextEditingController(text: secao?['acao_valor'] ?? '');

    // Tratamento correto para capturar o ID numérico da categoria vindo do banco
    int? categoriaIdSelecionado;
    if (secao != null && secao['categoria_id'] != null) {
      categoriaIdSelecionado = int.tryParse(secao['categoria_id'].toString());
    }

    final List<String> tiposValidos = ['padrao', 'ofertas', 'destaques', 'grade_produtos', 'banner_secundario'];
    String tipoSelecionado = tiposValidos.contains(secao?['tipo'])
        ? secao!['tipo']
        : 'padrao';

    bool ativa = secao?['ativa'] ?? true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return AlertDialog(
              title: Text(isEdicao ? 'Editar Seção' : 'Nova Seção Promocional', style: const TextStyle(fontWeight: FontWeight.bold)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: tituloCtrl,
                        decoration: const InputDecoration(labelText: 'Título da Seção (Ex: Ofertas do Açougue)', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 16),

                      DropdownButtonFormField<String>(
                        value: tipoSelecionado,
                        decoration: const InputDecoration(labelText: 'Regra de Filtro da Seção', border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'padrao', child: Text('Padrão (Todos da Categoria)')),
                          DropdownMenuItem(value: 'ofertas', child: Text('Ofertas (Apenas com Desconto/Clube)')),
                          DropdownMenuItem(value: 'destaques', child: Text('Destaques / Mais Vendidos')),
                          DropdownMenuItem(value: 'grade_produtos', child: Text('Grade de Produtos (Legado)')),
                          DropdownMenuItem(value: 'banner_secundario', child: Text('Banner Secundário')),
                        ],
                        onChanged: (val) {
                          if (val != null) setStateModal(() => tipoSelecionado = val);
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: ordemCtrl,
                              decoration: const InputDecoration(labelText: 'Ordem de Exibição', border: OutlineInputBorder()),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Dropdown dinâmico para selecionar a categoria via ID numérico
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<int?>(
                              value: categoriaIdSelecionado,
                              decoration: const InputDecoration(labelText: 'Categoria de Referência', border: OutlineInputBorder()),
                              items: [
                                const DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text('Geral (Todas as categorias)', style: TextStyle(color: Colors.grey)),
                                ),
                                ..._categoriasDisponiveis.map((cat) {
                                  final int idCat = cat['id'];
                                  final String nomeCat = (cat['nome'] ?? '').toString();
                                  return DropdownMenuItem<int?>(
                                    value: idCat,
                                    child: Text(nomeCat),
                                  );
                                }),
                              ],
                              onChanged: (val) {
                                setStateModal(() {
                                  categoriaIdSelecionado = val;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: bannerUrlCtrl,
                        decoration: const InputDecoration(labelText: 'URL do Banner (Se for do tipo banner)', border: OutlineInputBorder()),
                      ),

                      // 🌟 Bloco de Configuração de Ação (Aparece principalmente se for Banner)
                      if (tipoSelecionado == 'banner_secundario') ...[
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: acaoTipoSelecionado,
                          decoration: const InputDecoration(labelText: 'Comportamento ao Clicar na Seção', border: OutlineInputBorder()),
                          items: const [
                            DropdownMenuItem(value: null, child: Text('Sem Ação (Informativo)')),
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
                          const SizedBox(height: 16),
                          TextField(
                            controller: acaoValorCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Nome Exato da Categoria',
                              hintText: 'Ex: Bebidas, Hortifrúti',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ],

                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text('Seção Ativa na Home'),
                        value: ativa,
                        onChanged: (val) => setStateModal(() => ativa = val),
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
                    if (tituloCtrl.text.trim().isEmpty) {
                      _mostrarErro('O título é obrigatório.');
                      return;
                    }

                    // 🌟 Payload com integração dos novos campos
                    final payload = {
                      "titulo": tituloCtrl.text.trim(),
                      "tipo": tipoSelecionado,
                      "ordem": int.tryParse(ordemCtrl.text) ?? 0,
                      "ativa": ativa,
                      "banner_url": bannerUrlCtrl.text.isEmpty ? null : bannerUrlCtrl.text.trim(),
                      "categoria_id": categoriaIdSelecionado,
                      "acao_tipo": tipoSelecionado == 'banner_secundario' ? acaoTipoSelecionado : null,
                      "acao_valor": (tipoSelecionado == 'banner_secundario' && acaoTipoSelecionado == 'categoria') ? acaoValorCtrl.text.trim() : null,
                    };

                    try {
                      http.Response response;
                      if (isEdicao) {
                        response = await http.put(
                          Uri.parse('${widget.baseUrl}/admin/secoes/${secao['id']}'),
                          headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${widget.token}'},
                          body: jsonEncode(payload),
                        );
                      } else {
                        response = await http.post(
                          Uri.parse('${widget.baseUrl}/admin/secoes/'),
                          headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${widget.token}'},
                          body: jsonEncode(payload),
                        );
                      }

                      if (response.statusCode == 200 || response.statusCode == 201) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(isEdicao ? 'Seção atualizada!' : 'Seção criada!'), backgroundColor: Colors.green),
                        );
                        _carregarSecoes();
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

  void _mostrarErro(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensagem), backgroundColor: Colors.red.shade900));
  }

  @override
  Widget build(BuildContext context) {
    final secoesFiltradas = _secoes.where((secao) {
      if (_termoBusca.isEmpty) return true;
      String titulo = (secao['titulo'] ?? '').toString().toLowerCase();
      return titulo.contains(_termoBusca.toLowerCase());
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Gestão de Seções Promocionais', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
                onPressed: () => _exibirFormularioSecao(),
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('Nova Seção', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: 300,
            child: TextField(
              controller: _buscaController,
              decoration: InputDecoration(
                hintText: 'Buscar seção por título...',
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
                : secoesFiltradas.isEmpty
                ? const Center(child: Text('Nenhuma seção encontrada.', style: TextStyle(color: Colors.grey, fontSize: 16)))
                : Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListView.separated(
                itemCount: secoesFiltradas.length,
                separatorBuilder: (context, index) => Divider(color: Colors.grey.shade200, height: 1),
                itemBuilder: (context, index) {
                  final secao = secoesFiltradas[index];

                  // Formatação para exibir a ação se existir
                  String infoExtra = '';
                  if (secao['tipo'] == 'banner_secundario' && secao['acao_tipo'] != null) {
                    infoExtra = ' | Ação: ${secao['acao_tipo'] == 'categoria' ? secao['acao_valor'] : 'Box Prime'}';
                  }

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    title: Text(secao['titulo'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                    subtitle: Text('Tipo: ${secao['tipo']} | Categoria ID: ${secao['categoria_id'] ?? 'Geral'} | Ordem: ${secao['ordem']} | Ativa: ${secao['ativa'] == true ? "Sim" : "Não"}$infoExtra'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                          tooltip: 'Editar',
                          onPressed: () => _exibirFormularioSecao(secao),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          tooltip: 'Excluir',
                          onPressed: () => _deletarSecao(secao['id']),
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