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

  final TextEditingController _buscaController = TextEditingController();
  String _termoBusca = '';

  @override
  void initState() {
    super.initState();
    _carregarCategorias();
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
          _categorias = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        _mostrarErro('Erro ao carregar categorias: ${response.statusCode}');
      }
    } catch (e) {
      _mostrarErro('Erro de conexão: $e');
    }
  }

  Future<void> _deletarCategoria(int id) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Categoria'),
        content: const Text('Tem certeza que deseja apagar esta categoria? Isso pode afetar os produtos vinculados a ela.'),
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
        Uri.parse('${widget.baseUrl}/admin/categorias/$id'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      if (response.statusCode == 204 || response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Categoria excluída!'), backgroundColor: Colors.green));
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

    // 🌟 Novos controladores para Posição e Status
    final ordemCtrl = TextEditingController(text: categoria?['ordem']?.toString() ?? '0');
    bool ativa = categoria?['ativo'] ?? true;

    showDialog(
      context: context,
      builder: (context) {
        // 🌟 StatefulBuilder adicionado para o Switch funcionar no modal
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return AlertDialog(
              title: Text(isEdicao ? 'Editar Categoria' : 'Nova Categoria', style: const TextStyle(fontWeight: FontWeight.bold)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              content: SizedBox(
                width: 400,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nomeCtrl,
                        decoration: const InputDecoration(labelText: 'Nome da Categoria', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: ordemCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Posição no Menu (Ex: 0, 1, 2...)',
                          hintText: '0 é a primeira posição',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: corTextoCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Cor do Texto (Hex, ex: #333333)',
                          hintText: '#333333',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: imagemUrlCtrl,
                        decoration: const InputDecoration(
                          labelText: 'URL da Imagem (Opcional)',
                          hintText: 'https://exemplo.com/icone.png',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: corCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Cor do Ícone (Hex, ex: #1E3A8A)',
                          hintText: '#1E3A8A',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: corFundoCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Cor de Fundo do Botão (Hex, ex: #E3F2FD)',
                          hintText: '#E3F2FD',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text('Categoria Ativa no Menu'),
                        subtitle: const Text('Se desativado, o botão não aparecerá no app.'),
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
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A)),
                  onPressed: () async {
                    if (nomeCtrl.text.trim().isEmpty) {
                      _mostrarErro('O nome da categoria é obrigatório.');
                      return;
                    }

                    // 🌟 Payload agora inclui ordem e status
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
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(isEdicao ? 'Categoria atualizada!' : 'Categoria criada!'), backgroundColor: Colors.green),
                        );
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

  Color _parseCor(String? hexColor) {
    if (hexColor == null || hexColor.isEmpty) return const Color(0xFF1E3A8A);
    try {
      String hex = hexColor.replaceAll('#', '').trim();
      var buffer = StringBuffer();

      if (hex.length == 6) {
        buffer.write('ff'); // Adiciona opacidade total se vier 6 caracteres
        buffer.write(hex);
        return Color(int.parse(buffer.toString(), radix: 16));
      } else if (hex.length == 8) {
        buffer.write(hex);
        return Color(int.parse(buffer.toString(), radix: 16));
      }
    } catch (_) {}

    return const Color(0xFF1E3A8A);
  }

  void _mostrarErro(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensagem), backgroundColor: Colors.red.shade900));
  }

  @override
  Widget build(BuildContext context) {
    final categoriasFiltradas = _categorias.where((cat) {
      if (_termoBusca.isEmpty) return true;
      String nome = (cat['nome'] ?? '').toString().toLowerCase();
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
              const Text('Gerenciar Categorias', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
                onPressed: () => _exibirFormularioCategoria(),
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('Nova Categoria', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: 300,
            child: TextField(
              controller: _buscaController,
              decoration: InputDecoration(
                hintText: 'Buscar categoria por nome...',
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
                : categoriasFiltradas.isEmpty
                ? const Center(child: Text('Nenhuma categoria encontrada.', style: TextStyle(color: Colors.grey, fontSize: 16)))
                : Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListView.separated(
                  itemCount: categoriasFiltradas.length,
                  separatorBuilder: (context, index) => Divider(color: Colors.grey.shade200, height: 1),
                  itemBuilder: (context, index) {
                    final cat = categoriasFiltradas[index];
                    final int id = cat['id'] ?? 0;
                    final String? imagemUrl = cat['imagem_url'];
                    final String? corHex = cat['cor_icone'];
                    final Color corAplicada = _parseCor(corHex);

                    // 🌟 Lê a ordem e status para exibição
                    final int ordem = cat['ordem'] ?? 0;
                    final bool ativa = cat['ativo'] ?? true;

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: corAplicada.withOpacity(0.1),
                        backgroundImage: (imagemUrl != null && imagemUrl.startsWith('http'))
                            ? NetworkImage(imagemUrl)
                            : null,
                        child: (imagemUrl == null || !imagemUrl.startsWith('http'))
                            ? Icon(Icons.storefront, color: corAplicada, size: 22)
                            : null,
                      ),
                      title: Text(cat['nome'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 🌟 Exibe a ordem e o status diretamente no card
                          Text(
                              'ID: $id | Ordem: $ordem | Status: ${ativa ? "Ativo" : "Oculto"}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: ativa ? Colors.blueGrey : Colors.red,
                              )
                          ),
                          if (imagemUrl != null && imagemUrl.isNotEmpty)
                            Text('Img: $imagemUrl', style: const TextStyle(fontSize: 12, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                            tooltip: 'Editar',
                            onPressed: () => _exibirFormularioCategoria(cat),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            tooltip: 'Excluir',
                            onPressed: () => _deletarCategoria(cat['id']),
                          ),
                        ],
                      ),
                    );
                  }
              ),
            ),
          ),
        ],
      ),
    );
  }
}