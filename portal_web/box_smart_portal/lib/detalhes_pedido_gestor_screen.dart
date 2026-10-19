import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

class DetalhesPedidoGestorScreen extends StatefulWidget {
  final Map<String, dynamic> pedido;
  final String baseUrl;
  final String token;

  const DetalhesPedidoGestorScreen({
    super.key,
    required this.pedido,
    required this.baseUrl,
    required this.token,
  });

  @override
  State<DetalhesPedidoGestorScreen> createState() => _DetalhesPedidoGestorScreenState();
}

class _DetalhesPedidoGestorScreenState extends State<DetalhesPedidoGestorScreen> {
  late Map<String, dynamic> _pedidoAtual;
  bool _isLoading = false;

  final NumberFormat _formatoMoeda = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$',
  );

  @override
  void initState() {
    super.initState();
    _pedidoAtual = widget.pedido;
    _atualizarDetalhes();
  }

  Future<void> _atualizarDetalhes() async {
    final int id = _pedidoAtual['id'] ?? 0;
    if (id == 0) return;

    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('${widget.baseUrl}/admin/pedidos/$id'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      if (response.statusCode == 200) {
        final dadosServidor = jsonDecode(response.body);
        if (dadosServidor is Map<String, dynamic>) {
          setState(() {
            _pedidoAtual = dadosServidor;
            _isLoading = false;
          });
          return;
        }
      }
    } catch (e) {
      // Mantém os dados locais caso a chamada falhe
    }
    if (mounted) setState(() => _isLoading = false);
  }

  String _formatarStatus(String? status) {
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

  @override
  Widget build(BuildContext context) {
    final int id = _pedidoAtual['id'] ?? 0;
    final String rawStatus = (_pedidoAtual['status'] ?? 'PENDENTE').toString();
    final String statusFormatado = _formatarStatus(rawStatus);
    final String dataCriacao = _pedidoAtual['data_criacao'] ?? _pedidoAtual['criado_em'] ?? 'Data não informada';
    final List<dynamic> itens = _pedidoAtual['itens'] ?? [];

    // 🌟 1. Dados do Cliente
    String nomeCliente = 'Cliente Não Informado';
    String emailCliente = 'Não informado';
    String telefoneCliente = 'Não informado';

    final clienteData = _pedidoAtual['cliente'];
    if (clienteData is Map) {
      nomeCliente = clienteData['nome'] ?? clienteData['razao_social'] ?? 'Cliente Avulso';
      emailCliente = clienteData['email'] ?? 'Não informado';
      telefoneCliente = clienteData['telefone'] ?? clienteData['celular'] ?? 'Não informado';
    } else {
      nomeCliente = _pedidoAtual['cliente_nome'] ?? _pedidoAtual['nome_cliente'] ?? 'Cliente ID: ${_pedidoAtual['cliente_id'] ?? 'N/A'}';
      emailCliente = _pedidoAtual['cliente_email'] ?? 'Não informado';
      telefoneCliente = _pedidoAtual['cliente_telefone'] ?? 'Não informado';
    }

    // 🌟 2. Mapeamento de Rastreabilidade Operacional
    String separadorNome = 'Ainda não separado';
    if (_pedidoAtual['separado_por'] != null && _pedidoAtual['separado_por'].toString().trim().isNotEmpty) {
      separadorNome = _pedidoAtual['separado_por'].toString();
    } else if (_pedidoAtual['separador'] is Map) {
      separadorNome = _pedidoAtual['separador']['nome'] ?? 'Separador atribuído';
    } else if (_pedidoAtual['separador_nome'] != null) {
      separadorNome = _pedidoAtual['separador_nome'].toString();
    } else if (_pedidoAtual['nome_separador'] != null) {
      separadorNome = _pedidoAtual['nome_separador'].toString();
    }
    if (separadorNome == 'null' || separadorNome.trim().isEmpty) separadorNome = 'Ainda não separado';

    String entregadorNome = 'Não atribuído';
    if (_pedidoAtual['entregador'] is Map) {
      entregadorNome = _pedidoAtual['entregador']['nome'] ?? 'Entregador atribuído';
    } else if (_pedidoAtual['entregador_nome'] != null) {
      entregadorNome = _pedidoAtual['entregador_nome'].toString();
    } else if (_pedidoAtual['nome_entregador'] != null) {
      entregadorNome = _pedidoAtual['nome_entregador'].toString();
    } else if (_pedidoAtual['entregador'] != null && _pedidoAtual['entregador'].toString() != 'null') {
      entregadorNome = _pedidoAtual['entregador'].toString();
    } else if (_pedidoAtual['entregador_id'] != null) {
      entregadorNome = 'Entregador #${_pedidoAtual['entregador_id']}';
    }
    if (entregadorNome == 'null' || entregadorNome.trim().isEmpty) entregadorNome = 'Não atribuído';

    // 🌟 3. Cálculo dinâmico do valor total
    double totalPedido = double.tryParse(_pedidoAtual['total']?.toString() ?? '0') ?? 0.0;
    if (totalPedido == 0.0 && itens.isNotEmpty) {
      for (var item in itens) {
        double qtd = double.tryParse(item['quantidade']?.toString() ?? '1') ?? 1.0;
        double preco = double.tryParse(item['preco_unitario']?.toString() ?? item['preco']?.toString() ?? '0') ?? 0.0;
        totalPedido += (qtd * preco);
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text('Detalhes do Pedido #$id', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E3A8A),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _atualizarDetalhes,
            tooltip: 'Atualizar Dados',
          ),
        ],
      ),
      body: _isLoading && _pedidoAtual['itens'] == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cabeçalho com Status e ID
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Pedido #$id',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _obterCorStatus(rawStatus),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        statusFormatado,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Grid de Informações
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Coluna 1: Dados do Cliente e Pedido
                    Expanded(
                      flex: 2,
                      child: Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('👤 Informações do Cliente', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
                              const Divider(height: 20),
                              Text('Nome: $nomeCliente', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                              const SizedBox(height: 8),
                              Text('E-mail: $emailCliente', style: const TextStyle(fontSize: 14, color: Colors.grey)),
                              const SizedBox(height: 8),
                              Text('Telefone: $telefoneCliente', style: const TextStyle(fontSize: 14, color: Colors.grey)),
                              const SizedBox(height: 16),
                              const Text('📅 Data do Pedido:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                              Text(dataCriacao.contains('T') ? dataCriacao.split('T').first : dataCriacao, style: const TextStyle(fontSize: 14)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Coluna 2: Rastreabilidade de Equipe
                    Expanded(
                      flex: 2,
                      child: Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('🛡️ Rastreabilidade Operacional', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
                              const Divider(height: 20),
                              Row(
                                children: [
                                  const Icon(Icons.inventory_2_outlined, size: 20, color: Colors.blueAccent),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Separado por:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                        Text(separadorNome, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  const Icon(Icons.local_shipping_outlined, size: 20, color: Colors.orangeAccent),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Entregador responsável:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                        Text(entregadorNome, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Tabela de Itens do Pedido e Total Geral
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('🛒 Itens do Pedido', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
                        const Divider(height: 20),
                        itens.isEmpty
                            ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(child: Text('Nenhum item encontrado neste pedido.', style: TextStyle(color: Colors.grey))),
                        )
                            : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: itens.length,
                          separatorBuilder: (context, index) => const Divider(),
                          itemBuilder: (context, index) {
                            final item = itens[index];
                            final nomeProduto = item['produto_nome'] ?? item['nome'] ?? item['descricao'] ?? 'Produto';
                            final int quantidade = int.tryParse(item['quantidade']?.toString() ?? '1') ?? 1;
                            final double precoUnitario = double.tryParse(item['preco_unitario']?.toString() ?? item['preco']?.toString() ?? '0') ?? 0.0;
                            final double subtotal = quantidade * precoUnitario;

                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(nomeProduto, style: const TextStyle(fontWeight: FontWeight.w500)),
                              subtitle: Text('Qtd: $quantidade x ${_formatoMoeda.format(precoUnitario)}'),
                              trailing: Text(
                                _formatoMoeda.format(subtotal),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E3A8A)),
                              ),
                            );
                          },
                        ),
                        const Divider(height: 30),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Valor Total do Pedido:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            Text(
                              _formatoMoeda.format(totalPedido),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                            ),
                          ],
                        ),
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
  }

  Color _obterCorStatus(String status) {
    switch (status.toUpperCase().replaceAll(' ', '_')) {
      case 'PENDENTE':
        return Colors.orange;
      case 'APROVADO':
      case 'EM_SEPARACAO':
        return Colors.blue;
      case 'SEPARADO':
        return Colors.purple;
      case 'SAIU_PARA_ENTREGA':
      case 'EM_ROTA':
      case 'ENTREGA':
        return Colors.indigo;
      case 'CONCLUIDO':
      case 'ENTREGUE':
        return Colors.green;
      case 'CANCELADO':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}