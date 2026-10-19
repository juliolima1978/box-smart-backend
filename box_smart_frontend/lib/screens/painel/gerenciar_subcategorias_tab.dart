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

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    setState(() => _isLoading = true);
    try {
      final responses = await Future.wait([
        http.get(Uri.parse('${widget.baseUrl}/admin/subcategorias/'), headers: {'Authorization': 'Bearer ${widget.token}'}),
        http.get(Uri.parse('${widget.baseUrl}/admin/categorias/'), headers: {'Authorization': 'Bearer ${widget.token}'}),
      ]);

      if (responses[0].statusCode == 200 && responses[1].statusCode == 200) {
        setState(() {
          _subcategorias = jsonDecode(responses[0].body);
          _categorias = jsonDecode(responses[1].body);
          _isLoading = false;
        });
      } else {
        _mostrarErro('Erro ao carregar dados do servidor.');
      }
    } catch (e) {
      _mostrarErro('Erro de conexão: $e');
    }
  }

  Future<void> _deletarSubcategoria(int id) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Subcategoria'),
        content: const Text('Tem certeza que deseja apagar esta subcategoria?'),
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
        Uri.parse('${widget.baseUrl}/admin/subcategorias/$id'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      if (response.statusCode == 204 || response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Subcategoria excluída!'), backgroundColor: Colors.green));
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
              title: Text(isEdicao ? 'Editar Subcategoria' : 'Nova Subcategoria', style: const TextStyle(fontWeight: FontWeight.bold)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              content: SizedBox(
                width: 400,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nomeCtrl,
                        decoration: const InputDecoration(labelText: 'Nome da Subcategoria (Ex: Frutas, Aves)', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        value: categoriaIdSelecionada,
                        decoration: const InputDecoration(labelText: 'Categoria Pai (Departamento)', border: OutlineInputBorder()),
                        items: _categorias.map<DropdownMenuItem<int>>((cat) {
                          return DropdownMenuItem<int>(
                            value: cat['id'],
                            child: Text(cat['nome']),
                          );
                        }).toList(),
                        onChanged: (val) => setStateModal(() => categoriaIdSelecionada = val),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: ordemCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Ordem de Exibição',
                          hintText: '0, 1, 2...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text('Subcategoria Ativa'),
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
                    if (nomeCtrl.text.trim().isEmpty || categoriaIdSelecionada == null) {
                      _mostrarErro('Preencha o nome e selecione a categoria.');
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
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(isEdicao ? 'Subcategoria atualizada!' : 'Subcategoria criada!'), backgroundColor: Colors.green),
                        );
                        _carregarDados();
                      } else {
                        _mostrarErro('Erro ao salvar: ${response.body}');
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
    final subcategoriasFiltradas = _subcategorias.where((sub) {
      if (_termoBusca.isEmpty) return true;
      String nome = (sub['nome'] ?? '').toString().toLowerCase();
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
              const Text('Gestão de Subcategorias (Segmentos)', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
                onPressed: () => _exibirFormularioSubcategoria(),
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('Nova Subcategoria', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: 300,
            child: TextField(
              controller: _buscaController,
              decoration: InputDecoration(
                hintText: 'Buscar subcategoria...',
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
                : subcategoriasFiltradas.isEmpty
                ? const Center(child: Text('Nenhuma subcategoria encontrada.', style: TextStyle(color: Colors.grey, fontSize: 16)))
                : Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListView.separated(
                itemCount: subcategoriasFiltradas.length,
                separatorBuilder: (context, index) => Divider(color: Colors.grey.shade200, height: 1),
                itemBuilder: (context, index) {
                  final sub = subcategoriasFiltradas[index];
                  final int id = sub['id'] ?? 0;
                  final int ordem = sub['ordem'] ?? 0;
                  final bool ativa = sub['ativo'] ?? true;

                  // Busca o nome da categoria pai correspondente
                  final categoriaPai = _categorias.firstWhere(
                        (cat) => cat['id'] == sub['categoria_id'],
                    orElse: () => {'nome': 'Geral'},
                  );

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    title: Text(sub['nome'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                    subtitle: Text(
                      'Categoria Pai: ${categoriaPai['nome']} | Ordem: $ordem | Status: ${ativa ? "Ativo" : "Inativo"}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: ativa ? Colors.blueGrey : Colors.red,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                          tooltip: 'Editar',
                          onPressed: () => _exibirFormularioSubcategoria(sub),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          tooltip: 'Excluir',
                          onPressed: () => _deletarSubcategoria(id),
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