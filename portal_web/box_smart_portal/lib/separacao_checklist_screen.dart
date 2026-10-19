import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SeparacaoChecklistScreen extends StatefulWidget {
  final Map<String, dynamic> pedido;
  final String baseUrl;
  final String token;
  final String nomeSeparador;

  const SeparacaoChecklistScreen({
    super.key,
    required this.pedido,
    required this.baseUrl,
    required this.token,
    this.nomeSeparador = 'Operador',
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


    // 🌟 Print de depuração no console do Flutter
    if (widget.pedido['itens'] != null && widget.pedido['itens'].isNotEmpty) {
      print('📦 JSON DO PRIMEIRA ITEM DO PEDIDO: ${widget.pedido['itens'][0]}');
    }

    final statusAtual = (widget.pedido['status'] ?? '').toString().toLowerCase();
    _isJaSeparado = statusAtual == 'separado' || statusAtual == 'saiu_para_entrega' || statusAtual == 'concluido';

    _itens = List.from(widget.pedido['itens'] ?? []).map((item) {
      final Map<String, dynamic> itemMap = item is Map ? Map<String, dynamic>.from(item) : {};
      return {
        ...itemMap,
        'separado': _isJaSeparado ? true : false,
      };
    }).toList();

    if (!_isJaSeparado) {
      _atualizarStatusNaApi('em_separacao');
    }
  }

  // 🌟 Extrai o nome da Categoria/Setor tratando todos os formatos JSON do backend
  String _extrairNomeCategoria(dynamic itemInput) {
    if (itemInput is! Map) return 'Outros / Geral';

    // 1. Tenta pegar diretamente do item
    if (itemInput['categoria'] is String && (itemInput['categoria'] as String).trim().isNotEmpty) {
      return itemInput['categoria'];
    }
    if (itemInput['categoria'] is Map && itemInput['categoria']['nome'] != null) {
      return itemInput['categoria']['nome'].toString();
    }
    if (itemInput['categoria_nome'] != null) {
      return itemInput['categoria_nome'].toString();
    }
    if (itemInput['nome_categoria'] != null) {
      return itemInput['nome_categoria'].toString();
    }

    // 2. Tenta pegar de dentro de item['produto']
    final prod = itemInput['produto'];
    if (prod is Map) {
      if (prod['categoria'] is String && (prod['categoria'] as String).trim().isNotEmpty) {
        return prod['categoria'];
      }
      if (prod['categoria'] is Map && prod['categoria']['nome'] != null) {
        return prod['categoria']['nome'].toString();
      }
      if (prod['categoria_nome'] != null) {
        return prod['categoria_nome'].toString();
      }
      if (prod['nome_categoria'] != null) {
        return prod['nome_categoria'].toString();
      }
    }

    return 'Outros / Geral';
  }

  // 🌟 Agrupa os itens por Categoria/Setor
  Map<String, List<dynamic>> get _itensAgrupadosPorCategoria {
    final Map<String, List<dynamic>> grupos = {};

    for (var item in _itens) {
      final String categoria = _extrairNomeCategoria(item);

      if (!grupos.containsKey(categoria)) {
        grupos[categoria] = [];
      }
      grupos[categoria]!.add(item);
    }

    return grupos;
  }

  Future<void> _atualizarStatusNaApi(String novoStatus, {String? operador}) async {
    final int pedidoId = widget.pedido['id'];
    try {
      final Map<String, dynamic> body = {'status': novoStatus};
      if (operador != null) {
        body['separado_por'] = operador;
      }

      await http.patch(
        Uri.parse('${widget.baseUrl}/admin/pedidos/$pedidoId/status'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
    } catch (e) {
      debugPrint('Erro ao atualizar status na API: $e');
    }
  }

  void _abrirModalDetalhesProduto(dynamic itemInput) {
    final Map item = itemInput is Map ? itemInput : {};
    final String nomeProduto = item['nome'] ?? item['nome_produto'] ?? item['produto_nome'] ?? 'Produto';
    final int quantidade = item['quantidade'] ?? 1;
    final String? imagemUrl = item['imagem_url'] ?? item['imagem'] ?? (item['produto'] is Map ? item['produto']['imagem_url'] : null);

    final Map prodMap = item['produto'] is Map ? item['produto'] : {};
    final String marca = item['marca'] ?? prodMap['marca'] ?? 'Não informada';
    final String peso = item['peso'] ?? item['conteudo'] ?? prodMap['peso'] ?? prodMap['unidade_medida'] ?? 'Não informado';
    final String codigoBarras = item['codigo_barras'] ?? prodMap['codigo_barras'] ?? 'N/A';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  children: [
                    Container(
                      height: 260,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      ),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        child: (imagemUrl != null && imagemUrl.isNotEmpty)
                            ? InteractiveViewer(
                          minScale: 0.8,
                          maxScale: 4.0,
                          child: Image.network(
                            imagemUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.shopping_bag, size: 80, color: Colors.grey),
                            ),
                          ),
                        )
                            : Container(
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.shopping_bag, size: 80, color: Colors.grey),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: CircleAvatar(
                        backgroundColor: Colors.black54,
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white, size: 20),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 8,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.zoom_in, color: Colors.white, size: 14),
                            SizedBox(width: 4),
                            Text(
                              'Pince para dar zoom',
                              style: TextStyle(color: Colors.white, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nomeProduto,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 8),

                      _buildLinhaDetalhe('Quantidade:', '$quantidade un', destaque: true),
                      _buildLinhaDetalhe('Marca:', marca),
                      _buildLinhaDetalhe('Peso / Embalagem:', peso),
                      _buildLinhaDetalhe('Cód. Barras:', codigoBarras),

                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 45,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E3A8A),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text('OK, ENTENDIDO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLinhaDetalhe(String rotulo, String valor, {bool destaque = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(rotulo, style: TextStyle(color: Colors.grey.shade700, fontSize: 14)),
          Text(
            valor,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: destaque ? 16 : 14,
              color: destaque ? const Color(0xFF1E3A8A) : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagemProduto(dynamic itemInput) {
    final Map item = itemInput is Map ? itemInput : {};
    final String? url = item['imagem_url'] ?? item['imagem'] ?? (item['produto'] is Map ? item['produto']['imagem_url'] : null);

    return GestureDetector(
      onTap: () => _abrirModalDetalhesProduto(item),
      child: Tooltip(
        message: 'Toque para ampliar',
        child: Stack(
          alignment: Alignment.bottomRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: (url != null && url.isNotEmpty)
                  ? Image.network(
                url,
                width: 52,
                height: 52,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.shopping_bag, color: Colors.grey, size: 24),
                ),
              )
                  : Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.shopping_bag, color: Colors.grey, size: 24),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Color(0xFF1E3A8A),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.search, size: 12, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCategoria(String nomeCategoria, List<dynamic> itensDoGrupo) {
    final int checados = itensDoGrupo.where((i) => i['separado'] == true).length;
    final int total = itensDoGrupo.length;
    final bool todosConcluidos = total > 0 && checados == total;

    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8, left: 4, right: 4),
      child: Row(
        children: [
          Icon(
            Icons.storefront_outlined,
            size: 18,
            color: todosConcluidos ? Colors.green.shade700 : const Color(0xFF1E3A8A),
          ),
          const SizedBox(width: 8),
          Text(
            nomeCategoria.toUpperCase(),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: todosConcluidos ? Colors.green.shade800 : const Color(0xFF1E3A8A),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: todosConcluidos ? Colors.green.shade100 : Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$checados / $total',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: todosConcluidos ? Colors.green.shade800 : const Color(0xFF1E3A8A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  int get _totalItens => _itens.length;
  int get _itensChecados => _itens.where((item) => item['separado'] == true).length;
  bool get _todosSeparados => _itens.isNotEmpty && _itensChecados == _totalItens;
  double get _progresso => _totalItens == 0 ? 0.0 : _itensChecados / _totalItens;

  Future<void> _concluirSeparacao() async {
    if (!_todosSeparados) return;

    setState(() => _isLoading = true);

    await _atualizarStatusNaApi('separado', operador: widget.nomeSeparador);

    setState(() => _isLoading = false);

    if (!mounted) return;

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final int pedidoId = widget.pedido['id'] ?? 0;
    final bool concluido100 = _todosSeparados;
    final int porcentagem = (_progresso * 100).round();

    final grupos = _itensAgrupadosPorCategoria;
    final categoriasKeys = grupos.keys.toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text('Separando Pedido #$pedidoId',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E3A8A),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // CARD SUPERIOR DE PROGRESSO GERAL
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          concluido100 ? Icons.check_circle : Icons.fact_check_outlined,
                          color: concluido100 ? Colors.green.shade600 : const Color(0xFF1E3A8A),
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Progresso da Separação',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: concluido100 ? Colors.green.shade100 : Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$_itensChecados de $_totalItens ($porcentagem%)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: concluido100 ? Colors.green.shade800 : const Color(0xFF1E3A8A),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _progresso,
                    minHeight: 10,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      concluido100 ? Colors.green.shade600 : const Color(0xFF1E3A8A),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // LISTA AGRUPADA POR CATEGORIA / SETOR
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: categoriasKeys.length,
              itemBuilder: (context, catIndex) {
                final String categoria = categoriasKeys[catIndex];
                final List<dynamic> itensDaCategoria = grupos[categoria]!;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeaderCategoria(categoria, itensDaCategoria),
                    ...itensDaCategoria.map((item) {
                      final String nomeProduto =
                          item['nome'] ?? item['nome_produto'] ?? item['produto_nome'] ?? 'Produto';
                      final int quantidade = item['quantidade'] ?? 1;
                      final bool separado = item['separado'] ?? false;

                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: separado ? Colors.green.shade50.withOpacity(0.5) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: separado ? Colors.green.shade300 : Colors.grey.shade300,
                            width: separado ? 1.5 : 1.0,
                          ),
                        ),
                        child: CheckboxListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          secondary: _buildImagemProduto(item),
                          controlAffinity: ListTileControlAffinity.trailing,
                          title: Text(
                            nomeProduto,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              decoration: separado ? TextDecoration.lineThrough : TextDecoration.none,
                              color: separado ? Colors.grey.shade700 : Colors.black87,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Quantidade: $quantidade un',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: separado ? Colors.green.shade800 : Colors.grey.shade800,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          value: separado,
                          activeColor: Colors.green.shade600,
                          onChanged: _isJaSeparado
                              ? null
                              : (bool? valor) {
                            setState(() {
                              item['separado'] = valor ?? false;
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ],
                );
              },
            ),
          ),

          // BOTÃO INFERIOR DE FINALIZAÇÃO
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 6,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: _isJaSeparado
                    ? ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade700,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                  label: const Text('VOLTAR',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                )
                    : ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                    _todosSeparados ? Colors.green.shade700 : Colors.grey.shade300,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: _todosSeparados ? 2 : 0,
                  ),
                  icon: Icon(
                    _todosSeparados ? Icons.check_circle_outline : Icons.lock_outline,
                    color: _todosSeparados ? Colors.white : Colors.grey.shade600,
                  ),
                  onPressed: _todosSeparados ? _concluirSeparacao : null,
                  label: Text(
                    _todosSeparados
                        ? 'FINALIZAR E MARCAR COMO SEPARADO'
                        : 'CONFIRA TODOS OS ITENS ($_itensChecados/$_totalItens)',
                    style: TextStyle(
                      color: _todosSeparados ? Colors.white : Colors.grey.shade600,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
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