import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  Map<String, dynamic> _metricasBi = {};
  Map<String, dynamic> _insightsIa = {};
  List<dynamic> _produtos = [];
  bool _carregando = true;

  final String baseUrl = "http://192.168.15.175:8000";

  // Controladores para criar Banner
  final _bannerTituloController = TextEditingController();
  final _bannerUrlController = TextEditingController();

  // Controladores para atualizar Preço do Clube
  final Map<int, TextEditingController> _precoClubeControllers = {};

  @override
  void initState() {
    super.initState();
    _carregarDadosAdmin();
  }

  Future<void> _carregarDadosAdmin() async {
    setState(() => _carregando = true);
    try {
      final biRes = await http.get(Uri.parse('$baseUrl/admin/bi/metricas'));
      final iaRes = await http.get(Uri.parse('$baseUrl/admin/ia/insights'));
      final prodRes = await http.get(Uri.parse('$baseUrl/produtos/'));

      if (biRes.statusCode == 200 && iaRes.statusCode == 200 && prodRes.statusCode == 200) {
        setState(() {
          _metricasBi = jsonDecode(biRes.body);
          _insightsIa = jsonDecode(iaRes.body);
          _produtos = jsonDecode(prodRes.body);

          for (var p in _produtos) {
            _precoClubeControllers[p['id']] = TextEditingController(
              text: p['preco_clube'] != null ? p['preco_clube'].toString() : '',
            );
          }
          _carregando = false;
        });
      } else {
        setState(() => _carregando = false);
      }
    } catch (e) {
      setState(() => _carregando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar dados administrativos: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _criarBanner() async {
    if (_bannerTituloController.text.isEmpty || _bannerUrlController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha todos os campos do banner.'), backgroundColor: Colors.red),
      );
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/admin/banners/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "titulo": _bannerTituloController.text.trim(),
          "imagem_url": _bannerUrlController.text.trim(),
          "ativo": true,
        }),
      );

      if (response.statusCode == 201) {
        _bannerTituloController.clear();
        _bannerUrlController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Banner criado com sucesso!'), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao criar banner.'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _atualizarPrecoClube(int produtoId) async {
    final controller = _precoClubeControllers[produtoId];
    if (controller == null || controller.text.isEmpty) return;

    double? novoPreco = double.tryParse(controller.text.replaceAll(',', '.'));
    if (novoPreco == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Valor de preço inválido.'), backgroundColor: Colors.red),
      );
      return;
    }

    try {
      final response = await http.put(
        Uri.parse('$baseUrl/admin/produtos/$produtoId/preco-clube'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"preco_clube": novoPreco}),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preço do Clube atualizado com sucesso!'), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao atualizar preço.'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Portal do Gestor - Box Smart 📊'),
        centerTitle: true,
        backgroundColor: Colors.blue.shade800,
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _carregarDadosAdmin,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // SESSÃO DE BI E MÉTRICAS
            const Text('Métricas de Negócio (BI)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 2.2,
              children: [
                _cardMetrica('Faturamento Total', 'R\$ ${(_metricasBi['faturamento_total'] ?? 0.0).toStringAsFixed(2)}', Colors.green),
                _cardMetrica('Total de Pedidos', '${_metricasBi['total_pedidos_realizados'] ?? 0}', Colors.blue),
                _cardMetrica('Clientes Fidelidade', '${_metricasBi['total_clientes_fidelidade'] ?? 0}', Colors.orange),
                _cardMetrica('Produtos Ativos', '${_metricasBi['total_produtos_cadastrados'] ?? 0}', Colors.purple),
              ],
            ),
            const SizedBox(height: 25),

            // SESSÃO DE INTELIGÊNCIA ARTIFICIAL (IA)
            const Text('Insights & Previsões da IA 🤖', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Card(
              elevation: 3,
              color: Colors.blue.shade50,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ticket Médio: R\$ ${(_insightsIa['ticket_medio'] ?? 0.0).toStringAsFixed(2)}',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _insightsIa['recomendacao_ia'] ?? 'A analisar dados...',
                      style: const TextStyle(fontSize: 14, height: 1.4),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 25),

            // SESSÃO DE GESTÃO DE BANNERS
            const Text('Publicar Banner Promocional', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    TextField(
                      controller: _bannerTituloController,
                      decoration: const InputDecoration(labelText: 'Título da Promoção', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _bannerUrlController,
                      decoration: const InputDecoration(labelText: 'URL da Imagem do Banner', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 45,
                      child: ElevatedButton(
                        onPressed: _criarBanner,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade800, foregroundColor: Colors.white),
                        child: const Text('Cadastrar Banner'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 25),

            // SESSÃO DE PRECIFICAÇÃO DO CLUBE
            const Text('Gerir Preços do Clube por Produto', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _produtos.length,
              itemBuilder: (context, index) {
                final produto = _produtos[index];
                final int produtoId = produto['id'];
                final double precoNormal = produto['preco'];

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(produto['nome'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 4),
                              Text('Normal: R\$ ${precoNormal.toStringAsFixed(2)}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _precoClubeControllers[produtoId],
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Preço Clube',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.save, color: Colors.green),
                          onPressed: () => _atualizarPrecoClube(produtoId),
                          tooltip: 'Salvar Preço Clube',
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardMetrica(String titulo, String valor, Color cor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(titulo, style: TextStyle(color: cor, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(valor, style: TextStyle(color: cor, fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}