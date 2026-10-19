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
          _banners = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        _mostrarErro('Erro ao carregar banners: ${response.statusCode}');
      }
    } catch (e) {
      _mostrarErro('Erro de conexão: $e');
    }
  }

  Future<void> _deletarBanner(int id) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Banner'),
        content: const Text('Tem certeza que deseja remover este banner do carrossel?'),
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
        Uri.parse('${widget.baseUrl}/admin/banners/$id'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Banner excluído com sucesso!'), backgroundColor: Colors.green));
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

    String tipoSelecionado = bannerExistente?['tipo'] ?? 'principal';
    String? acaoTipoSelecionado = bannerExistente?['acao_tipo']; // null ou vazio = Informativo
    bool ativo = bannerExistente?['ativo'] ?? true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return AlertDialog(
              title: Text(isEdicao ? 'Editar Banner' : 'Novo Banner para a Home', style: const TextStyle(fontWeight: FontWeight.bold)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: tituloCtrl,
                        decoration: const InputDecoration(labelText: 'Título do Banner (Ex: Destaque Semanal)', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: imagemUrlCtrl,
                        decoration: const InputDecoration(labelText: 'URL da Imagem (Proporção 16:9)', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: tipoSelecionado,
                        decoration: const InputDecoration(labelText: 'Tipo de Banner', border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'principal', child: Text('Principal (Carrossel Topo)')),
                          DropdownMenuItem(value: 'secundario', child: Text('Secundário')),
                        ],
                        onChanged: (val) {
                          if (val != null) setStateModal(() => tipoSelecionado = val);
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: acaoTipoSelecionado,
                        decoration: const InputDecoration(labelText: 'Comportamento ao Clicar', border: OutlineInputBorder()),
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
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text('Banner Ativo'),
                        value: ativo,
                        onChanged: (val) => setStateModal(() => ativo = val),
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
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(isEdicao ? 'Banner atualizado com sucesso!' : 'Banner criado com sucesso!'), backgroundColor: Colors.green),
                        );
                        _carregarBanners();
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
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Gestão de Banners do Carrossel', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
                onPressed: () => _exibirFormularioBanner(),
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('Novo Banner', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _banners.isEmpty
                ? const Center(child: Text('Nenhum banner cadastrado.', style: TextStyle(color: Colors.grey, fontSize: 16)))
                : Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListView.separated(
                itemCount: _banners.length,
                separatorBuilder: (context, index) => Divider(color: Colors.grey.shade200, height: 1),
                itemBuilder: (context, index) {
                  final banner = _banners[index];
                  final acaoTipo = banner['acao_tipo'];
                  final acaoDescricao = acaoTipo == 'categoria'
                      ? 'Categoria: ${banner['acao_valor']}'
                      : (acaoTipo == 'clube_prime' ? 'Abre Box Prime' : 'Informativo');

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        banner['imagem_url'] ?? '',
                        width: 80,
                        height: 45,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 80,
                          height: 45,
                          color: Colors.grey.shade300,
                          child: const Icon(Icons.broken_image, size: 20),
                        ),
                      ),
                    ),
                    title: Text(banner['titulo'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                    subtitle: Text('Tipo: ${banner['tipo']} | Ação: $acaoDescricao | Ativo: ${banner['ativo'] == true ? "Sim" : "Não"}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, color: Color(0xFF1E3A8A)),
                          tooltip: 'Editar',
                          onPressed: () => _exibirFormularioBanner(banner),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          tooltip: 'Excluir',
                          onPressed: () => _deletarBanner(banner['id']),
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