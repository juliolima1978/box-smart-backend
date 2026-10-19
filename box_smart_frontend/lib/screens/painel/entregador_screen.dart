import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class EntregadorScreen extends StatefulWidget {
  final String baseUrl;
  final String token;

  const EntregadorScreen({
    super.key,
    required this.baseUrl,
    required this.token,
  });

  @override
  State<EntregadorScreen> createState() => _EntregadorScreenState();
}

class _EntregadorScreenState extends State<EntregadorScreen> {
  List<dynamic> _pedidos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _carregarTodosOsPedidos();
  }

  Future<void> _carregarTodosOsPedidos() async {
    setState(() => _isLoading = true);
    try {
      // Nota: Certifique-se de ter uma rota no backend que traga todos os pedidos para o painel administrativo/entregador
      final response = await http.get(
        Uri.parse('${widget.baseUrl}/pedidos/'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      if (response.statusCode == 200) {
        setState(() {
          _pedidos = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        _mostrarErro('Erro ao carregar pedidos.');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _mostrarErro('Erro de conexão: $e');
    }
  }

  Future<void> _atualizarStatus(int pedidoId, String novoStatus) async {
    try {
      final response = await http.patch(
        Uri.parse('${widget.baseUrl}/pedidos/$pedidoId/status?novo_status=$novoStatus'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      if (response.statusCode == 200) {
        // Atualiza a lista localmente ou recarrega
        _carregarTodosOsPedidos();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Pedido #$pedidoId atualizado para $novoStatus!'), backgroundColor: Colors.green),
        );
      } else {
        _mostrarErro('Falha ao atualizar status.');
      }
    } catch (e) {
      _mostrarErro('Erro ao atualizar: $e');
    }
  }

  void _mostrarErro(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red.shade900));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Painel do Entregador', style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF1E293B)),
            onPressed: _carregarTodosOsPedidos,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _carregarTodosOsPedidos,
        child: _pedidos.isEmpty
            ? const Center(child: Text('Nenhum pedido no momento.'))
            : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _pedidos.length,
          itemBuilder: (context, index) {
            final pedido = _pedidos[index];
            final statusAtual = pedido['status'] ?? 'Pendente';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Pedido #${pedido['id']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Chip(
                          label: Text(statusAtual, style: const TextStyle(color: Colors.white, fontSize: 12)),
                          backgroundColor: statusAtual == 'Concluído' ? Colors.green : Colors.orange,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Total: R\$ ${pedido['total'].toStringAsFixed(2)}', style: const TextStyle(fontSize: 14)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => _atualizarStatus(pedido['id'], 'Saiu para Entrega'),
                          child: const Text('Saiu para Entrega'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                          onPressed: () => _atualizarStatus(pedido['id'], 'Concluído'),
                          child: const Text('Concluir', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}