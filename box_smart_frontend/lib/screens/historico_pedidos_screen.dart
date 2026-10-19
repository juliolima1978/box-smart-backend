import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

// 🌟 Importe a tela de acompanhamento criada anteriormente
import 'acompanhar_pedido_screen.dart';

class MeusPedidosScreen extends StatefulWidget {
  final String baseUrl;
  final int clienteId;
  final String token;

  const MeusPedidosScreen({
    super.key,
    required this.baseUrl,
    required this.clienteId,
    required this.token,
  });

  @override
  State<MeusPedidosScreen> createState() => _MeusPedidosScreenState();
}

class _MeusPedidosScreenState extends State<MeusPedidosScreen> {
  List<dynamic> _pedidos = [];
  List<dynamic> _pedidosFiltrados = [];
  bool _isLoading = true;
  String? _filtroStatus;
  final TextEditingController _buscaController = TextEditingController();

  final NumberFormat _formatoMoeda = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$',
  );

  @override
  void initState() {
    super.initState();
    _carregarMeusPedidos();
    _buscaController.addListener(_filtrarLocalmente);
  }

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  String formatarStatus(String? status) {
    if (status == null || status.isEmpty) return 'Pendente';
    return status
        .replaceAll('_', ' ')
        .toLowerCase()
        .split(' ')
        .map((palavra) => palavra.isNotEmpty
        ? '${palavra[0].toUpperCase()}${palavra.substring(1)}'
        : '')
        .join(' ');
  }

  Color _corStatus(String? status) {
    switch (status?.toUpperCase()) {
      case 'CONCLUIDO':
      case 'ENTREGUE':
        return Colors.green;
      case 'CANCELADO':
        return Colors.red;
      case 'EM_SEPARACAO':
      case 'SEPARADO':
        return Colors.purple;
      case 'SAIU_PARA_ENTREGA':
        return Colors.indigo;
      default:
        return Colors.orange;
    }
  }

  void _filtrarLocalmente() {
    final query = _buscaController.text.toLowerCase();
    setState(() {
      _pedidosFiltrados = _pedidos.where((pedido) {
        final idMatch = pedido['id'].toString().contains(query);
        final statusMatch = _filtroStatus == null ||
            pedido['status']?.toString().toUpperCase() == _filtroStatus?.toUpperCase();
        return idMatch && statusMatch;
      }).toList();
    });
  }

  Future<void> _carregarMeusPedidos() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('${widget.baseUrl}/clientes/${widget.clienteId}/pedidos/'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      if (response.statusCode == 200) {
        setState(() {
          _pedidos = jsonDecode(response.body);
          _filtrarLocalmente();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        _mostrarErro('Não foi possível carregar os pedidos.');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _mostrarErro('Erro de conexão: $e');
    }
  }

  String formatarDataPedido(String? dataIso) {
    if (dataIso == null) return 'Recente';
    try {
      DateTime dataUtc = DateTime.parse(dataIso);
      DateTime dataLocal = dataUtc.toLocal();
      return DateFormat('dd/MM/yyyy \'às\' HH:mm').format(dataLocal);
    } catch (e) {
      return dataIso;
    }
  }

  void _mostrarErro(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red.shade900),
    );
  }

  // 🌟 Método auxiliar para abrir a tela de Linha do Tempo
  void _abrirAcompanhamento(int pedidoId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AcompanharPedidoScreen(
          baseUrl: widget.baseUrl,
          token: widget.token,
          pedidoId: pedidoId,
        ),
      ),
    );
  }

  void _exibirDetalhesPedido(Map<String, dynamic> pedido) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final List itens = pedido['itens'] ?? [];
        final status = pedido['status']?.toString();
        final int pedidoId = pedido['id'];

        return Padding(
          padding: EdgeInsets.fromLTRB(
            24.0,
            24.0,
            24.0,
            MediaQuery.of(context).padding.bottom + 24.0,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Pedido #$pedidoId',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _corStatus(status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      formatarStatus(status),
                      style: TextStyle(color: _corStatus(status), fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Realizado em: ${formatarDataPedido(pedido['data_criacao'])}',
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const Divider(height: 28),
              const Text('Itens do Pedido', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B))),
              const SizedBox(height: 8),
              SizedBox(
                height: 160,
                child: ListView.builder(
                  itemCount: itens.length,
                  itemBuilder: (context, index) {
                    final item = itens[index];
                    final double precoUnitario = (item['preco_unitario'] as num? ?? 0.0).toDouble();
                    final int quantidade = (item['quantidade'] as num? ?? 1).toInt();
                    final double totalItem = precoUnitario * quantidade;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${quantidade}x ${item['nome'] ?? item['nome_produto'] ?? 'Produto'}',
                              style: const TextStyle(fontSize: 14, color: Color(0xFF334155)),
                            ),
                          ),
                          Text(
                            _formatoMoeda.format(totalItem),
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const Divider(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total do Pedido', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                  Text(
                    _formatoMoeda.format((pedido['total'] as num? ?? 0.0).toDouble()),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 🌟 Botão para abrir a Linha do Tempo a partir do Modal
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.timeline_rounded, color: Colors.white, size: 20),
                  label: const Text('Ver Linha do Tempo Detalhada', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    Navigator.pop(context);
                    _abrirAcompanhamento(pedidoId);
                  },
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Fechar', style: TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Meus Pedidos', style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF1E293B)),
            onPressed: _carregarMeusPedidos,
            tooltip: 'Atualizar Pedidos',
          ),
        ],
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
      ),
      body: Column(
        children: [
          // Filtros e Busca Estilizada
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _buscaController,
                    decoration: InputDecoration(
                      hintText: 'Pesquisar nº do pedido...',
                      hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B)),
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButton<String>(
                    hint: const Text('Status', style: TextStyle(fontSize: 14)),
                    value: _filtroStatus,
                    underline: const SizedBox(),
                    items: <Map<String, String?>>[
                      {'label': 'Todos', 'value': null},
                      {'label': 'Pendente', 'value': 'PENDENTE'},
                      {'label': 'Em Separação', 'value': 'EM_SEPARACAO'},
                      {'label': 'Separado', 'value': 'SEPARADO'},
                      {'label': 'Saiu p/ Entrega', 'value': 'SAIU_PARA_ENTREGA'},
                      {'label': 'Concluído', 'value': 'CONCLUIDO'},
                      {'label': 'Cancelado', 'value': 'CANCELADO'},
                    ].map((item) {
                      return DropdownMenuItem<String>(
                        value: item['value'],
                        child: Text(item['label']!, style: const TextStyle(fontSize: 14)),
                      );
                    }).toList(),
                    onChanged: (String? novoValor) {
                      setState(() {
                        _filtroStatus = novoValor;
                        _filtrarLocalmente();
                      });
                    },
                  ),
                ),
              ],
            ),
          ),

          // Lista de Pedidos
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E3A8A)))
                : RefreshIndicator(
              onRefresh: _carregarMeusPedidos,
              color: const Color(0xFF1E3A8A),
              child: _pedidosFiltrados.isEmpty
                  ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.5,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          const Text('Nenhum pedido encontrado.', style: TextStyle(color: Colors.grey, fontSize: 16)),
                        ],
                      ),
                    ),
                  ),
                ],
              )
                  : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: _pedidosFiltrados.length,
                itemBuilder: (context, index) {
                  final pedido = _pedidosFiltrados[index];
                  final status = pedido['status']?.toString();
                  final int id = pedido['id'];
                  final double total = (pedido['total'] as num? ?? 0.0).toDouble();

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _exibirDetalhesPedido(pedido),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E3A8A).withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.shopping_bag_outlined, color: Color(0xFF1E3A8A)),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Pedido #$id',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B)),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: _corStatus(status).withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Text(
                                                formatarStatus(status),
                                                style: TextStyle(color: _corStatus(status), fontWeight: FontWeight.bold, fontSize: 11),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          formatarDataPedido(pedido['data_criacao']),
                                          style: const TextStyle(color: Colors.grey, fontSize: 13),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          _formatoMoeda.format(total),
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E3A8A)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 20, color: Color(0xFFF1F5F9)),

                              // 🌟 Botão Direto no Card de Acompanhamento
                              InkWell(
                                onTap: () => _abrirAcompanhamento(id),
                                borderRadius: BorderRadius.circular(8),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 4.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.timeline_rounded, size: 16, color: Color(0xFF1E3A8A)),
                                      SizedBox(width: 6),
                                      Text(
                                        'Acompanhar Linha do Tempo',
                                        style: TextStyle(
                                          color: Color(0xFF1E3A8A),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      SizedBox(width: 4),
                                      Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Color(0xFF1E3A8A)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
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