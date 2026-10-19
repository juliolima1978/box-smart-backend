import 'package:box_smart_frontend/main.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
// import '../main.dart'; // Ajuste para importar o AppColors, se necessário

class AdminProdutosTab extends StatefulWidget {
  final String baseUrl;

  const AdminProdutosTab({super.key, required this.baseUrl});

  @override
  State<AdminProdutosTab> createState() => _AdminProdutosTabState();
}

class _AdminProdutosTabState extends State<AdminProdutosTab> {
  List<dynamic> _produtos = [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _buscarProdutos();
  }

  Future<void> _buscarProdutos() async {
    setState(() => _carregando = true);
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
      if (mounted) setState(() => _carregando = false);
    }
  }

  void _exibirFormularioProduto([Map<String, dynamic>? produto]) {
    final bool isEdicao = produto != null;

    // Controladores de Texto
    final nomeCtrl = TextEditingController(text: produto?['nome'] ?? '');
    final descricaoCtrl = TextEditingController(text: produto?['descricao'] ?? '');
    final precoCtrl = TextEditingController(text: produto?['preco']?.toString() ?? '');
    final precoClubeCtrl = TextEditingController(text: produto?['preco_clube']?.toString() ?? '');
    final unidadeCtrl = TextEditingController(text: produto?['unidade'] ?? 'un');
    final estoqueCtrl = TextEditingController(text: produto?['estoque']?.toString() ?? '50');
    final imagemCtrl = TextEditingController(text: produto?['imagem_url'] ?? '');
    final categoriaCtrl = TextEditingController(text: produto?['categoria_id']?.toString() ?? '1');

    // Controladores Booleanos
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

                      // 🎛️ OPÇÕES DE STATUS E MARKETING
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
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaria),
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
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(isEdicao ? 'Produto atualizado!' : 'Produto criado!'), backgroundColor: Colors.green),
                        );
                      } else {
                        // Tenta extrair a mensagem de erro do JSON, se não conseguir, mostra o corpo bruto ou o status
                        String mensagemErro = 'Erro HTTP ${response.statusCode}';
                        try {
                          final erroJson = jsonDecode(response.body);
                          mensagemErro = erroJson['detail'] != null
                              ? erroJson['detail'].toString()
                              : erroJson.toString();
                        } catch (_) {
                          if (response.body.isNotEmpty) {
                            mensagemErro = response.body;
                          }
                        }

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(mensagemErro),
                            backgroundColor: Colors.red.shade900,
                            duration: const Duration(seconds: 5), // Fica mais tempo na tela para você ler
                          ),
                        );
                      }
                    } catch (e) {
                      debugPrint('Erro crítico ao salvar: $e');
                      // 👇 Agora o erro aparecerá na tela se falhar
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cabeçalho da Aba
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Gestão de Produtos', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
                SizedBox(height: 4),
                Text('Controle o catálogo, estoque e os preços exclusivos do clube Box Prime.', style: TextStyle(color: Colors.grey)),
              ],
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent, // Ou AppColors.primaria
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => _exibirFormularioProduto(),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Novo Produto', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Tabela de Dados
        Expanded(
          child: _carregando
              ? const Center(child: CircularProgressIndicator())
              : Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: MaterialStateProperty.resolveWith((states) => Colors.grey.shade50),
                  columns: const [
                    DataColumn(label: Text('ID', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Produto', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Preço Padrão', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Preço Prime', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Unidade', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Ações', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  rows: _produtos.map((produto) {
                    final preco = produto['preco'] != null ? double.parse(produto['preco'].toString()).toStringAsFixed(2) : '0.00';
                    final precoClube = produto['preco_clube'] != null ? double.parse(produto['preco_clube'].toString()).toStringAsFixed(2) : '-';

                    return DataRow(
                      cells: [
                        DataCell(Text(produto['id'].toString(), style: const TextStyle(color: Colors.grey))),
                        DataCell(
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                margin: const EdgeInsets.only(right: 12),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: produto['imagem_url'] != null
                                    ? Image.network(produto['imagem_url'], fit: BoxFit.contain)
                                    : const Icon(Icons.inventory_2, color: Colors.grey, size: 20),
                              ),
                              SizedBox(
                                width: 250,
                                child: Text(produto['nome'] ?? 'Sem nome', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500)),
                              ),
                            ],
                          ),
                        ),
                        DataCell(Text('R\$ $preco')),
                        DataCell(
                          produto['preco_clube'] != null
                              ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(4)),
                            child: Text('R\$ $precoClube', style: TextStyle(color: Colors.amber.shade900, fontWeight: FontWeight.bold)),
                          )
                              : const Text('-', style: TextStyle(color: Colors.grey)),
                        ),
                        DataCell(Text(produto['unidade'] ?? 'un')),
                        DataCell(
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                                tooltip: 'Editar Produto',
                                onPressed: () => _exibirFormularioProduto(produto),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                tooltip: 'Remover Produto',
                                onPressed: () {
                                  // Espaço para a função de deletar
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}