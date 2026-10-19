import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AdminPedidosScreen extends StatefulWidget {
  final String baseUrl;
  final String token;

  const AdminPedidosScreen({
    super.key,
    required this.baseUrl,
    required this.token,
  });

  @override
  State<AdminPedidosScreen> createState() => _AdminPedidosScreenState();
}

class _AdminPedidosScreenState extends State<AdminPedidosScreen> {
  bool _isLoading = true;
  List<dynamic> _pedidos = [];
  String _filtroStatus = 'Todos';

  // 👈 Controladores para a busca por ID do pedido
  final TextEditingController _buscaController = TextEditingController();
  String _termoBusca = '';

  @override
  void initState() {
    super.initState();
    _carregarPedidos();
  }

  Future<void> _carregarPedidos() async {
    setState(() => _isLoading = true);
    try {
      String url = '${widget.baseUrl}/admin/pedidos';
      if (_filtroStatus != 'Todos') {
        url += '?status=$_filtroStatus';
      }

      final response = await http.get(
        Uri.parse(url),
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
      final response = await http.patch(
        Uri.parse('${widget.baseUrl}/admin/pedidos/$pedidoId/status'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'status': novoStatus}),
      );

      if (response.statusCode == 200) {
        _carregarPedidos();
      } else {
        _mostrarErro('Não foi possível atualizar o status.');
      }
    } catch (e) {
      _mostrarErro('Erro de conexão: $e');
    }
  }

  void _mostrarErro(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red.shade900),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 👈 Filtra a lista de pedidos localmente pelo ID digitado
    final pedidosFiltrados = _pedidos.where((p) {
      if (_termoBusca.isEmpty) return true;
      String idStr = p['id'].toString();
      return idStr.contains(_termoBusca);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text(
          'Gerenciamento de Pedidos',
          style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: _carregarPedidos,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- BARRA DE FILTROS E BUSCA POR ID ---
            Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['Todos', 'Pendente', 'Concluído', 'Cancelado'].map((status) {
                        bool ativo = _filtroStatus == status;
                        return Padding(
                          padding: const EdgeInsets.only(right: 12.0),
                          child: ChoiceChip(
                            label: Text(status),
                            selected: ativo,
                            selectedColor: const Color(0xFF1E3A8A),
                            labelStyle: TextStyle(
                              color: ativo ? Colors.white : const Color(0xFF334155),
                              fontWeight: FontWeight.bold,
                            ),
                            onSelected: (bool selected) {
                              setState(() {
                                _filtroStatus = status;
                              });
                              _carregarPedidos();
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // 👈 Campo de busca por ID do pedido
                SizedBox(
                  width: 250,
                  child: TextField(
                    controller: _buscaController,
                    decoration: InputDecoration(
                      hintText: 'Buscar pedido por ID...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    onChanged: (valor) {
                      setState(() {
                        _termoBusca = valor.trim();
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // --- TABELA DE PEDIDOS ---
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
                  ],
                ),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : pedidosFiltrados.isEmpty
                    ? const Center(child: Text('Nenhum pedido encontrado.', style: TextStyle(color: Colors.grey)))
                    : ListView.separated(
                  itemCount: pedidosFiltrados.length,
                  separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  itemBuilder: (context, index) {
                    final p = pedidosFiltrados[index];
                    String status = p['status'] ?? 'Pendente';
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      title: Row(
                        children: [
                          Text('Pedido #${p['id']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                          const SizedBox(width: 12),
                          if (p['eh_membro_clube'] == true)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(4)),
                              child: const Text('Membro Clube', style: TextStyle(color: Colors.indigo, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                      subtitle: Text('Cliente: ${p['cliente_nome']} • R\$ ${(p['total'] ?? 0.0).toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF64748B))),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: _corStatusBg(status),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(status, style: TextStyle(color: _corStatusTexto(status), fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                          const SizedBox(width: 12),
                          PopupMenuButton<String>(
                            onSelected: (novoStatus) => _atualizarStatus(p['id'], novoStatus),
                            itemBuilder: (context) => [
                              const PopupMenuItem(value: 'Pendente', child: Text('Marcar como Pendente')),
                              const PopupMenuItem(value: 'Concluído', child: Text('Marcar como Concluído')),
                              const PopupMenuItem(value: 'Cancelado', child: Text('Marcar como Cancelado')),
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
      ),
    );
  }

  Color _corStatusBg(String status) {
    switch (status) {
      case 'Concluído': return Colors.green.shade50;
      case 'Cancelado': return Colors.red.shade50;
      default: return Colors.orange.shade50;
    }
  }

  Color _corStatusTexto(String status) {
    switch (status) {
      case 'Concluído': return Colors.green.shade700;
      case 'Cancelado': return Colors.red.shade700;
      default: return Colors.orange.shade700;
    }
  }
}