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

    // Verifica o status atual do pedido que veio por parâmetro
    final statusAtual = (widget.pedido['status'] ?? '').toString().toLowerCase();
    _isJaSeparado = statusAtual == 'separado' || statusAtual == 'saiu_para_entrega' || statusAtual == 'concluido';

    // Clona os itens: se já estiver separado, todos começam marcados (true)
    _itens = List.from(widget.pedido['itens'] ?? []).map((item) {
      return {
        ...item,
        'separado': _isJaSeparado ? true : false,
      };
    }).toList();

    // 🌟 SÓ atualiza para 'em_separacao' se o pedido ainda estiver pendente/aprovado
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

  // Verifica se todos os itens da lista foram marcados como separados
  bool get _todosSeparados {
    if (_itens.isEmpty) return false;
    return _itens.every((item) => item['separado'] == true);
  }

  Future<void> _concluirSeparacao() async {
    if (!_todosSeparados) return;

    setState(() => _isLoading = true);

    // Atualiza o status para "separado" na API
    await _atualizarStatusNaApi('separado');

    setState(() => _isLoading = false);

    if (!mounted) return;

    // Retorna true para a tela anterior atualizar a lista
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final int pedidoId = widget.pedido['id'] ?? 0;

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
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _itens.length,
              itemBuilder: (context, index) {
                final item = _itens[index];
                final String nomeProduto = item['nome'] ?? item['produto_nome'] ?? 'Produto';
                final int quantidade = item['quantidade'] ?? 1;
                final bool separado = item['separado'] ?? false;

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: CheckboxListTile(
                    title: Text(
                      nomeProduto,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        // 🌟 Risca o texto se o item estiver separado
                        decoration: separado ? TextDecoration.lineThrough : TextDecoration.none,
                        color: separado ? Colors.grey : Colors.black87,
                      ),
                    ),
                    subtitle: Text('Quantidade: $quantidade un'),
                    value: separado,
                    activeColor: const Color(0xFF1E3A8A),
                    // 🌟 Se já estiver separado, desativa o clique no checkbox individual
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