import 'package:box_smart_frontend/screens/painel/separacao_checklist_screen.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class FilaPedidosSeparadorScreen extends StatefulWidget {
  final String baseUrl;
  final String token;

  const FilaPedidosSeparadorScreen({
    super.key,
    required this.baseUrl,
    required this.token,
  });

  @override
  State<FilaPedidosSeparadorScreen> createState() => _FilaPedidosSeparadorScreenState();
}

class _FilaPedidosSeparadorScreenState extends State<FilaPedidosSeparadorScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<dynamic> _pedidosPendentes = [];
  List<dynamic> _pedidosSeparados = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _carregarFilaPedidos();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _carregarFilaPedidos() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('${widget.baseUrl}/admin/pedidos/'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> todosPedidos = jsonDecode(response.body);

        for (var p in todosPedidos) {
          print('Pedido ID: ${p['id']} - Status no Banco: "${p['status']}"');
        }

        setState(() {
          // Filtra os pendentes/aprovados para a primeira aba
          _pedidosPendentes = todosPedidos.where((pedido) {
            final status = (pedido['status'] ?? '').toString().toLowerCase();
            return status == 'pendente' || status == 'aprovado' || status == 'em_separacao';
          }).toList();

          // Filtra os separados ou em rota de entrega para a segunda aba
          _pedidosSeparados = todosPedidos.where((pedido) {
            final status = (pedido['status'] ?? '').toString().toLowerCase();
            return status == 'separado' || status == 'saiu_para_entrega';
          }).toList();

          _isLoading = false;
        });
      } else {
        _mostrarErro('Erro ao carregar os pedidos: ${response.statusCode}');
      }
    } catch (e) {
      _mostrarErro('Erro de conexão com o servidor: $e');
    }
  }

  Future<void> _atualizarStatusPedidoApi(int pedidoId, String novoStatus) async {
    try {
      final response = await http.patch(
        Uri.parse('${widget.baseUrl}/admin/pedidos/$pedidoId/status/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: jsonEncode({'status': novoStatus}),
      );

      if (response.statusCode == 200) {
        _carregarFilaPedidos();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Status do pedido atualizado com sucesso!'), backgroundColor: Colors.green),
        );
      } else {
        _mostrarErro('Erro ao atualizar status: ${response.statusCode}');
      }
    } catch (e) {
      _mostrarErro('Erro de conexão ao atualizar status: $e');
    }
  }

  void _mostrarErro(String mensagem) {
    if (!mounted) return;
    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem), backgroundColor: Colors.red.shade900),
    );
  }

  // 🌟 Método que constrói os botões dinâmicos de acordo com o status atual do pedido
  Widget _buildBotoesAcaoOperador(Map<String, dynamic> pedido) {
    final status = (pedido['status'] ?? '').toString().toLowerCase();

    if (status == 'separado') {
      return ElevatedButton.icon(
        onPressed: () => _atualizarStatusPedidoApi(pedido['id'], 'saiu_para_entrega'),
        icon: const Icon(Icons.local_shipping_outlined, size: 16),
        label: const Text('Despachar Pedido'),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade700, foregroundColor: Colors.white),
      );
    } else if (status == 'saiu_para_entrega') {
      return ElevatedButton.icon(
        onPressed: () => _atualizarStatusPedidoApi(pedido['id'], 'concluido'),
        icon: const Icon(Icons.done_all_rounded, size: 16),
        label: const Text('Marcar como Concluído'),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
      );
    }

    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text(
          'Painel do Separador',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF001e64),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _carregarFilaPedidos,
            tooltip: 'Atualizar Filas',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.orangeAccent,
          indicatorWeight: 3,
          tabs: [
            Tab(
              icon: const Icon(Icons.pending_actions),
              text: 'Pendentes (${_pedidosPendentes.length})',
            ),
            Tab(
              icon: const Icon(Icons.task_alt),
              text: 'Separados / Fila (${_pedidosSeparados.length})',
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
        controller: _tabController,
        children: [
          // Aba 1: Pendentes
          _pedidosPendentes.isEmpty
              ? _buildListaVazia('Nenhum pedido na fila!', 'Todos os pedidos já foram separados.')
              : _buildListaPedidos(_pedidosPendentes, isPendente: true),

          // Aba 2: Separados
          _pedidosSeparados.isEmpty
              ? _buildListaVazia('Nenhum pedido separado ainda.', 'Os pedidos concluídos aparecerão aqui.')
              : _buildListaPedidos(_pedidosSeparados, isPendente: false),
        ],
      ),
    );
  }

  Widget _buildListaVazia(String titulo, String subtitulo) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            titulo,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 8),
          Text(
            subtitulo,
            style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildListaPedidos(List<dynamic> listaPedidos, {required bool isPendente}) {
    return RefreshIndicator(
      onRefresh: _carregarFilaPedidos,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: listaPedidos.length,
        itemBuilder: (context, index) {
          final pedido = listaPedidos[index];
          String nomeCliente = 'Cliente Avulso';

          if (pedido['cliente'] is Map) {
            nomeCliente = pedido['cliente']['nome'] ?? pedido['cliente']['razao_social'] ?? 'Cliente Avulso';
          } else if (pedido['nome_cliente'] != null) {
            nomeCliente = pedido['nome_cliente'];
          } else if (pedido['cliente_nome'] != null) {
            nomeCliente = pedido['cliente_nome'];
          } else if (pedido['usuario'] is Map) {
            nomeCliente = pedido['usuario']['nome'] ?? 'Cliente Avulso';
          }

          final int id = pedido['id'] ?? 0;
          final String data = pedido['data_criacao'] ?? 'Data não informada';
          final List<dynamic> itens = pedido['itens'] ?? [];
          final int qtdItens = itens.length;
          final String statusAtual = (pedido['status'] ?? '').toString().toLowerCase();

          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Pedido #$id',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isPendente ? Colors.orange.shade100 : Colors.green.shade100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isPendente ? Icons.timer_outlined : Icons.check_circle_outline,
                              size: 14,
                              color: isPendente ? Colors.orange.shade800 : Colors.green.shade800,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              statusAtual == 'saiu_para_entrega' ? 'A Caminho' : (isPendente ? 'Aguardando' : 'Separado'),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isPendente ? Colors.orange.shade800 : Colors.green.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      const Icon(Icons.person_outline, size: 20, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        nomeCliente,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 20, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        data.split('T').first,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total de itens:', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          Text(
                            '$qtdItens itens',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
                      // Ações baseadas na aba
                      if (isPendente)
                        ElevatedButton.icon(
                          onPressed: () async {
                            final atualizou = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SeparacaoChecklistScreen(
                                  pedido: pedido,
                                  baseUrl: widget.baseUrl,
                                  token: widget.token,
                                ),
                              ),
                            );

                            if (atualizou == true) {
                              _carregarFilaPedidos();
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('🎉 Pedido separado com sucesso! Movido para a aba Separados.'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.inventory_2_outlined, size: 16),
                          label: const Text('Separar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E3A8A),
                            foregroundColor: Colors.white,
                          ),
                        )
                      else
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end, // ou alinhado à direita
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: TextButton.icon(
                                  onPressed: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => SeparacaoChecklistScreen(
                                          pedido: pedido,
                                          baseUrl: widget.baseUrl,
                                          token: widget.token,
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.visibility_outlined, size: 16, color: Colors.grey),
                                  label: const Text('Itens', style: TextStyle(color: Colors.grey)),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: _buildBotoesAcaoOperador(pedido),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}