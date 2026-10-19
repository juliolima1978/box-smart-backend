import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'detalhes_pedido_gestor_screen.dart';

class GerenciarPedidosTab extends StatefulWidget {
  final String baseUrl;
  final String token;

  const GerenciarPedidosTab({
    super.key,
    required this.baseUrl,
    required this.token,
  });

  @override
  State<GerenciarPedidosTab> createState() => _GerenciarPedidosTabState();
}

class _GerenciarPedidosTabState extends State<GerenciarPedidosTab> {
  List<dynamic> _pedidos = [];
  bool _isLoading = true;
  String _filtroStatus = 'TODOS';
  String _termoBusca = '';

  final TextEditingController _buscaController = TextEditingController();

  // 🌟 Formatador de moeda no padrão brasileiro
  final NumberFormat _formatoMoeda = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$',
  );

  @override
  void initState() {
    super.initState();
    _carregarPedidos();
  }

  // 🌟 Formata "SAIU_PARA_ENTREGA" -> "Saiu para Entrega"
  String _formatarStatus(String? status) {
    if (status == null || status.isEmpty) return 'Pendente';
    final s = status.toUpperCase().replaceAll(' ', '_');
    if (s == 'CONCLUIDO' || s == 'ENTREGUE') return 'Concluído';
    if (s == 'SAIU_PARA_ENTREGA' || s == 'EM_ROTA') return 'Saiu p/ Entrega';
    if (s == 'EM_SEPARACAO') return 'Em Separação';
    if (s == 'PENDENTE') return 'Pendente';
    if (s == 'CANCELADO') return 'Cancelado';

    return status
        .replaceAll('_', ' ')
        .toLowerCase()
        .split(' ')
        .map((palavra) => palavra.isNotEmpty
        ? '${palavra[0].toUpperCase()}${palavra.substring(1)}'
        : '')
        .join(' ');
  }

  // 🌟 Cores dinâmicas para os Badges
  Color _obterCorStatus(String? status) {
    final s = status?.toUpperCase().replaceAll(' ', '_') ?? '';
    switch (s) {
      case 'PENDENTE':
        return const Color(0xFFD97706); // Laranja / Âmbar
      case 'EM_SEPARACAO':
      case 'APROVADO':
        return const Color(0xFF1E3A8A); // Azul Primário
      case 'SEPARADO':
        return const Color(0xFF7C3AED); // Roxo
      case 'SAIU_PARA_ENTREGA':
      case 'EM_ROTA':
        return const Color(0xFF0284C7); // Azul Céu
      case 'CONCLUIDO':
      case 'ENTREGUE':
        return const Color(0xFF10B981); // Verde
      case 'CANCELADO':
        return const Color(0xFFEF4444); // Vermelho
      default:
        return const Color(0xFF64748B);
    }
  }

  Color _obterBgCorStatus(String? status) {
    final s = status?.toUpperCase().replaceAll(' ', '_') ?? '';
    switch (s) {
      case 'PENDENTE':
        return const Color(0xFFFEF3C7);
      case 'EM_SEPARACAO':
      case 'APROVADO':
        return const Color(0xFFEFF6FF);
      case 'SEPARADO':
        return const Color(0xFFF5F3FF);
      case 'SAIU_PARA_ENTREGA':
      case 'EM_ROTA':
        return const Color(0xFFE0F2FE);
      case 'CONCLUIDO':
      case 'ENTREGUE':
        return const Color(0xFFECFDF5);
      case 'CANCELADO':
        return const Color(0xFFFEF2F2);
      default:
        return const Color(0xFFF1F5F9);
    }
  }

  Future<void> _carregarPedidos() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('${widget.baseUrl}/admin/pedidos/'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      if (response.statusCode == 200) {
        setState(() {
          _pedidos = jsonDecode(response.body) ?? [];
          _isLoading = false;
        });
      } else {
        _mostrarErro('Erro ao carregar pedidos.');
      }
    } catch (e) {
      _mostrarErro('Erro de conexão: $e');
    }
  }

  Future<void> _atualizarStatus(int pedidoId, String novoStatus) async {
    try {
      final response = await http.put(
        Uri.parse('${widget.baseUrl}/admin/pedidos/$pedidoId/status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: jsonEncode({'status': novoStatus}),
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        _mostrarSucesso('Status do Pedido #$pedidoId atualizado com sucesso!');
        _carregarPedidos();
      } else {
        _mostrarErro('Erro ao atualizar status.');
      }
    } catch (e) {
      _mostrarErro('Erro de conexão: $e');
    }
  }

  void _abrirDetalhesGestor(Map<String, dynamic> pedido) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetalhesPedidoGestorScreen(
          pedido: pedido,
          baseUrl: widget.baseUrl,
          token: widget.token,
        ),
      ),
    );
    _carregarPedidos();
  }

  void _mostrarErro(String mensagem) {
    if (!mounted) return;
    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensagem), backgroundColor: const Color(0xFFB91C1C)));
  }

  void _mostrarSucesso(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensagem), backgroundColor: const Color(0xFF10B981)));
  }

  // --- Indicadores dos Cards KPI ---
  int get _totalPedidos => _pedidos.length;
  int get _totalPendentes => _pedidos.where((p) => (p['status'] ?? '').toString().toUpperCase().replaceAll(' ', '_') == 'PENDENTE').length;
  int get _totalEmSeparacao => _pedidos.where((p) => (p['status'] ?? '').toString().toUpperCase().replaceAll(' ', '_') == 'EM_SEPARACAO').length;
  double get _faturamentoTotal {
    double total = 0.0;
    for (var p in _pedidos) {
      final rawStatus = (p['status'] ?? '').toString().toUpperCase().replaceAll(' ', '_');
      if (rawStatus != 'CANCELADO') {
        total += double.tryParse(p['total']?.toString() ?? '0') ?? 0.0;
      }
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final opcoesFiltro = [
      {'label': 'Todos os Pedidos', 'value': 'TODOS'},
      {'label': 'Pendentes', 'value': 'PENDENTE'},
      {'label': 'Em Separação', 'value': 'EM_SEPARACAO'},
      {'label': 'Saiu p/ Entrega', 'value': 'SAIU_PARA_ENTREGA'},
      {'label': 'Concluídos', 'value': 'CONCLUIDO'},
      {'label': 'Cancelados', 'value': 'CANCELADO'},
    ];

    List<dynamic> pedidosFiltrados = _pedidos.where((pedido) {
      final rawStatus = (pedido['status'] ?? 'PENDENTE').toString().toUpperCase().replaceAll(' ', '_');

      bool passaFiltroAba = true;
      if (_filtroStatus != 'TODOS') {
        if (_filtroStatus == 'CONCLUIDO') {
          passaFiltroAba = rawStatus == 'CONCLUIDO' || rawStatus == 'ENTREGUE';
        } else if (_filtroStatus == 'SAIU_PARA_ENTREGA') {
          passaFiltroAba = rawStatus == 'SAIU_PARA_ENTREGA' || rawStatus == 'EM_ROTA';
        } else {
          passaFiltroAba = rawStatus == _filtroStatus;
        }
      }

      bool passaBusca = true;
      if (_termoBusca.isNotEmpty) {
        final idStr = pedido['id'].toString();
        final clienteNome = (pedido['cliente'] is Map ? pedido['cliente']['nome'] ?? '' : '').toString().toLowerCase();
        passaBusca = idStr.contains(_termoBusca) || clienteNome.contains(_termoBusca.toLowerCase());
      }

      return passaFiltroAba && passaBusca;
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
                    'Gerenciamento de Pedidos',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: -0.4),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Acompanhe o fluxo de pedidos, altere etapas de processamento e gerencie entregas.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Color(0xFF334155)),
                onPressed: _carregarPedidos,
                tooltip: 'Atualizar Pedidos',
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 2. CARDS KPIs
          _buildKpiGrid(),
          const SizedBox(height: 20),

          // 3. BARRA DE FERRAMENTAS E FILTROS DE STATUS
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _buscaController,
                        decoration: InputDecoration(
                          hintText: 'Buscar pedido por ID ou nome do cliente...',
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
                  ],
                ),
                const SizedBox(height: 14),

                // ChoiceChips de Filtro por Status
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: opcoesFiltro.map((opcao) {
                      final selecionado = _filtroStatus == opcao['value'];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(opcao['label']!),
                          selected: selecionado,
                          selectedColor: const Color(0xFF1E3A8A),
                          backgroundColor: const Color(0xFFF1F5F9),
                          labelStyle: TextStyle(
                            color: selecionado ? Colors.white : const Color(0xFF475569),
                            fontWeight: selecionado ? FontWeight.bold : FontWeight.w500,
                            fontSize: 12,
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide.none),
                          showCheckmark: false,
                          onSelected: (bool selected) {
                            if (selected) {
                              setState(() => _filtroStatus = opcao['value']!);
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 4. TABELA / LISTAGEM DE PEDIDOS
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E3A8A)))
                  : pedidosFiltrados.isEmpty
                  ? const Center(child: Text('Nenhum pedido encontrado para este filtro.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 15)))
                  : ListView.separated(
                itemCount: pedidosFiltrados.length,
                separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                itemBuilder: (context, index) {
                  final pedido = pedidosFiltrados[index];
                  final rawStatus = (pedido['status'] ?? 'PENDENTE').toString();
                  final totalPedido = double.tryParse(pedido['total']?.toString() ?? '0') ?? 0.0;

                  String nomeCliente = 'Cliente ID: ${pedido['cliente_id']}';
                  if (pedido['cliente'] is Map) {
                    nomeCliente = pedido['cliente']['nome'] ?? pedido['cliente']['razao_social'] ?? nomeCliente;
                  }

                  final Color corTexto = _obterCorStatus(rawStatus);
                  final Color corFundo = _obterBgCorStatus(rawStatus);

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: corFundo,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: corTexto.withOpacity(0.3)),
                      ),
                      child: Icon(
                        Icons.receipt_long_rounded,
                        color: corTexto,
                        size: 22,
                      ),
                    ),
                    title: Text(
                      'Pedido #${pedido['id']}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B)),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Row(
                        children: [
                          Text(
                            'Cliente: $nomeCliente',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _formatoMoeda.format(totalPedido),
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Badge de Status
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: corFundo,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: corTexto.withOpacity(0.4)),
                          ),
                          child: Text(
                            _formatarStatus(rawStatus),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: corTexto,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF64748B)),
                          onSelected: (valor) {
                            if (valor == 'detalhes') {
                              _abrirDetalhesGestor(pedido);
                            } else {
                              _atualizarStatus(pedido['id'], valor);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'detalhes',
                              child: Row(
                                children: [
                                  Icon(Icons.visibility_outlined, size: 18, color: Color(0xFF1E3A8A)),
                                  SizedBox(width: 8),
                                  Text('Ver Detalhes Completos'),
                                ],
                              ),
                            ),
                            const PopupMenuDivider(),
                            const PopupMenuItem(value: 'PENDENTE', child: Text('Mudar para Pendente')),
                            const PopupMenuItem(value: 'EM_SEPARACAO', child: Text('Mudar para Em Separação')),
                            const PopupMenuItem(value: 'SAIU_PARA_ENTREGA', child: Text('Mudar para Saiu p/ Entrega')),
                            const PopupMenuItem(value: 'CONCLUIDO', child: Text('Mudar para Concluído')),
                            const PopupMenuItem(value: 'CANCELADO', child: Text('Mudar para Cancelado')),
                          ],
                        ),
                      ],
                    ),
                    onTap: () => _abrirDetalhesGestor(pedido),
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
          _buildKpiCard('Total Pedidos', '$_totalPedidos registrados', 'Volume total de pedidos', Icons.receipt_long_rounded, const Color(0xFF1E3A8A), const Color(0xFFEFF6FF)),
          _buildKpiCard('Pendentes', '$_totalPendentes aguardando', 'Aguardando confirmação', Icons.hourglass_top_rounded, const Color(0xFFD97706), const Color(0xFFFEF3C7)),
          _buildKpiCard('Em Separação', '$_totalEmSeparacao na esteira', 'Sendo separados em loja', Icons.inventory_rounded, const Color(0xFF7C3AED), const Color(0xFFF5F3FF)),
          _buildKpiCard('Faturamento Total', _formatoMoeda.format(_faturamentoTotal), 'Pedidos ativos acumulados', Icons.attach_money_rounded, const Color(0xFF10B981), const Color(0xFFECFDF5)),
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