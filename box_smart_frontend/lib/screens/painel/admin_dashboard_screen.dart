import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'gerenciar_usuarios_tab.dart';

import 'fila_pedidos_separador_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  final String baseUrl;
  final String token;

  const AdminDashboardScreen({
    super.key,
    required this.baseUrl,
    required this.token,
  });

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _isLoading = true;
  bool _isGerandoIA = false; // Controle de loading para a IA
  String _insightIA = 'Analisando o fluxo recente e as tendências do setor supermercadista para gerar recomendações estratégicas...';

  Map<String, dynamic> _dadosResumo = {};
  List<dynamic> _produtosMaisVendidos = [];
  List<dynamic> _ticketMedioDiario = [];
  Map<String, dynamic> _dadosConversao = {};
  List<dynamic> _produtosEstoqueCritico = [];
  Map<String, dynamic> _desempenhoClube = {};
  List<dynamic> _faturamentoCategoria = [];

  final Color corPrimaria = const Color(0xFF1E3A8A);

  @override
  void initState() {
    super.initState();
    _carregarResumo();
  }

  Future<void> _carregarResumo() async {
    setState(() => _isLoading = true);
    try {
      final responseResumo = await http.get(Uri.parse('${widget.baseUrl}/admin/relatorios/resumo'), headers: {'Authorization': 'Bearer ${widget.token}'});
      final responseTopProdutos = await http.get(Uri.parse('${widget.baseUrl}/admin/relatorios/produtos-mais-vendidos'), headers: {'Authorization': 'Bearer ${widget.token}'});
      final responseTicket = await http.get(Uri.parse('${widget.baseUrl}/admin/relatorios/ticket-medio-diario'), headers: {'Authorization': 'Bearer ${widget.token}'});
      final responseConversao = await http.get(Uri.parse('${widget.baseUrl}/admin/relatorios/taxa-conversao'), headers: {'Authorization': 'Bearer ${widget.token}'});
      final responseEstoque = await http.get(Uri.parse('${widget.baseUrl}/admin/relatorios/estoque-critico'), headers: {'Authorization': 'Bearer ${widget.token}'});
      final responseClube = await http.get(Uri.parse('${widget.baseUrl}/admin/relatorios/desempenho-clube'), headers: {'Authorization': 'Bearer ${widget.token}'});
      final responseCategoria = await http.get(Uri.parse('${widget.baseUrl}/admin/relatorios/faturamento-categoria'), headers: {'Authorization': 'Bearer ${widget.token}'});

      if (responseResumo.statusCode == 200) {
        setState(() {
          _dadosResumo = jsonDecode(responseResumo.body) ?? {};
          _produtosMaisVendidos = jsonDecode(responseTopProdutos.body) ?? [];
          _ticketMedioDiario = jsonDecode(responseTicket.body) ?? [];
          _dadosConversao = jsonDecode(responseConversao.body) ?? {};
          _produtosEstoqueCritico = jsonDecode(responseEstoque.body) ?? [];
          _desempenhoClube = jsonDecode(responseClube.body) ?? {};
          _faturamentoCategoria = jsonDecode(responseCategoria.body) ?? [];
          _isLoading = false;
        });
      } else {
        _mostrarErro('Não foi possível carregar os dados analíticos.');
      }
    } catch (e) {
      _mostrarErro('Erro de conexão: $e');
    }
  }

  // --- Função Placeholder para a futura Rota de IA ---
  Future<void> _solicitarInsightsIA() async {
    setState(() => _isGerandoIA = true);
    try {
      final response = await http.get(
        Uri.parse('${widget.baseUrl}/admin/ai-insights'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _insightIA = data['insight'] ?? 'Nenhum insight retornado.';
          _isGerandoIA = false;
        });
      } else {
        setState(() {
          _insightIA = 'Não foi possível conectar à IA do Box Smart no momento.';
          _isGerandoIA = false;
        });
      }
    } catch (e) {
      setState(() {
        _insightIA = 'Erro de comunicação com o servidor de IA.';
        _isGerandoIA = false;
      });
    }
  }

  void _mostrarErro(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red.shade900));
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> resumo = _dadosResumo;
    final Map<String, dynamic> conversao = _dadosConversao;

    final int totalPedidos = resumo['total_pedidos'] ?? 0;
    final double faturamentoTotal = (resumo['faturamento_total'] ?? 0).toDouble();
    final Map<String, dynamic> statusPedidos = resumo['status_pedidos'] ?? {};

    final double taxaConversao = (conversao['taxa_conversao'] ?? 0.0).toDouble();
    final int concluidos = conversao['concluidos'] ?? 0;
    final int totalGeralConv = conversao['total_geral'] ?? 0;

    final Map<String, dynamic> membros = _desempenhoClube['membros'] ?? {};
    final Map<String, dynamic> comuns = _desempenhoClube['comuns'] ?? {};

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Visão Estratégica',
              style: TextStyle(
                color: Color(0xFF1E293B),
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(width: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 200),
              child: const Text(
                'Box Smart Dashboard',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: _carregarResumo,
            tooltip: 'Atualizar Dados',
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: CircleAvatar(
              backgroundColor: Color(0xFF1E3A8A),
              radius: 16,
              child: Text(
                'BS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _carregarResumo,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1300),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSaudacao(),
                  const SizedBox(height: 24),

                  // --- LINHA 1: KPIs Principais (Responsivo) ---
                  LayoutBuilder(
                    builder: (context, constraints) {
                      bool isTelaPequena = constraints.maxWidth < 900;

                      final kpis = [
                        _buildKpiCard('Faturamento Total', 'R\$ ${faturamentoTotal.toStringAsFixed(2)}', 'Atualizado em tempo real', Icons.attach_money, Colors.green),
                        _buildKpiCard('Total de Pedidos', '$totalPedidos', 'Volume transacional', Icons.receipt_long, corPrimaria),
                        _buildKpiCard('Média por Pedido', totalPedidos > 0 ? 'R\$ ${(faturamentoTotal / totalPedidos).toStringAsFixed(2)}' : 'R\$ 0.00', 'Ticket médio geral', Icons.analytics_outlined, Colors.purple),
                        _buildKpiCard('Taxa de Conversão', '${taxaConversao.toStringAsFixed(1)}%', '$concluidos concluídos de $totalGeralConv', Icons.trending_up, Colors.blue),
                      ];

                      if (isTelaPequena) {
                        return Column(
                          children: [
                            Row(children: [Expanded(child: kpis[0]), const SizedBox(width: 16), Expanded(child: kpis[1])]),
                            const SizedBox(height: 16),
                            Row(children: [Expanded(child: kpis[2]), const SizedBox(width: 16), Expanded(child: kpis[3])]),
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(child: kpis[0]), const SizedBox(width: 16),
                          Expanded(child: kpis[1]), const SizedBox(width: 16),
                          Expanded(child: kpis[2]), const SizedBox(width: 16),
                          Expanded(child: kpis[3]),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // --- LINHA 2: NOVO PAINEL SMART IA ---
                  _buildAreaInteligenciaArtificial(),
                  const SizedBox(height: 24),

                  // --- LINHA 3: Desempenho do Clube (Responsivo) ---
                  LayoutBuilder(
                    builder: (context, constraints) {
                      bool isTelaPequena = constraints.maxWidth < 700;

                      final cardPrime = _buildKpiCard(
                        'Faturamento - Clube Prime',
                        'R\$ ${(membros['faturamento'] ?? 0.0).toStringAsFixed(2)}',
                        '${membros['total_pedidos'] ?? 0} pedidos | Ticket: R\$ ${(membros['ticket_medio'] ?? 0.0).toStringAsFixed(2)}',
                        Icons.workspace_premium,
                        Colors.amber.shade700,
                      );

                      final cardComuns = _buildKpiCard(
                        'Faturamento - Comuns',
                        'R\$ ${(comuns['faturamento'] ?? 0.0).toStringAsFixed(2)}',
                        '${comuns['total_pedidos'] ?? 0} pedidos | Ticket: R\$ ${(comuns['ticket_medio'] ?? 0.0).toStringAsFixed(2)}',
                        Icons.person_outline,
                        Colors.blueGrey,
                      );

                      if (isTelaPequena) {
                        return Column(
                          children: [
                            cardPrime,
                            const SizedBox(height: 16),
                            cardComuns,
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(child: cardPrime),
                          const SizedBox(width: 16),
                          Expanded(child: cardComuns),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // --- LINHA 4: Gráficos de Status + Estoque (Responsivo) ---
                  LayoutBuilder(
                    builder: (context, constraints) {
                      bool isTelaPequena = constraints.maxWidth < 900;

                      final cardStatus = _buildCardPadrao(
                        titulo: 'Status dos Pedidos',
                        height: 350,
                        child: _buildGraficoStatus(statusPedidos),
                      );

                      final cardEstoque = _buildCardPadrao(
                        titulo: 'Estoque Crítico (${_produtosEstoqueCritico.length} itens)',
                        height: 350,
                        child: _buildListaEstoque(),
                      );

                      if (isTelaPequena) {
                        return Column(
                          children: [
                            cardStatus,
                            const SizedBox(height: 24),
                            cardEstoque,
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 1, child: cardStatus),
                          const SizedBox(width: 24),
                          Expanded(flex: 1, child: cardEstoque),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // --- LINHA 5: Evolução + Top Produtos (Responsivo) ---
                  LayoutBuilder(
                    builder: (context, constraints) {
                      bool isTelaPequena = constraints.maxWidth < 900;

                      final cardEvolucao = _buildCardPadrao(
                        titulo: 'Evolução Diária de Vendas',
                        height: 380,
                        child: _buildGraficoEvolucao(),
                      );

                      final cardTopProdutos = _buildCardPadrao(
                        titulo: 'Top 5 Mais Vendidos',
                        height: 380,
                        child: _buildListaTopProdutos(),
                      );

                      if (isTelaPequena) {
                        return Column(
                          children: [
                            cardEvolucao,
                            const SizedBox(height: 24),
                            cardTopProdutos,
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: cardEvolucao),
                          const SizedBox(width: 24),
                          Expanded(flex: 2, child: cardTopProdutos),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // --- LINHA 6: Categoria ---
                  _buildCardPadrao(titulo: 'Faturamento por Categoria', height: 380, child: _buildGraficoCategoria()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // FORMATAÇÃO E NORMALIZAÇÃO DE STATUS
  // ==========================================

  String _formatarNomeStatus(String statusTecnico) {
    final s = statusTecnico.toLowerCase().trim();
    if (s.contains('concluido') || s.contains('concluído')) return 'Concluído';
    if (s.contains('cancelado')) return 'Cancelado';
    if (s.contains('saiu') || s.contains('entrega')) return 'Saiu para Entrega';
    if (s.contains('separacao') || s.contains('separação') || s.contains('pendente')) return 'Aguardando Separação';
    if (s.contains('separado')) return 'Separado';

    return statusTecnico
        .replaceAll('_', ' ')
        .split(' ')
        .map((str) => str.isNotEmpty ? '${str[0].toUpperCase()}${str.substring(1)}' : '')
        .join(' ');
  }

  Map<String, double> _normalizarStatusPedidos(Map<String, dynamic> statusMap) {
    Map<String, double> mapaConsolidado = {};

    statusMap.forEach((chave, valor) {
      String nomeAmigavel = _formatarNomeStatus(chave);
      double qtd = (valor as num).toDouble();

      if (mapaConsolidado.containsKey(nomeAmigavel)) {
        mapaConsolidado[nomeAmigavel] = mapaConsolidado[nomeAmigavel]! + qtd;
      } else {
        mapaConsolidado[nomeAmigavel] = qtd;
      }
    });

    return mapaConsolidado;
  }

  // ==========================================
  // WIDGETS E COMPONENTES VISUAIS
  // ==========================================

  Widget _buildSaudacao() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Olá, Gestor!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
        const SizedBox(height: 4),
        Text('Aqui estão os indicadores em tempo real para as tomadas de decisão.', style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
      ],
    );
  }

  Widget _buildAreaInteligenciaArtificial() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [const Color(0xFF4F46E5), corPrimaria], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: corPrimaria.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle), child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20)),
              const SizedBox(width: 12),
              const Text('Box Smart AI Insights', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          _isGerandoIA
              ? const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: CircularProgressIndicator(color: Colors.white)))
              : Text(_insightIA, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 15, height: 1.5)),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _isGerandoIA ? null : _solicitarInsightsIA,
              icon: const Icon(Icons.analytics, color: Color(0xFF1E3A8A), size: 16),
              label: const Text('Solicitar Nova Análise', style: TextStyle(color: Color(0xFF1E3A8A), fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildCardPadrao({required String titulo, required double height, required Widget child}) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
          const SizedBox(height: 20),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildKpiCard(String title, String value, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 24)),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color), overflow: TextOverflow.ellipsis),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  // ==========================================
  // CONSTRUÇÃO DE DADOS (GRÁFICOS E LISTAS)
  // ==========================================

  Widget _buildListaEstoque() {
    if (_produtosEstoqueCritico.isEmpty) return const Center(child: Text('Nenhum produto em nível crítico!', style: TextStyle(color: Colors.grey)));
    return ListView.builder(
      itemCount: _produtosEstoqueCritico.length,
      itemBuilder: (context, index) {
        final prod = _produtosEstoqueCritico[index];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(backgroundColor: Colors.red.withOpacity(0.1), child: const Icon(Icons.warning, color: Colors.red, size: 18)),
          title: Text(prod['nome'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          subtitle: Text('R\$ ${(prod['preco'] ?? 0.0).toStringAsFixed(2)}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
            child: Text('${prod['estoque']} un', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        );
      },
    );
  }

  Widget _buildListaTopProdutos() {
    if (_produtosMaisVendidos.isEmpty) return const Center(child: Text('Nenhuma venda registrada.', style: TextStyle(color: Colors.grey)));
    return ListView.builder(
      itemCount: _produtosMaisVendidos.length,
      itemBuilder: (context, index) {
        final prod = _produtosMaisVendidos[index];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(backgroundColor: corPrimaria.withOpacity(0.1), child: Text('${index + 1}', style: TextStyle(color: corPrimaria, fontWeight: FontWeight.bold))),
          title: Text(prod['nome'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          trailing: Text('${prod['quantidade']} vendidos', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 13)),
        );
      },
    );
  }

  Widget _buildGraficoStatus(Map<String, dynamic> statusPedidos) {
    if (statusPedidos.isEmpty) return const Center(child: Text('Nenhum pedido.', style: TextStyle(color: Colors.grey)));

    final statusNormalizado = _normalizarStatusPedidos(statusPedidos);

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              sections: _criarSecoesGrafico(statusNormalizado),
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: statusNormalizado.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _corParaStatus(entry.key),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${entry.key} (${entry.value.toInt()})',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildGraficoEvolucao() {
    if (_ticketMedioDiario.isEmpty) return const Center(child: Text('Sem dados diários.', style: TextStyle(color: Colors.grey)));
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: _calcularMaxY(),
        barTouchData: BarTouchData(enabled: true),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (value, meta) {
            int idx = value.toInt();
            if (idx >= 0 && idx < _ticketMedioDiario.length) {
              String dataStr = _ticketMedioDiario[idx]['data'];
              List<String> p = dataStr.split('-');
              return Padding(padding: const EdgeInsets.only(top: 8.0), child: Text(p.length == 3 ? '${p[2]}/${p[1]}' : dataStr, style: const TextStyle(fontSize: 11, color: Colors.grey)));
            }
            return const Text('');
          })),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 45, getTitlesWidget: (value, meta) {
            return Text('R\$${value.toInt()}', style: const TextStyle(fontSize: 11, color: Colors.grey));
          })),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: true, drawVerticalLine: false), borderData: FlBorderData(show: false), barGroups: _criarBarrasDiarias(),
      ),
    );
  }

  Widget _buildGraficoCategoria() {
    if (_faturamentoCategoria.isEmpty) return const Center(child: Text('Sem dados de categorias.', style: TextStyle(color: Colors.grey)));
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: _calcularMaxYCategoria(),
        barTouchData: BarTouchData(enabled: true),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (value, meta) {
            int idx = value.toInt();
            if (idx >= 0 && idx < _faturamentoCategoria.length) {
              String nome = _faturamentoCategoria[idx]['categoria'] ?? '';
              return Padding(padding: const EdgeInsets.only(top: 8.0), child: Text(nome.length > 10 ? '${nome.substring(0, 9)}.' : nome, style: const TextStyle(fontSize: 11, color: Colors.grey)));
            }
            return const Text('');
          })),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 50, getTitlesWidget: (value, meta) {
            return Text('R\$${value.toInt()}', style: const TextStyle(fontSize: 11, color: Colors.grey));
          })),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: true, drawVerticalLine: false), borderData: FlBorderData(show: false), barGroups: _criarBarrasCategorias(),
      ),
    );
  }

  // --- Funções Auxiliares de Cálculo ---
  double _calcularMaxY() {
    if (_ticketMedioDiario.isEmpty) return 100.0;
    double max = 0;
    for (var item in _ticketMedioDiario) { double fat = (item['faturamento'] ?? 0).toDouble(); if (fat > max) max = fat; }
    return max == 0 ? 100.0 : max * 1.2;
  }

  double _calcularMaxYCategoria() {
    if (_faturamentoCategoria.isEmpty) return 100.0;
    double max = 0;
    for (var item in _faturamentoCategoria) { double fat = (item['faturamento'] ?? 0).toDouble(); if (fat > max) max = fat; }
    return max == 0 ? 100.0 : max * 1.2;
  }

  List<BarChartGroupData> _criarBarrasDiarias() {
    return List.generate(_ticketMedioDiario.length, (i) {
      return BarChartGroupData(x: i, barRods: [BarChartRodData(toY: (_ticketMedioDiario[i]['faturamento'] ?? 0).toDouble(), color: corPrimaria, width: 20, borderRadius: const BorderRadius.vertical(top: Radius.circular(6)))]);
    });
  }

  List<BarChartGroupData> _criarBarrasCategorias() {
    return List.generate(_faturamentoCategoria.length, (i) {
      return BarChartGroupData(x: i, barRods: [BarChartRodData(toY: (_faturamentoCategoria[i]['faturamento'] ?? 0).toDouble(), color: Colors.teal, width: 22, borderRadius: const BorderRadius.vertical(top: Radius.circular(6)))]);
    });
  }

  List<PieChartSectionData> _criarSecoesGrafico(Map<String, dynamic> statusMap) {
    return statusMap.entries.map((entry) {
      final double valor = (entry.value as num).toDouble();
      return PieChartSectionData(
        color: _corParaStatus(entry.key),
        value: valor,
        title: '${valor.toInt()}',
        radius: 45,
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      );
    }).toList();
  }

  Color _corParaStatus(String status) {
    final s = status.toLowerCase();
    if (s.contains('concluído') || s.contains('concluido')) return Colors.green;
    if (s.contains('cancelado')) return Colors.red;
    if (s.contains('entrega')) return Colors.blue;
    if (s.contains('separado')) return Colors.purple;
    return Colors.orange; // Cor padrão para pendentes / aguardando separação
  }
}