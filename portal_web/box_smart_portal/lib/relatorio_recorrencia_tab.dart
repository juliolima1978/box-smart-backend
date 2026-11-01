import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

class RelatorioRecorrenciaTab extends StatefulWidget {
  final String baseUrl;
  final String token;

  const RelatorioRecorrenciaTab({
    super.key,
    required this.baseUrl,
    required this.token,
  });

  @override
  State<RelatorioRecorrenciaTab> createState() => _RelatorioRecorrenciaTabState();
}

class _RelatorioRecorrenciaTabState extends State<RelatorioRecorrenciaTab> {
  Map<String, dynamic> _dados = {};
  bool _isLoading = true;
  bool _mostrarFiltros = true; // 👁️ Estado para alternar a visibilidade do topo

  final NumberFormat _formatoMoeda = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$',
  );

  @override
  void initState() {
    super.initState();
    _carregarRelatorioRecorrencia();
  }

  Future<void> _carregarRelatorioRecorrencia() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('${widget.baseUrl}/admin/relatorios/recorrencia-clientes/'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      if (response.statusCode == 200) {
        setState(() {
          _dados = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        _mostrarErro('Erro ao carregar relatório de retenção.');
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF1E3A8A)));
    }

    final double taxaRecorrencia = double.tryParse(_dados['taxa_recorrencia']?.toString() ?? '0') ?? 0.0;
    final double freqMedia = double.tryParse(_dados['frequencia_media_compras']?.toString() ?? '0') ?? 0.0;
    final double intervaloMedio = double.tryParse(_dados['intervalo_medio_dias']?.toString() ?? '0') ?? 0.0;
    final int totalClientes = _dados['total_clientes_unicos'] ?? 0;

    final distrib = _dados['distribuicao_frequencia'] ?? {};
    final List topClientes = _dados['top_clientes_recorrentes'] ?? [];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 👁️ PAINEL SUPERIOR COLAPSÁVEL (Cabeçalho e KPIs)
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 250),
            crossFadeState: _mostrarFiltros ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            firstChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. CABEÇALHO 100% RESPONSIVO
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Retenção & Recorrência de Clientes',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.4,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Métricas de fidelidade, tempo de recompra e análise da base recorrente.',
                            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      children: [
                        // 👁️ BOTÃO DE OLHO
                        IconButton(
                          icon: Icon(
                            _mostrarFiltros ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                            color: const Color(0xFF334155),
                          ),
                          tooltip: _mostrarFiltros ? 'Ocultar Cabeçalho/KPIs' : 'Mostrar Cabeçalho/KPIs',
                          onPressed: () {
                            setState(() {
                              _mostrarFiltros = !_mostrarFiltros;
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded, color: Color(0xFF334155)),
                          onPressed: _carregarRelatorioRecorrencia,
                          tooltip: 'Atualizar Relatório',
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 2. CARDS KPIs
                _buildKpiGrid(taxaRecorrencia, freqMedia, intervaloMedio, totalClientes),
                const SizedBox(height: 14),
              ],
            ),
            secondChild: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // 👁️ Botão de olho flutuante quando o topo estiver oculto
                TextButton.icon(
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                  onPressed: () {
                    setState(() {
                      _mostrarFiltros = !_mostrarFiltros;
                    });
                  },
                  icon: const Icon(Icons.visibility_rounded, color: Color(0xFF1E3A8A), size: 18),
                  label: const Text('Mostrar Cabeçalho e KPIs', style: TextStyle(color: Color(0xFF1E3A8A), fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),

          // 3. CONTEÚDO ADAPTATIVO (Empilhado ou Lado a lado dependendo do espaço)
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                bool telaEstreita = constraints.maxWidth < 900;

                final cardDistribuicao = Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Distribuição de Pedidos por Cliente',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Frequência acumulada de compras na base',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 16),
                      _buildItemBarraDistribucao('1 Compra Apenas', distrib['1_compra'] ?? 0, totalClientes, const Color(0xFFD97706)),
                      const SizedBox(height: 12),
                      _buildItemBarraDistribucao('2 a 3 Compras', distrib['2_a_3_compras'] ?? 0, totalClientes, const Color(0xFF0284C7)),
                      const SizedBox(height: 12),
                      _buildItemBarraDistribucao('4 a 5 Compras', distrib['4_a_5_compras'] ?? 0, totalClientes, const Color(0xFF7C3AED)),
                      const SizedBox(height: 12),
                      _buildItemBarraDistribucao('6+ Compras', distrib['6_ou_mais_compras'] ?? 0, totalClientes, const Color(0xFF10B981)),
                    ],
                  ),
                );

                final cardTopClientes = Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Top Clientes em Faturamento & Fidelidade',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Clientes de maior LTV (Lifetime Value) da loja',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: topClientes.isEmpty
                            ? const Center(child: Text('Nenhum dado registrado.', style: TextStyle(color: Color(0xFF94A3B8))))
                            : ListView.separated(
                          itemCount: topClientes.length,
                          separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          itemBuilder: (context, index) {
                            final c = topClientes[index];
                            final String nome = c['nome'] ?? 'Cliente';
                            final int pedidos = (c['total_pedidos'] as num).toInt();
                            final double gasto = double.tryParse(c['total_gasto']?.toString() ?? '0') ?? 0.0;
                            final double tMedio = double.tryParse(c['ticket_medio']?.toString() ?? '0') ?? 0.0;

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: const Color(0xFF1E3A8A).withOpacity(0.1),
                                    child: Text(
                                      '#${index + 1}',
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          nome,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '$pedidos ped. • Méd: ${_formatoMoeda.format(tMedio)}',
                                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _formatoMoeda.format(gasto),
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF10B981)),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );

                if (telaEstreita) {
                  return ListView(
                    children: [
                      cardDistribuicao,
                      const SizedBox(height: 14),
                      SizedBox(height: 350, child: cardTopClientes),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 4, child: cardDistribuicao),
                    const SizedBox(width: 14),
                    Expanded(flex: 6, child: cardTopClientes),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemBarraDistribucao(String label, int quantidade, int totalGeral, Color cor) {
    final double percentual = totalGeral > 0 ? (quantidade / totalGeral * 100) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF334155)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$quantidade (${percentual.toStringAsFixed(1)}%)',
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (percentual / 100).clamp(0.0, 1.0),
            backgroundColor: const Color(0xFFF1F5F9),
            color: cor,
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildKpiGrid(double taxa, double freq, double intervalo, int total) {
    return LayoutBuilder(
      builder: (context, constraints) {
        bool isPequeno = constraints.maxWidth < 900;
        final cards = [
          _buildKpiCard('Taxa de Recorrência', '${taxa.toStringAsFixed(1)}%', 'Clientes fiéis', Icons.repeat_rounded, const Color(0xFF10B981), const Color(0xFFECFDF5)),
          _buildKpiCard('Frequência Média', '${freq.toStringAsFixed(1)} ped.', 'Média compras/cliente', Icons.shopping_basket_rounded, const Color(0xFF1E3A8A), const Color(0xFFEFF6FF)),
          _buildKpiCard('Intervalo Recompra', '${intervalo.toStringAsFixed(0)} dias', 'Tempo entre pedidos', Icons.timer_rounded, const Color(0xFF7C3AED), const Color(0xFFF5F3FF)),
          _buildKpiCard('Base Analisada', '$total clientes', 'Com histórico', Icons.groups_rounded, const Color(0xFFD97706), const Color(0xFFFEF3C7)),
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
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
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