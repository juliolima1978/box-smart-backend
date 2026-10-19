import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart'; // 🌟 1. Importa o pacote intl

class AdminDashboardTab extends StatefulWidget {
  final String baseUrl;

  const AdminDashboardTab({super.key, required this.baseUrl});

  @override
  State<AdminDashboardTab> createState() => _AdminDashboardTabState();
}

class _AdminDashboardTabState extends State<AdminDashboardTab> {
  bool _carregando = true;
  Map<String, dynamic>? _dadosPainel;

  // 🌟 2. Instancia o formatador de moeda para o padrão brasileiro
  final NumberFormat _formatoMoeda = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$',
  );

  void _abrirModalCampanha() {
    final tituloController = TextEditingController(text: 'Oferta Especial para Você! 🛒');
    final mensagemController = TextEditingController(
        text: 'Aproveite as recomendações exclusivas do Box Smart e economize hoje no Clube de Fidelidade.'
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Disparar Campanha de Marketing', style: TextStyle(fontWeight: FontWeight.bold)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Esta ação enviará uma notificação push para todos os clientes cadastrados na plataforma.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: tituloController,
                  decoration: const InputDecoration(labelText: 'Título da Notificação', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: mensagemController,
                  decoration: const InputDecoration(labelText: 'Mensagem', border: OutlineInputBorder()),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade800),
              onPressed: () async {
                try {
                  final uri = Uri.parse('${widget.baseUrl}/admin/notificacoes/campanha').replace(
                    queryParameters: {
                      'titulo': tituloController.text,
                      'mensagem': mensagemController.text,
                    },
                  );

                  final response = await http.post(uri);

                  if (response.statusCode == 201) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Campanha disparada com sucesso!'), backgroundColor: Colors.green),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erro ao disparar: ${response.body}'), backgroundColor: Colors.red),
                    );
                  }
                } catch (e) {
                  debugPrint('Erro na requisição: $e');
                }
              },
              child: const Text('Enviar Campanha', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _buscarMetricas();
  }

  Future<void> _buscarMetricas() async {
    setState(() => _carregando = true);
    try {
      final response = await http.get(Uri.parse('${widget.baseUrl}/admin/ia/insights'));

      if (response.statusCode == 200) {
        setState(() {
          _dadosPainel = json.decode(response.body);
        });
      }
    } catch (e) {
      debugPrint('Erro ao buscar métricas: $e');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Widget _buildCardMetrica(String titulo, String valor, IconData icone, Color cor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: cor.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icone, color: cor, size: 32),
            ),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(valor, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.black87)),
              ],
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const Center(child: CircularProgressIndicator(color: Colors.redAccent));
    }

    final double faturamento = _dadosPainel?['faturamento_acumulado'] ?? 0.0;
    final double ticketMedio = _dadosPainel?['ticket_medio'] ?? 0.0;
    final String insightIa = _dadosPainel?['recomendacao_ia'] ?? 'Nenhum insight gerado ainda.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Visão Geral e Inteligência Artificial', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
                SizedBox(height: 4),
                Text('Acompanhe o desempenho das vendas e as previsões do sistema.', style: TextStyle(color: Colors.grey)),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Atualizar Dados',
              onPressed: _buscarMetricas,
            )
          ],
        ),
        const SizedBox(height: 24),

        // Cards de Faturamento e Ticket formatados com o NumberFormat
        Row(
          children: [
            _buildCardMetrica('Faturamento Total', _formatoMoeda.format(faturamento), Icons.attach_money, Colors.green),
            const SizedBox(width: 16),
            _buildCardMetrica('Ticket Médio', _formatoMoeda.format(ticketMedio), Icons.receipt_long, Colors.blue),
          ],
        ),
        const SizedBox(height: 24),

        // Painel de Insights da IA
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Colors.purple.shade800, Colors.deepPurple.shade900]),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: Colors.purple.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.auto_awesome, color: Colors.amber, size: 28),
                  SizedBox(width: 12),
                  Text('Motor de Decisão Box Smart', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                insightIa,
                style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black87,
                ),
                onPressed: _abrirModalCampanha,
                child: const Text(
                  'Configurar Campanha Recomendada',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}