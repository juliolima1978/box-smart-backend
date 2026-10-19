import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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

  @override
  void initState() {
    super.initState();
    _carregarPedidos();
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
          _pedidos = jsonDecode(response.body);
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Status atualizado com sucesso!'), backgroundColor: Colors.green),
        );
        _carregarPedidos();
      } else {
        _mostrarErro('Erro ao atualizar status.');
      }
    } catch (e) {
      _mostrarErro('Erro de conexão: $e');
    }
  }

  void _exibirDetalhesGestor(Map<String, dynamic> pedido) {
    showDialog(
      context: context,
      builder: (context) {
        final List itens = pedido['itens'] ?? [];
        String statusAtual = pedido['status'] ?? 'Pendente';

        return StatefulBuilder(
          builder: (context, setStateModal) {
            return AlertDialog(
              title: Text('Detalhes do Pedido #${pedido['id']}', style: const TextStyle(fontWeight: FontWeight.bold)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Cliente ID: ${pedido['cliente_id']}', style: const TextStyle(color: Colors.grey)),
                      Text('Data: ${pedido['data_criacao'] ?? 'Recente'}', style: const TextStyle(color: Colors.grey)),
                      const Divider(height: 24),
                      const Text('Alterar Status do Pedido:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: ['Pendente', 'Em Separação', 'Saiu para Entrega', 'Concluído'].contains(statusAtual) ? statusAtual : 'Pendente',
                        decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                        items: const [
                          DropdownMenuItem(value: 'Pendente', child: Text('Pendente')),
                          DropdownMenuItem(value: 'Em Separação', child: Text('Em Separação')),
                          DropdownMenuItem(value: 'Saiu para Entrega', child: Text('Saiu para Entrega')),
                          DropdownMenuItem(value: 'Concluído', child: Text('Concluído')),
                        ],
                        onChanged: (novoValor) async {
                          if (novoValor != null) {
                            setStateModal(() => statusAtual = novoValor);
                            await _atualizarStatus(pedido['id'], novoValor);
                          }
                        },
                      ),
                      const Divider(height: 24),
                      const Text('Itens Comprados:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 180,
                        child: ListView.builder(
                          itemCount: itens.length,
                          itemBuilder: (context, index) {
                            final item = itens[index];
                            return ListTile(
                              dense: true,
                              title: Text(item['nome_produto'] ?? 'Produto', style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text('Qtd: ${item['quantidade']} un • R\$ ${item['preco_unitario'].toStringAsFixed(2)} cada'),
                              trailing: Text(
                                'R\$ ${(item['preco_unitario'] * item['quantidade']).toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            );
                          },
                        ),
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total do Pedido:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          Text('R\$ ${pedido['total'].toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A)),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Fechar', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _mostrarErro(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensagem), backgroundColor: Colors.red.shade900));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Controle e Gestão de Pedidos', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _carregarPedidos,
                tooltip: 'Atualizar Lista',
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _pedidos.isEmpty
                ? const Center(child: Text('Nenhum pedido realizado até o momento.', style: TextStyle(color: Colors.grey, fontSize: 16)))
                : Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: ListView.separated(
                itemCount: _pedidos.length,
                separatorBuilder: (context, index) => Divider(color: Colors.grey.shade200, height: 1),
                itemBuilder: (context, index) {
                  final pedido = _pedidos[index];
                  final status = pedido['status'] ?? 'Pendente';
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.receipt_long, color: Color(0xFF1E3A8A)),
                    ),
                    title: Text('Pedido #${pedido['id']} — R\$ ${pedido['total'].toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    subtitle: Text('Cliente ID: ${pedido['cliente_id']} | Status atual: $status'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Chip(
                          label: Text(status, style: const TextStyle(color: Colors.white, fontSize: 11)),
                          backgroundColor: status == 'Concluído' ? Colors.green : Colors.orange.shade700,
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E3A8A),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          onPressed: () => _exibirDetalhesGestor(pedido),
                          icon: const Icon(Icons.visibility, size: 16, color: Colors.white),
                          label: const Text('Detalhes', style: TextStyle(color: Colors.white, fontSize: 12)),
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
}