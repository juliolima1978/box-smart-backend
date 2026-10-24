import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SeparacaoChecklistScreen extends StatefulWidget {
  final Map<String, dynamic> pedido;
  final String baseUrl;
  final String token;

  const SeparacaoChecklistScreen({
    super.key,
    required this.pedido,
    required this.baseUrl,
    required this.token,
  });

  @override
  State<SeparacaoChecklistScreen> createState() => _SeparacaoChecklistScreenState();
}

class _SeparacaoChecklistScreenState extends State<SeparacaoChecklistScreen> {
  late List<dynamic> _itens;
  bool _isLoading = false;
  late bool _isJaSeparado;

  @override
  void initState() {
    super.initState();

    final statusAtual = (widget.pedido['status'] ?? '').toString().toLowerCase();
    _isJaSeparado = statusAtual == 'separado' || statusAtual == 'saiu_para_entrega' || statusAtual == 'concluido';

    _itens = List.from(widget.pedido['itens'] ?? []).map((item) {
      return {
        ...item,
        'separado': _isJaSeparado ? true : false,
      };
    }).toList();

    if (!_isJaSeparado) {
      _atualizarStatusNaApi('em_separacao');
    }
  }

  Future<void> _atualizarStatusNaApi(String novoStatus) async {
    final int pedidoId = widget.pedido['id'];
    try {
      await http.patch(
        Uri.parse('${widget.baseUrl}/admin/pedidos/$pedidoId/status/'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'status': novoStatus}),
      );
    } catch (e) {
      print('Erro ao atualizar status na API: $e');
    }
  }

  bool get _todosSeparados {
    if (_itens.isEmpty) return false;
    return _itens.every((item) => item['separado'] == true);
  }

  Future<void> _concluirSeparacao() async {
    if (!_todosSeparados) return;

    setState(() => _isLoading = true);
    await _atualizarStatusNaApi('separado');
    setState(() => _isLoading = false);

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final int pedidoId = widget.pedido['id'] ?? 0;
    final cliente = widget.pedido['cliente'] ?? {};

    // 🌟 Novas informações do pedido
    final String opcaoSubstituicao = (widget.pedido['opcao_substituicao'] ?? 'reembolso').toString();
    final bool desejaCpfNota = widget.pedido['deseja_cpf_nota'] == true;
    final String tipoEntrega = (widget.pedido['tipo_entrega'] ?? 'retirada').toString();
    final String enderecoEntrega = widget.pedido['endereco_entrega'] ?? 'Retirada no Box Smart';
    final String formaPagamento = (widget.pedido['forma_pagamento'] ?? 'pix').toString();
    final double trocoPara = (widget.pedido['troco_para'] ?? 0.0).toDouble();
    final String? cupomCodigo = widget.pedido['cupom_codigo'];
    final double descontoCupom = (widget.pedido['valor_desconto_cupom'] ?? 0.0).toDouble();

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text('Checklist do Pedido #$pedidoId', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E3A8A),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // 🌟 CARD DE INSTRUÇÕES DO CLIENTE (Visível para o Separador/Gestor)
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Cliente: ${cliente['nome'] ?? 'Cliente'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text('Tel: ${cliente['telefone'] ?? 'Não inf.'}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                const Divider(height: 16),

                // 1. Política de Indisponibilidade
                Row(
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: Colors.blue),
                    const SizedBox(width: 8),
                    const Text('Falta de item: ', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    Text(
                      opcaoSubstituicao == 'similar' ? 'Substituir por similar' : 'Reembolso do valor',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: opcaoSubstituicao == 'similar' ? Colors.orange.shade800 : Colors.blue.shade800),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // 2. CPF na Nota
                Row(
                  children: [
                    const Icon(Icons.badge_outlined, size: 16, color: Colors.green),
                    const SizedBox(width: 8),
                    const Text('CPF na Nota: ', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    Text(
                      desejaCpfNota ? 'SIM (${cliente['cpf'] ?? 'Cadastrado'})' : 'NÃO',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: desejaCpfNota ? Colors.green.shade800 : Colors.red.shade700),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // 3. Entrega & Pagamento
                Row(
                  children: [
                    Icon(tipoEntrega == 'delivery' ? Icons.delivery_dining : Icons.storefront, size: 16, color: Colors.purple),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Entrega: ${tipoEntrega.toUpperCase()} - $enderecoEntrega',
                        style: const TextStyle(fontSize: 11, color: Colors.black87),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.payment, size: 16, color: Colors.teal),
                    const SizedBox(width: 8),
                    Text(
                      'Pagamento: ${formaPagamento.toUpperCase()}${trocoPara > 0 ? " (Troco para R\$ ${trocoPara.toStringAsFixed(2).replaceAll('.', ',')})" : ""}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87),
                    ),
                  ],
                ),
                if (cupomCodigo != null && cupomCodigo.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.local_offer, size: 16, color: Colors.green),
                      const SizedBox(width: 8),
                      Text('Cupom Aplicado: $cupomCodigo (-R\$ ${descontoCupom.toStringAsFixed(2).replaceAll('.', ',')})', style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Itens para Separar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
            ),
          ),
          const SizedBox(height: 4),

          // Lista de Itens do Pedido
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _itens.length,
              itemBuilder: (context, index) {
                final item = _itens[index];
                final String nomeProduto = item['nome'] ?? item['produto_nome'] ?? 'Produto';
                final dynamic quantidade = item['quantidade'] ?? 1;
                final bool separado = item['separado'] ?? false;

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: CheckboxListTile(
                    title: Text(
                      nomeProduto,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        decoration: separado ? TextDecoration.lineThrough : TextDecoration.none,
                        color: separado ? Colors.grey : Colors.black87,
                      ),
                    ),
                    subtitle: Text('Quantidade: $quantidade un', style: const TextStyle(fontSize: 11)),
                    value: separado,
                    activeColor: const Color(0xFF1E3A8A),
                    onChanged: _isJaSeparado
                        ? null
                        : (bool? valor) {
                      setState(() {
                        _itens[index]['separado'] = valor ?? false;
                      });
                    },
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: _isJaSeparado
                  ? ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade700,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('Voltar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              )
                  : ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _todosSeparados ? const Color(0xFF1E3A8A) : Colors.grey.shade300,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                onPressed: _todosSeparados ? _concluirSeparacao : null,
                child: Text(
                  _todosSeparados ? 'Finalizar e Marcar como Separado' : 'Marque todos os itens para finalizar',
                  style: TextStyle(
                    color: _todosSeparados ? Colors.white : Colors.grey.shade600,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}