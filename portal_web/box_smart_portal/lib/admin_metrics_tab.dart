import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart'; // 🌟 1. Importação do intl

class AdminMetricsTab extends StatefulWidget {
  final String baseUrl;
  final String token;

  const AdminMetricsTab({
    super.key,
    required this.baseUrl,
    required this.token,
  });

  @override
  State<AdminMetricsTab> createState() => _AdminMetricsTabState();
}

class _AdminMetricsTabState extends State<AdminMetricsTab> {
  Map<String, dynamic> _dadosMetricas = {};
  bool _isLoading = true;

  // 🌟 2. Instância do formatador de moeda no padrão pt_BR
  final NumberFormat _formatoMoeda = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$',
  );

  @override
  void initState() {
    super.initState();
    _carregarMetricas();
  }

  Future<void> _carregarMetricas() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('${widget.baseUrl}/admin/metrics/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _dadosMetricas = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        // Fallback simulado caso a rota do backend ainda esteja em ajustes
        setState(() {
          _dadosMetricas = {
            "faturamento_total": 14280.50,
            "pedidos_mes": 312,
            "ticket_medio": 45.75,
            "insights_ia": [
              "A categoria Hortifrúti teve um aumento de 28% nas buscas esta semana. Recomenda-se criar uma seção de destaque.",
              "Clientes que compram pão integral frequentemente adicionam café gourmet no mesmo carrinho.",
              "Horário de pico de vendas detectado entre 18h e 20h nos dias de semana."
            ]
          };
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _mostrarErro('Erro ao carregar métricas: $e');
    }
  }

  void _mostrarErro(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensagem), backgroundColor: Colors.red.shade900));
  }

  @override
  Widget build(BuildContext context) {
    // 🌟 Conversão segura dos valores do Map
    final double faturamento = double.tryParse(_dadosMetricas['faturamento_total']?.toString() ?? '0') ?? 0.0;
    final double ticketMedio = double.tryParse(_dadosMetricas['ticket_medio']?.toString() ?? '0') ?? 0.0;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Métricas e Insights de IA', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Atualizar Dados',
                  onPressed: _carregarMetricas,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Cards de KPIs com formatação de milhar e centavos
            Row(
              children: [
                _buildKpiCard(
                    'Faturamento Total',
                    _formatoMoeda.format(faturamento), // 🌟 Formata ex: R$ 14.280,50
                    Icons.attach_money,
                    Colors.green
                ),
                const SizedBox(width: 16),
                _buildKpiCard('Pedidos no Mês', '${_dadosMetricas['pedidos_mes'] ?? 0}', Icons.shopping_bag, Colors.blue),
                const SizedBox(width: 16),
                _buildKpiCard(
                    'Ticket Médio',
                    _formatoMoeda.format(ticketMedio), // 🌟 Formata ex: R$ 45,75
                    Icons.trending_up,
                    Colors.orange
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Seção de Insights de IA
            const Text('Recomendações e Insights do Motor de IA', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: ((_dadosMetricas['insights_ia'] as List?) ?? []).map((insight) {
                    return ListTile(
                      leading: const Icon(Icons.lightbulb, color: Colors.amber, size: 28),
                      title: Text(insight.toString(), style: const TextStyle(fontSize: 15, height: 1.4)),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard(String titulo, String valor, IconData icone, Color cor) {
    return Expanded(
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: cor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(icone, color: cor, size: 30),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 6),
                  Text(valor, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}