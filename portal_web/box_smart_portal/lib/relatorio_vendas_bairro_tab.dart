import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

class RelatorioVendasBairroTab extends StatefulWidget {
  final String baseUrl;
  final String token;

  const RelatorioVendasBairroTab({
    super.key,
    required this.baseUrl,
    required this.token,
  });

  @override
  State<RelatorioVendasBairroTab> createState() => _RelatorioVendasBairroTabState();
}

class _RelatorioVendasBairroTabState extends State<RelatorioVendasBairroTab> {
  List<dynamic> _bairros = [];
  double _faturamentoGlobal = 0.0;
  int _totalBairrosAtendidos = 0;
  bool _isLoading = true;

  final TextEditingController _buscaController = TextEditingController();
  String _termoBusca = '';

  final NumberFormat _formatoMoeda = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$',
  );

  @override
  void initState() {
    super.initState();
    _carregarRelatorioBairros();
  }

  Future<void> _carregarRelatorioBairros() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('${widget.baseUrl}/admin/relatorios/vendas-por-bairro/'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _faturamentoGlobal = double.tryParse(data['faturamento_global']?.toString() ?? '0') ?? 0.0;
          _totalBairrosAtendidos = data['total_bairros_atendidos'] ?? 0;
          _bairros = data['bairros'] ?? [];
          _isLoading = false;
        });
      } else {
        _mostrarErro('Erro ao carregar dados geográficos.');
      }
    } catch (e) {
      _mostrarErro('Erro de conexão: $e');
    }
  }

  void _mostrarErro(String msg) {
    if (!mounted) return;
    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: const Color(0xFFB91C1C)),
    );
  }

  String get _bairroLider {
    if (_bairros.isEmpty) return 'Nenhum';
    return _bairros.first['bairro'] ?? 'Nenhum';
  }

  double get _ticketMedioGeral {
    int totalPedidos = 0;
    for (var b in _bairros) {
      totalPedidos += (b['total_pedidos'] as num).toInt();
    }
    return totalPedidos > 0 ? (_faturamentoGlobal / totalPedidos) : 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final bairrosFiltrados = _bairros.where((b) {
      if (_termoBusca.isEmpty) return true;
      final nome = (b['bairro'] ?? '').toString().toLowerCase();
      return nome.contains(_termoBusca.toLowerCase());
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
                    'Distribuição Geográfica por Bairro',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.4,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Mapeamento de faturamento, volume de pedidos e ticket médio por região.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Color(0xFF334155)),
                onPressed: _carregarRelatorioBairros,
                tooltip: 'Atualizar Relatório',
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 2. CARDS KPIs
          _buildKpiGrid(),
          const SizedBox(height: 20),

          // 3. BARRA DE BUSCA
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: TextField(
              controller: _buscaController,
              decoration: InputDecoration(
                hintText: 'Filtrar por nome do bairro...',
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
          const SizedBox(height: 20),

          // 4. LISTAGEM RANQUEADA
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E3A8A)))
                  : bairrosFiltrados.isEmpty
                  ? const Center(child: Text('Nenhum bairro registrado no período.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 15)))
                  : ListView.separated(
                itemCount: bairrosFiltrados.length,
                separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                itemBuilder: (context, index) {
                  final b = bairrosFiltrados[index];
                  final String nomeBairro = b['bairro'] ?? 'Não informado';
                  final int pedidos = (b['total_pedidos'] as num).toInt();
                  final double faturamento = double.tryParse(b['faturamento']?.toString() ?? '0') ?? 0.0;
                  final double ticketMedio = double.tryParse(b['ticket_medio']?.toString() ?? '0') ?? 0.0;
                  final double percentual = double.tryParse(b['percentual_total']?.toString() ?? '0') ?? 0.0;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            // Posicional Badge
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: index == 0
                                    ? const Color(0xFFFEF3C7)
                                    : (index == 1 ? const Color(0xFFF1F5F9) : const Color(0xFFF8FAFC)),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: index == 0 ? const Color(0xFFF59E0B) : const Color(0xFFCBD5E1),
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  '#${index + 1}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: index == 0 ? const Color(0xFFD97706) : const Color(0xFF475569),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                nomeBairro,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B)),
                              ),
                            ),
                            Text(
                              _formatoMoeda.format(faturamento),
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF1E3A8A)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Barra de Progresso Relativa
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (percentual / 100).clamp(0.0, 1.0),
                            backgroundColor: const Color(0xFFF1F5F9),
                            color: index == 0 ? const Color(0xFF10B981) : const Color(0xFF1E3A8A),
                            minHeight: 6,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Subinformações
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '$pedidos pedidos realizados',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                            Text(
                              'Ticket Médio: ${_formatoMoeda.format(ticketMedio)} • ${percentual.toStringAsFixed(1)}% do total',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                            ),
                          ],
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
          _buildKpiCard('Regiões Atendidas', '$_totalBairrosAtendidos bairros', 'Presença de entregas', Icons.map_rounded, const Color(0xFF1E3A8A), const Color(0xFFEFF6FF)),
          _buildKpiCard('Bairro Campeão', _bairroLider, 'Maior faturamento', Icons.emoji_events_rounded, const Color(0xFFD97706), const Color(0xFFFEF3C7)),
          _buildKpiCard('Faturamento Mapeado', _formatoMoeda.format(_faturamentoGlobal), 'Total bruto acumulado', Icons.attach_money_rounded, const Color(0xFF10B981), const Color(0xFFECFDF5)),
          _buildKpiCard('Ticket Médio Geral', _formatoMoeda.format(_ticketMedioGeral), 'Média por pedido', Icons.analytics_rounded, const Color(0xFF7C3AED), const Color(0xFFF5F3FF)),
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