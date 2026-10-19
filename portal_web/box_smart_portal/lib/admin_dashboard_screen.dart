import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

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
  bool _isGerandoIA = false;
  String _insightIA =
      'Analisando o fluxo recente e as tendências do setor supermercadista para gerar recomendações estratégicas...';

  // 🌟 Estado do filtro de período
  String _filtroPeriodo = 'todos'; // 'hoje', '7dias', 'este_mes', 'todos'

  // Variáveis dos Relatórios Tradicionais
  Map<String, dynamic> _dadosResumo = {};
  List<dynamic> _produtosMaisVendidos = [];
  List<dynamic> _ticketMedioDiario = [];
  Map<String, dynamic> _dadosConversao = {};
  List<dynamic> _produtosEstoqueCritico = [];
  Map<String, dynamic> _desempenhoClube = {};
  List<dynamic> _faturamentoCategoria = [];

  // 🌟 Variáveis de BI & IA Avançadas
  Map<String, dynamic> _dadosLeadTime = {};
  Map<String, dynamic> _dadosChurn = {};
  List<dynamic> _dadosPrevisaoDemanda = [];
  Map<String, dynamic> _dadosVendasAcumuladas = {}; // 📈 NOVO: Vendas Acumuladas

  final Color corPrimaria = const Color(0xFF1E3A8A);
  final Color corDarkSlate = const Color(0xFF0F172A);

  final NumberFormat _formatoMoeda = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$',
  );

  @override
  void initState() {
    super.initState();
    _carregarResumo();
  }

  // 🌟 Gera os parâmetros de data para filtrar as consultas no backend
  Map<String, String> _obterParamsData() {
    final agora = DateTime.now();
    final formatoData = DateFormat('yyyy-MM-dd');

    switch (_filtroPeriodo) {
      case 'hoje':
        final hojeStr = formatoData.format(agora);
        return {'data_inicio': hojeStr, 'data_fim': hojeStr};
      case '7dias':
        final seteDiasAtras = agora.subtract(const Duration(days: 7));
        return {
          'data_inicio': formatoData.format(seteDiasAtras),
          'data_fim': formatoData.format(agora),
        };
      case 'este_mes':
        final primeiroDiaMes = DateTime(agora.year, agora.month, 1);
        return {
          'data_inicio': formatoData.format(primeiroDiaMes),
          'data_fim': formatoData.format(agora),
        };
      default:
        return {}; // 'todos' - sem restrição de data
    }
  }

  // 🌟 Auxiliar para montar a URI completa com query parameters
  Uri _montarUri(String rota) {
    final base = Uri.parse('${widget.baseUrl}$rota');
    final params = _obterParamsData();
    if (params.isEmpty) return base;
    return base.replace(queryParameters: params);
  }

  Future<void> _carregarResumo() async {
    setState(() => _isLoading = true);
    try {
      final headers = {'Authorization': 'Bearer ${widget.token}'};

      final responseResumo = await http.get(_montarUri('/admin/relatorios/resumo'), headers: headers);
      final responseTopProdutos = await http.get(_montarUri('/admin/relatorios/produtos-mais-vendidos'), headers: headers);
      final responseTicket = await http.get(_montarUri('/admin/relatorios/ticket-medio-diario'), headers: headers);
      final responseConversao = await http.get(_montarUri('/admin/relatorios/taxa-conversao'), headers: headers);
      final responseEstoque = await http.get(_montarUri('/admin/relatorios/estoque-critico'), headers: headers);
      final responseClube = await http.get(_montarUri('/admin/relatorios/desempenho-clube'), headers: headers);
      final responseCategoria = await http.get(_montarUri('/admin/relatorios/faturamento-categoria'), headers: headers);

      // 🌟 Requisições das Métricas Avançadas de BI & IA
      final responseLeadTime = await http.get(_montarUri('/admin/relatorios/lead-time'), headers: headers);
      final responseChurn = await http.get(_montarUri('/admin/relatorios/risco-churn'), headers: headers);
      final responsePrevisao = await http.get(_montarUri('/admin/relatorios/previsao-demanda'), headers: headers);
      final responseAcumuladas = await http.get(_montarUri('/admin/relatorios/vendas-acumuladas'), headers: headers);

      if (responseResumo.statusCode == 200) {
        setState(() {
          _dadosResumo = jsonDecode(responseResumo.body) ?? {};
          _produtosMaisVendidos = jsonDecode(responseTopProdutos.body) ?? [];
          _ticketMedioDiario = jsonDecode(responseTicket.body) ?? [];
          _dadosConversao = jsonDecode(responseConversao.body) ?? {};
          _produtosEstoqueCritico = jsonDecode(responseEstoque.body) ?? [];
          _desempenhoClube = jsonDecode(responseClube.body) ?? {};
          _faturamentoCategoria = jsonDecode(responseCategoria.body) ?? [];

          // Guardando respostas de BI & IA
          _dadosLeadTime = jsonDecode(responseLeadTime.body) ?? {};
          _dadosChurn = jsonDecode(responseChurn.body) ?? {};
          _dadosPrevisaoDemanda = jsonDecode(responsePrevisao.body) ?? [];
          _dadosVendasAcumuladas = jsonDecode(responseAcumuladas.body) ?? {};

          _isLoading = false;
        });
      } else {
        _mostrarErro('Não foi possível carregar os dados analíticos.');
      }
    } catch (e) {
      _mostrarErro('Erro de conexão: $e');
    }
  }

  Future<void> _solicitarInsightsIA() async {
    setState(() => _isGerandoIA = true);
    try {
      final response = await http.get(
        _montarUri('/admin/ai-insights'),
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

  Future<void> _notificarClienteChurn(int clienteId, String nomeCliente) async {
    try {
      final response = await http.post(
        Uri.parse('${widget.baseUrl}/admin/notificacoes/churn/$clienteId'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Notificação de reconquista enviada para $nomeCliente!'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      } else {
        _mostrarErro('Falha ao enviar notificação para $nomeCliente.');
      }
    } catch (e) {
      _mostrarErro('Erro de conexão com o servidor: $e');
    }
  }

  void _mostrarErro(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFFB91C1C),
      ),
    );
  }

  String _formatarNomeStatus(String statusTecnico) {
    final s = statusTecnico.toLowerCase().trim();
    if (s.contains('concluido') || s.contains('concluído') || s.contains('entregue')) {
      return 'Concluído';
    }
    if (s.contains('cancelado')) return 'Cancelado';
    if (s.contains('saiu') || s.contains('entrega') || s.contains('transito') || s.contains('trânsito')) {
      return 'Saiu para Entrega';
    }
    if (s.contains('em_separacao') || s.contains('em separação')) {
      return 'Em Separação';
    }
    if (s.contains('separado')) return 'Separado';
    if (s.contains('pendente')) return 'Pendente';

    return statusTecnico
        .replaceAll('_', ' ')
        .split(' ')
        .map((str) => str.isNotEmpty ? '${str[0].toUpperCase()}${str.substring(1).toLowerCase()}' : '')
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

  Color _corParaStatus(String status) {
    final s = status.toLowerCase();
    if (s.contains('concluído') || s.contains('concluido') || s.contains('entregue')) {
      return const Color(0xFF10B981);
    }
    if (s.contains('cancelado')) {
      return const Color(0xFFEF4444);
    }
    if (s.contains('entrega')) {
      return const Color(0xFF0284C7);
    }
    if (s.contains('separado')) {
      return const Color(0xFF8B5CF6);
    }
    if (s.contains('em separação')) {
      return const Color(0xFF6366F1);
    }
    return const Color(0xFFF59E0B);
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
        scrolledUnderElevation: 0.5,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Visão Estratégica & BI',
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w800,
                fontSize: 18,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              'Box Smart AI Dashboard',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 11,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 20, color: Color(0xFF334155)),
              onPressed: _carregarResumo,
              tooltip: 'Atualizar Dados',
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 16.0, left: 4.0),
            child: CircleAvatar(
              backgroundColor: Color(0xFF1E3A8A),
              radius: 16,
              child: Text(
                'BS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(color: Color(0xFF1E3A8A)),
      )
          : RefreshIndicator(
        onRefresh: _carregarResumo,
        color: const Color(0xFF1E3A8A),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20.0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1300),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSaudacao(),
                  const SizedBox(height: 16),

                  // BARRA DE FILTROS DE PERÍODO
                  _buildFiltrosPeriodo(),
                  const SizedBox(height: 20),

                  // --- LINHA 1: KPIs Principais ---
                  LayoutBuilder(
                    builder: (context, constraints) {
                      bool isTelaPequena = constraints.maxWidth < 900;

                      final kpis = [
                        _buildKpiCard(
                          'Faturamento Total',
                          _formatoMoeda.format(faturamentoTotal),
                          'Atualizado em tempo real',
                          Icons.account_balance_wallet_rounded,
                          const Color(0xFF10B981),
                          const Color(0xFFECFDF5),
                        ),
                        _buildKpiCard(
                          'Total de Pedidos',
                          '$totalPedidos',
                          'Volume transacional',
                          Icons.receipt_long_rounded,
                          corPrimaria,
                          const Color(0xFFEFF6FF),
                        ),
                        _buildKpiCard(
                          'Média por Pedido',
                          totalPedidos > 0
                              ? _formatoMoeda.format(faturamentoTotal / totalPedidos)
                              : 'R\$ 0,00',
                          'Ticket médio geral',
                          Icons.analytics_rounded,
                          const Color(0xFF8B5CF6),
                          const Color(0xFFF5F3FF),
                        ),
                        _buildKpiCard(
                          'Taxa de Conversão',
                          '${taxaConversao.toStringAsFixed(1)}%',
                          '$concluidos concluídos de $totalGeralConv',
                          Icons.trending_up_rounded,
                          const Color(0xFF0284C7),
                          const Color(0xFFE0F2FE),
                        ),
                      ];

                      if (isTelaPequena) {
                        return Column(
                          children: [
                            Row(
                              children: [
                                Expanded(child: kpis[0]),
                                const SizedBox(width: 12),
                                Expanded(child: kpis[1]),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(child: kpis[2]),
                                const SizedBox(width: 12),
                                Expanded(child: kpis[3]),
                              ],
                            ),
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(child: kpis[0]),
                          const SizedBox(width: 12),
                          Expanded(child: kpis[1]),
                          const SizedBox(width: 12),
                          Expanded(child: kpis[2]),
                          const SizedBox(width: 12),
                          Expanded(child: kpis[3]),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  // --- LINHA 2: PAINEL DE LEAD TIME LOGÍSTICO ---
                  _buildBlocoLeadTime(),
                  const SizedBox(height: 20),

                  // --- LINHA 3: CONSULTORIA SMART IA + PREVISÃO DE DEMANDA ---
                  LayoutBuilder(
                    builder: (context, constraints) {
                      bool isTelaPequena = constraints.maxWidth < 900;
                      final areaIA = _buildAreaInteligenciaArtificial();
                      final areaDemanda = _buildBlocoPrevisaoDemanda();

                      if (isTelaPequena) {
                        return Column(
                          children: [
                            areaIA,
                            const SizedBox(height: 20),
                            areaDemanda,
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: areaIA),
                          const SizedBox(width: 20),
                          Expanded(flex: 2, child: areaDemanda),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  // --- LINHA 4: GRÁFICO DE VENDAS ACUMULADAS VS META (NOVO) ---
                  _buildCardPadrao(
                    titulo: '📈 Vendas Acumuladas vs. Meta no Período',
                    height: 380,
                    child: _buildGraficoVendasAcumuladas(),
                  ),
                  const SizedBox(height: 20),

                  // --- LINHA 5: Desempenho do Clube Prime + Comuns ---
                  LayoutBuilder(
                    builder: (context, constraints) {
                      bool isTelaPequena = constraints.maxWidth < 700;

                      final cardPrime = _buildKpiCard(
                        'Faturamento - Clube Prime',
                        _formatoMoeda.format((membros['faturamento'] ?? 0.0).toDouble()),
                        '${membros['total_pedidos'] ?? 0} pedidos | Ticket: ${_formatoMoeda.format((membros['ticket_medio'] ?? 0.0).toDouble())}',
                        Icons.workspace_premium_rounded,
                        const Color(0xFFD97706),
                        const Color(0xFFFEF3C7),
                      );

                      final cardComuns = _buildKpiCard(
                        'Faturamento - Comuns',
                        _formatoMoeda.format((comuns['faturamento'] ?? 0.0).toDouble()),
                        '${comuns['total_pedidos'] ?? 0} pedidos | Ticket: ${_formatoMoeda.format((comuns['ticket_medio'] ?? 0.0).toDouble())}',
                        Icons.person_outline_rounded,
                        const Color(0xFF475569),
                        const Color(0xFFF1F5F9),
                      );

                      if (isTelaPequena) {
                        return Column(
                          children: [
                            cardPrime,
                            const SizedBox(height: 12),
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
                  const SizedBox(height: 20),

                  // --- LINHA 6: RISCO DE CHURN DE CLIENTES PRIME ---
                  _buildBlocoRiscoChurn(),
                  const SizedBox(height: 20),

                  // --- LINHA 7: Gráficos de Status + Estoque Crítico ---
                  LayoutBuilder(
                    builder: (context, constraints) {
                      bool isTelaPequena = constraints.maxWidth < 900;

                      final cardStatus = _buildCardPadrao(
                        titulo: 'Status dos Pedidos',
                        height: 360,
                        child: _buildGraficoStatus(statusPedidos),
                      );

                      final cardEstoque = _buildCardPadrao(
                        titulo: 'Estoque Crítico (${_produtosEstoqueCritico.length} itens)',
                        height: 360,
                        child: _buildListaEstoque(),
                      );

                      if (isTelaPequena) {
                        return Column(
                          children: [
                            cardStatus,
                            const SizedBox(height: 20),
                            cardEstoque,
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 1, child: cardStatus),
                          const SizedBox(width: 20),
                          Expanded(flex: 1, child: cardEstoque),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  // --- LINHA 8: Evolução + Top Produtos ---
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
                            const SizedBox(height: 20),
                            cardTopProdutos,
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: cardEvolucao),
                          const SizedBox(width: 20),
                          Expanded(flex: 2, child: cardTopProdutos),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  // --- LINHA 9: Faturamento por Categoria ---
                  _buildCardPadrao(
                    titulo: 'Faturamento por Categoria',
                    height: 380,
                    child: _buildGraficoCategoria(),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // WIDGETS E COMPONENTES VISUAIS
  // ==========================================

  Widget _buildSaudacao() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Olá, Gestor!',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
            letterSpacing: -0.4,
          ),
        ),
        SizedBox(height: 2),
        Text(
          'Aqui estão os indicadores em tempo real para as tomadas de decisão.',
          style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
      ],
    );
  }

  Widget _buildFiltrosPeriodo() {
    final filtros = [
      {'label': 'Hoje', 'value': 'hoje'},
      {'label': 'Últimos 7 dias', 'value': '7dias'},
      {'label': 'Este Mês', 'value': 'este_mes'},
      {'label': 'Todo o Histórico', 'value': 'todos'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filtros.map((f) {
          final bool isSelected = _filtroPeriodo == f['value'];
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(
                f['label']!,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF475569),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 12,
                ),
              ),
              selected: isSelected,
              selectedColor: const Color(0xFF1E3A8A),
              backgroundColor: const Color(0xFFF1F5F9),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide.none,
              ),
              showCheckmark: false,
              onSelected: (selected) {
                if (selected && _filtroPeriodo != f['value']) {
                  setState(() {
                    _filtroPeriodo = f['value']!;
                  });
                  _carregarResumo();
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBlocoLeadTime() {
    final num sepMin = _dadosLeadTime['tempo_medio_separacao_minutos'] ?? 0;
    final num entMin = _dadosLeadTime['tempo_medio_entrega_minutos'] ?? 0;
    final num totalMin = _dadosLeadTime['lead_time_total_minutos'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
          const Text(
            '⏱️ Tempo Médio de Ciclo Logístico (Lead Time)',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildItemLeadTime('Separação em Loja', '${sepMin.toStringAsFixed(1)} min', Icons.inventory_2_outlined, Colors.orange),
              _buildItemLeadTime('Tempo de Rota', '${entMin.toStringAsFixed(1)} min', Icons.directions_bike_outlined, Colors.purple),
              _buildItemLeadTime('Ciclo Total do Pedido', '${totalMin.toStringAsFixed(1)} min', Icons.timer_outlined, Colors.green),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemLeadTime(String titulo, String valor, IconData icone, Color cor) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icone, color: cor, size: 22),
            const SizedBox(height: 6),
            Text(valor, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: cor)),
            Text(titulo, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildBlocoPrevisaoDemanda() {
    return _buildCardPadrao(
      titulo: '🔮 Previsão de Demanda (Próximo FDS)',
      height: 340,
      child: _dadosPrevisaoDemanda.isEmpty
          ? const Center(
        child: Text(
          'Sem dados preditivos.',
          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
        ),
      )
          : ListView.separated(
        itemCount: _dadosPrevisaoDemanda.length,
        separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
        itemBuilder: (context, index) {
          final item = _dadosPrevisaoDemanda[index];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    item['produto'] ?? '',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Color(0xFF1E293B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Est. ${item['previsao_proximo_fds']} un',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBlocoRiscoChurn() {
    final List clientes = _dadosChurn['clientes_em_risco'] ?? [];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
              const Text(
                '⚠️️ Alerta de Risco de Churn (Membros do Clube)',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              Chip(
                label: Text(
                  '${_dadosChurn['total_risco_churn'] ?? 0} Inativos',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
                backgroundColor: Colors.red.shade700,
              ),
            ],
          ),
          const SizedBox(height: 12),
          clientes.isEmpty
              ? const Text(
            'Nenhum membro do clube em risco de inatividade no momento.',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
          )
              : ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: clientes.length,
            separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
            itemBuilder: (context, index) {
              final c = clientes[index];
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: Colors.red.shade50,
                  child: Icon(Icons.person_off_outlined, color: Colors.red.shade700, size: 18),
                ),
                title: Text(c['nome'] ?? 'Cliente', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Sem comprar há ${c['dias_sem_comprar']} dias (${c['ultimo_pedido_data']})'),
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    elevation: 0,
                  ),
                  onPressed: () => _notificarClienteChurn(
                    c['cliente_id'] ?? 0,
                    c['nome'] ?? 'Cliente',
                  ),
                  child: const Text('Notificar', style: TextStyle(color: Colors.white, fontSize: 11)),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAreaInteligenciaArtificial() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E1B4B), Color(0xFF312E81)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF312E81).withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: CircleAvatar(
              radius: 60,
              backgroundColor: Colors.white.withOpacity(0.03),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF818CF8).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF818CF8).withOpacity(0.3),
                            ),
                          ),
                          child: const Icon(
                            Icons.auto_awesome_rounded,
                            color: Color(0xFFA5B4FC),
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Box Smart AI Insights',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF10B981).withOpacity(0.4),
                        ),
                      ),
                      child: const Text(
                        'LIVE',
                        style: TextStyle(
                          color: Color(0xFF34D399),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _isGerandoIA
                    ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFFA5B4FC)),
                  ),
                )
                    : Text(
                  _insightIA,
                  style: const TextStyle(
                    color: Color(0xFFE2E8F0),
                    fontSize: 13,
                    height: 1.5,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: _isGerandoIA ? null : _solicitarInsightsIA,
                    icon: const Icon(Icons.analytics_rounded, color: Color(0xFF0F172A), size: 16),
                    label: const Text(
                      'Solicitar Nova Análise',
                      style: TextStyle(
                        color: Color(0xFF0F172A),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    ),
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardPadrao({
    required String titulo,
    required double height,
    required Widget child,
  }) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
          Text(
            titulo,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildKpiCard(
      String title,
      String value,
      String subtitle,
      IconData icon,
      Color color,
      Color bgColor,
      ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.03),
            blurRadius: 12,
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
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ==========================================
  // CONSTRUÇÃO DE DADOS (GRÁFICOS E LISTAS)
  // ==========================================

  // 🌟 NOVO WIDGET: GRÁFICO DE VENDAS ACUMULADAS
  Widget _buildGraficoVendasAcumuladas() {
    final List serie = _dadosVendasAcumuladas['serie_historica'] ?? [];
    final double metaFaturamento = (_dadosVendasAcumuladas['meta_faturamento'] ?? 250000.0).toDouble();

    if (serie.isEmpty) {
      return const Center(
        child: Text(
          'Sem dados de vendas acumuladas no período.',
          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
        ),
      );
    }

    // Calcula valor máximo no Y para escala
    double maxVenda = 0.0;
    for (var item in serie) {
      double ac = (item['venda_acumulada'] ?? 0.0).toDouble();
      if (ac > maxVenda) maxVenda = ac;
    }
    double maxY = maxVenda > metaFaturamento ? maxVenda * 1.15 : metaFaturamento * 1.15;
    if (maxY == 0) maxY = 10000;

    return Column(
      children: [
        // Legenda Superior
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _buildLegendaItem('Período Atual', const Color(0xFF1E3A8A)),
            const SizedBox(width: 14),
            _buildLegendaItem('Período Anterior', const Color(0xFFE91E63)),
            const SizedBox(width: 14),
            _buildLegendaItem('Meta', Colors.amber, isDashed: true),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: LineChart(
            LineChartData(
              maxY: maxY,
              minY: 0,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) => const FlLine(
                  color: Color(0xFFF1F5F9),
                  strokeWidth: 1,
                ),
              ),
              titlesData: FlTitlesData(
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 55,
                    getTitlesWidget: (value, meta) {
                      if (value == 0) return const SizedBox.shrink();
                      return Text(
                        'R\$ ${(value / 1000).toStringAsFixed(0)}k',
                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      int idx = value.toInt();
                      if (idx >= 0 && idx < serie.length) {
                        String diaStr = serie[idx]['dia'] ?? '';
                        List<String> p = diaStr.split('/');
                        String label = p.length >= 2 ? '${p[0]}/${p[1]}' : diaStr;
                        return Padding(
                          padding: const EdgeInsets.only(top: 6.0),
                          child: Text(
                            label,
                            style: const TextStyle(color: Color(0xFF64748B), fontSize: 10),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),

              // 🌟 Linha Horizontal de Meta
              extraLinesData: ExtraLinesData(
                horizontalLines: [
                  HorizontalLine(
                    y: metaFaturamento,
                    color: Colors.amber.shade700,
                    strokeWidth: 2,
                    dashArray: [8, 4],
                    label: HorizontalLineLabel(
                      show: true,
                      alignment: Alignment.topRight,
                      style: TextStyle(
                        color: Colors.amber.shade900,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      labelResolver: (line) =>
                      'META: R\$ ${(metaFaturamento / 1000).toStringAsFixed(0)}k',
                    ),
                  ),
                ],
              ),

              // 🌟 Séries do Gráfico (Venda Acumulada x Período Anterior)
              lineBarsData: [
                // 1. Linha do Período Atual (Azul)
                LineChartBarData(
                  spots: List.generate(serie.length, (i) {
                    double val = (serie[i]['venda_acumulada'] ?? 0.0).toDouble();
                    return FlSpot(i.toDouble(), val);
                  }),
                  isCurved: true,
                  color: const Color(0xFF1E3A8A),
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: const Color(0xFF1E3A8A).withOpacity(0.12),
                  ),
                ),

                // 2. Linha do Período Anterior (Rosa)
                LineChartBarData(
                  spots: List.generate(serie.length, (i) {
                    double val = (serie[i]['projecao_periodo_anterior'] ?? 0.0).toDouble();
                    return FlSpot(i.toDouble(), val);
                  }),
                  isCurved: true,
                  color: const Color(0xFFE91E63),
                  barWidth: 2,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: false),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLegendaItem(String label, Color color, {bool isDashed = false}) {
    return Row(
      children: [
        Container(
          width: 14,
          height: isDashed ? 3 : 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildListaEstoque() {
    if (_produtosEstoqueCritico.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle_outline_rounded, color: Color(0xFF059669), size: 18),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Estoque saudável. Nenhum item abaixo do limite.',
                style: TextStyle(
                  color: Color(0xFF047857),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: _produtosEstoqueCritico.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
      itemBuilder: (context, index) {
        final prod = _produtosEstoqueCritico[index];
        final double preco = (prod['preco'] ?? 0.0).toDouble();

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      prod['nome'] ?? 'Produto',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      _formatoMoeda.format(preco),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Text(
                  '${prod['estoque']} un restantes',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFB91C1C),
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildListaTopProdutos() {
    if (_produtosMaisVendidos.isEmpty) {
      return const Center(
        child: Text(
          'Nenhuma venda registrada.',
          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
        ),
      );
    }

    return ListView.separated(
      itemCount: _produtosMaisVendidos.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
      itemBuilder: (context, index) {
        final prod = _produtosMaisVendidos[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: index == 0 ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: index == 0 ? const Color(0xFFD97706) : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        prod['nome'] ?? 'Produto',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: Color(0xFF1E293B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${prod['quantidade']} un',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGraficoStatus(Map<String, dynamic> statusPedidos) {
    if (statusPedidos.isEmpty) {
      return const Center(
        child: Text(
          'Nenhum pedido.',
          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
        ),
      );
    }

    final statusNormalizado = _normalizarStatusPedidos(statusPedidos);

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 36,
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
                padding: const EdgeInsets.symmetric(vertical: 5.0),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _corParaStatus(entry.key),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${entry.key} (${entry.value.toInt()})',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF334155),
                        ),
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
    if (_ticketMedioDiario.isEmpty) {
      return const Center(
        child: Text(
          'Sem dados diários.',
          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
        ),
      );
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: _calcularMaxY(),
        barTouchData: BarTouchData(enabled: true),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                int idx = value.toInt();
                if (idx >= 0 && idx < _ticketMedioDiario.length) {
                  String dataStr = _ticketMedioDiario[idx]['data'];
                  List<String> p = dataStr.split('-');
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      p.length == 3 ? '${p[2]}/${p[1]}' : dataStr,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              getTitlesWidget: (value, meta) {
                return Text(
                  'R\$ ${value.toInt()}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF94A3B8),
                  ),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => const FlLine(
            color: Color(0xFFF1F5F9),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: _criarBarrasDiarias(),
      ),
    );
  }

  Widget _buildGraficoCategoria() {
    if (_faturamentoCategoria.isEmpty) {
      return const Center(
        child: Text(
          'Sem dados de categorias.',
          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
        ),
      );
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: _calcularMaxYCategoria(),
        barTouchData: BarTouchData(enabled: true),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                int idx = value.toInt();
                if (idx >= 0 && idx < _faturamentoCategoria.length) {
                  String nome = _faturamentoCategoria[idx]['categoria'] ?? '';
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      nome.length > 10 ? '${nome.substring(0, 9)}.' : nome,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              getTitlesWidget: (value, meta) {
                return Text(
                  'R\$ ${value.toInt()}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF94A3B8),
                  ),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => const FlLine(
            color: Color(0xFFF1F5F9),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: _criarBarrasCategorias(),
      ),
    );
  }

  // Auxiliares de Cálculo de Eixos
  double _calcularMaxY() {
    if (_ticketMedioDiario.isEmpty) return 100.0;
    double max = 0;
    for (var item in _ticketMedioDiario) {
      double fat = (item['faturamento'] ?? 0).toDouble();
      if (fat > max) max = fat;
    }
    return max == 0 ? 100.0 : max * 1.2;
  }

  double _calcularMaxYCategoria() {
    if (_faturamentoCategoria.isEmpty) return 100.0;
    double max = 0;
    for (var item in _faturamentoCategoria) {
      double fat = (item['faturamento'] ?? 0).toDouble();
      if (fat > max) max = fat;
    }
    return max == 0 ? 100.0 : max * 1.2;
  }

  List<BarChartGroupData> _criarBarrasDiarias() {
    return List.generate(_ticketMedioDiario.length, (i) {
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: (_ticketMedioDiario[i]['faturamento'] ?? 0).toDouble(),
            color: corPrimaria,
            width: 18,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          ),
        ],
      );
    });
  }

  List<BarChartGroupData> _criarBarrasCategorias() {
    return List.generate(_faturamentoCategoria.length, (i) {
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: (_faturamentoCategoria[i]['faturamento'] ?? 0).toDouble(),
            color: const Color(0xFF0D9488),
            width: 20,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          ),
        ],
      );
    });
  }

  List<PieChartSectionData> _criarSecoesGrafico(Map<String, dynamic> statusMap) {
    return statusMap.entries.map((entry) {
      final double valor = (entry.value as num).toDouble();
      return PieChartSectionData(
        color: _corParaStatus(entry.key),
        value: valor,
        title: '${valor.toInt()}',
        radius: 40,
        titleStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }
}