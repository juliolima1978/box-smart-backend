import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:audioplayers/audioplayers.dart';

class FilaPedidosSeparadorScreen extends StatefulWidget {
  final String baseUrl;
  final String token;
  final String nomeSeparador;

  const FilaPedidosSeparadorScreen({
    super.key,
    required this.baseUrl,
    required this.token,
    required this.nomeSeparador,
  });

  @override
  State<FilaPedidosSeparadorScreen> createState() => _FilaPedidosSeparadorScreenState();
}

class _FilaPedidosSeparadorScreenState extends State<FilaPedidosSeparadorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Timer? _timerAutoRefresh;
  final AudioPlayer _audioPlayer = AudioPlayer();

  List<dynamic> _pedidosPendentes = [];
  List<dynamic> _pedidosEmSeparacao = [];
  List<dynamic> _pedidosConcluidos = [];

  bool _carregando = true;
  int _quantidadeAnteriorPendentes = 0;

  // 🔍 BARRA DE PESQUISA
  String _termoBusca = '';
  final TextEditingController _buscaController = TextEditingController();

  // Estados dos itens em memória por pedido
  final Map<int, Map<int, bool>> _checklistItens = {};
  final Map<int, Map<int, bool>> _itensFaltantes = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _carregarPedidos();

    _timerAutoRefresh = Timer.periodic(const Duration(seconds: 10), (timer) {
      _carregarPedidos(silencioso: true);
    });
  }

  @override
  void dispose() {
    _timerAutoRefresh?.cancel();
    _tabController.dispose();
    _audioPlayer.dispose();
    _buscaController.dispose();
    super.dispose();
  }

  // ==========================================
  // 🔄 CARREGAR PEDIDOS E ALERTA SONORO
  // ==========================================
  Future<void> _carregarPedidos({bool silencioso = false}) async {
    if (!silencioso) setState(() => _carregando = true);

    try {
      final response = await http.get(
        Uri.parse('${widget.baseUrl}/admin/pedidos'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> todos = json.decode(response.body);

        final pendentes = todos.where((p) => p['status'] == 'PENDENTE').toList();
        final emSeparacao = todos.where((p) => p['status'] == 'EM_SEPARACAO').toList();
        final concluidos = todos.where((p) => [
          'SEPARADO',
          'SAIU_PARA_ENTREGA',
          'ENTREGUE',
          'CONCLUIDO',
          'CANCELADO'
        ].contains(p['status'])).toList();

        if (silencioso && pendentes.length > _quantidadeAnteriorPendentes) {
          _tocarAlertaSonoro();
          _exibirSnackBarAlertaNovoPedido(pendentes.length - _quantidadeAnteriorPendentes);
        }

        _quantidadeAnteriorPendentes = pendentes.length;

        if (mounted) {
          setState(() {
            _pedidosPendentes = pendentes;
            _pedidosEmSeparacao = emSeparacao;
            _pedidosConcluidos = concluidos;
            _carregando = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Erro ao carregar pedidos para separação: $e');
      if (mounted && !silencioso) setState(() => _carregando = false);
    }
  }

  Future<void> _tocarAlertaSonoro() async {
    try {
      await _audioPlayer.play(
        UrlSource('https://assets.mixkit.co/active_storage/sfx/2869/2869-preview.mp3'),
      );
    } catch (e) {
      debugPrint('Erro ao tocar som de alerta: $e');
    }
  }

  void _exibirSnackBarAlertaNovoPedido(int novos) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.notifications_active_rounded, color: Colors.amber),
            const SizedBox(width: 10),
            Text(
              '🎉 $novos novo(s) pedido(s) aguardando separação!',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ==========================================
  // 💬 WHATSAPP CLIENTE
  // ==========================================
  Future<void> _abrirWhatsAppCliente(Map<String, dynamic> pedido, {String? itemFaltanteNome}) async {
    final cliente = pedido['cliente'] ?? {};
    final telefone = cliente['telefone'] ?? '';
    final nomeCliente = pedido['cliente_nome'] ?? 'Cliente';
    final int pedidoId = pedido['id'];

    if (telefone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Telefone do cliente não cadastrado.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final numLimpo = telefone.replaceAll(RegExp(r'\D'), '');
    final numFormatado = numLimpo.startsWith('55') ? numLimpo : '55$numLimpo';

    final String textoMensagem = itemFaltanteNome != null
        ? 'Olá, $nomeCliente! Sou ${widget.nomeSeparador}, separador do Box Smart. No momento estou separando seu Pedido #$pedidoId e notei que o item "$itemFaltanteNome" está em falta no estoque. Gostaria de substituir por outro produto ou remover do pedido?'
        : 'Olá, $nomeCliente! Sou ${widget.nomeSeparador}, separador do Box Smart. Estou separando seu Pedido #$pedidoId e gostaria de falar com você.';

    final url = Uri.parse('https://wa.me/$numFormatado?text=${Uri.encodeComponent(textoMensagem)}');

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível abrir o WhatsApp.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ==========================================
  // 🔄 ATUALIZAR STATUS DO PEDIDO
  // ==========================================
  Future<void> _atualizarStatusPedido(int pedidoId, String novoStatus) async {
    try {
      final response = await http.put(
        Uri.parse('${widget.baseUrl}/admin/pedidos/$pedidoId/status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: json.encode({
          'status': novoStatus,
          'separado_por': widget.nomeSeparador,
        }),
      );

      if (response.statusCode == 200) {
        _carregarPedidos();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Pedido #$pedidoId atualizado para $novoStatus!'),
              backgroundColor: Colors.green.shade700,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Erro ao atualizar status: $e');
    }
  }

  // ==========================================
  // 🔍 MODAL DE VISUALIZAÇÃO EXPANDIDA DO PRODUTO (COM PINÇA/ZOOM)
  // ==========================================
  void _exibirModalProdutoExpandido(Map<String, dynamic> item) {
    final String nome = item['nome'] ?? 'Produto';
    final String? imagemUrl = item['imagem_url'];
    final int quantidade = item['quantidade'] ?? 1;
    final double precoUnitario = (item['preco_unitario'] as num?)?.toDouble() ?? 0.0;
    final String categoria = item['categoria_nome'] ?? item['categoria'] ?? 'Geral';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          nome,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 220,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: imagemUrl != null && imagemUrl.startsWith('http')
                    ? InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Image.network(
                    imagemUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.image_not_supported,
                      size: 60,
                      color: Colors.grey,
                    ),
                  ),
                )
                    : const Icon(Icons.shopping_bag, size: 60, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '💡 Dica: Dê uma pinça com os dedos na imagem para aproximar.',
              style: TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Chip(
                  label: Text(categoria),
                  backgroundColor: Colors.blue.shade50,
                  labelStyle: TextStyle(color: Colors.blue.shade900, fontSize: 12),
                ),
                Text(
                  'Qtd: $quantidade',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Preço Unitário:'),
                Text(
                  'R\$ ${precoUnitario.toStringAsFixed(2).replaceAll('.', ',')}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Subtotal Item:'),
                Text(
                  'R\$ ${(precoUnitario * quantidade).toStringAsFixed(2).replaceAll('.', ',')}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                ),
              ],
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 🔍 FILTRO DE BUSCA DE PEDIDOS
  // ==========================================
  List<dynamic> _aplicarFiltroBusca(List<dynamic> lista) {
    if (_termoBusca.trim().isEmpty) return lista;

    final termo = _termoBusca.trim().toLowerCase();

    return lista.where((pedido) {
      final idStr = (pedido['id'] ?? '').toString();
      final clienteNome = (pedido['cliente_nome'] ?? '').toString().toLowerCase();
      final separadoPor = (pedido['separado_por'] ?? '').toString().toLowerCase();
      final itens = (pedido['itens'] as List<dynamic>?) ?? [];

      final contemNoItem = itens.any(
            (i) => (i['nome'] ?? '').toString().toLowerCase().contains(termo),
      );

      return idStr.contains(termo) ||
          clienteNome.contains(termo) ||
          separadoPor.contains(termo) ||
          contemNoItem;
    }).toList();
  }

  // ==========================================
  // BUILD DA TELA
  // ==========================================
  @override
  Widget build(BuildContext context) {
    final pendentesFiltrados = _aplicarFiltroBusca(_pedidosPendentes);
    final emSeparacaoFiltrados = _aplicarFiltroBusca(_pedidosEmSeparacao);
    final concluidosFiltrados = _aplicarFiltroBusca(_pedidosConcluidos);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.inventory_rounded, color: Colors.amber),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Fila de Separação', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text('Operador: ${widget.nomeSeparador}', style: const TextStyle(fontSize: 11, color: Colors.white70)),
              ],
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amber,
          labelColor: Colors.amber,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(text: 'Pendentes (${pendentesFiltrados.length})'),
            Tab(text: 'Em Separação (${emSeparacaoFiltrados.length})'),
            Tab(text: 'Concluídos (${concluidosFiltrados.length})'),
          ],
        ),
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: TextField(
              controller: _buscaController,
              onChanged: (val) {
                setState(() => _termoBusca = val);
              },
              decoration: InputDecoration(
                hintText: 'Buscar por #Pedido, Cliente, Separador ou Produto...',
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF1E293B)),
                suffixIcon: _termoBusca.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear_rounded),
                  onPressed: () {
                    _buscaController.clear();
                    setState(() => _termoBusca = '');
                  },
                )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildListaPedidos(pendentesFiltrados, podeIniciar: true, podeFinalizar: false),
                _buildListaPedidos(emSeparacaoFiltrados, podeIniciar: false, podeFinalizar: true),
                _buildListaPedidos(concluidosFiltrados, podeIniciar: false, podeFinalizar: false, ehConcluido: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // CONSTRUTOR DA LISTA DE CARDS
  // ==========================================
  Widget _buildListaPedidos(
      List<dynamic> lista, {
        required bool podeIniciar,
        required bool podeFinalizar,
        bool ehConcluido = false,
      }) {
    if (lista.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_turned_in_outlined, size: 60, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              _termoBusca.isNotEmpty
                  ? 'Nenhum pedido encontrado para "$_termoBusca".'
                  : 'Nenhum pedido nesta aba no momento.',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: lista.length,
      itemBuilder: (context, index) {
        final pedido = lista[index];
        final int pedidoId = pedido['id'];
        final List<dynamic> itens = pedido['itens'] ?? [];
        final double total = (pedido['total'] as num?)?.toDouble() ?? 0.0;
        final double subtotal = (pedido['subtotal'] as num?)?.toDouble() ?? total;
        final double taxaEntrega = (pedido['taxa_entrega'] as num?)?.toDouble() ?? 0.0;
        final String clienteNome = pedido['cliente_nome'] ?? 'Cliente';
        final String endereco = pedido['endereco_entrega'] ?? 'Endereço não informado';
        final String? separadoPor = pedido['separado_por'];

        _checklistItens.putIfAbsent(pedidoId, () => {});
        _itensFaltantes.putIfAbsent(pedidoId, () => {});

        final int itensConcluidos = _checklistItens[pedidoId]!.values.where((v) => v == true).length;
        final int itensFaltantesQtd = _itensFaltantes[pedidoId]!.values.where((v) => v == true).length;
        final double progressoChecklist = itens.isNotEmpty
            ? ((itensConcluidos + itensFaltantesQtd) / itens.length).clamp(0.0, 1.0)
            : 0.0;

        final Map<String, List<dynamic>> itensPorCategoria = {};
        for (var item in itens) {
          final String cat = item['categoria_nome'] ?? item['categoria'] ?? 'Geral / Outros';
          itensPorCategoria.putIfAbsent(cat, () => []).add(item);
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: ehConcluido
                  ? Colors.grey.shade300
                  : podeFinalizar
                  ? (itensFaltantesQtd > 0 ? Colors.orange : Colors.amber.shade400)
                  : Colors.blue.shade200,
              width: 1.5,
            ),
          ),
          child: ExpansionTile(
            key: ValueKey('pedido_$pedidoId'),
            tilePadding: const EdgeInsets.all(12),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      'Pedido #$pedidoId',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: ehConcluido ? Colors.green.shade100 : Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        pedido['status'],
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: ehConcluido ? Colors.green.shade900 : Colors.blue.shade900,
                        ),
                      ),
                    ),
                    if (itensFaltantesQtd > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '⚠️ $itensFaltantesQtd em falta',
                          style: TextStyle(fontSize: 10, color: Colors.red.shade900, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  'R\$ ${total.toStringAsFixed(2).replaceAll('.', ',')}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(clienteNome, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const Spacer(),
                    InkWell(
                      onTap: () => _abrirWhatsAppCliente(pedido),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.green.shade300),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.chat, color: Colors.green, size: 14),
                            SizedBox(width: 4),
                            Text('WhatsApp', style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        endereco,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: Colors.black87),
                      ),
                    ),
                  ],
                ),

                if (separadoPor != null && separadoPor.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.badge_outlined, size: 14, color: Color(0xFF1E293B)),
                      const SizedBox(width: 4),
                      Text(
                        'Separado por: $separadoPor',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                ],

                if (podeFinalizar) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          value: progressoChecklist,
                          color: itensFaltantesQtd > 0 ? Colors.orange : Colors.green,
                          backgroundColor: Colors.grey.shade200,
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${itensConcluidos + itensFaltantesQtd}/${itens.length}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            children: [
              const Divider(height: 1),
              Container(
                color: Colors.grey.shade50,
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 📋 CARD DE INSTRUÇÕES E PREFERÊNCIAS DO CLIENTE
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.assignment_ind_outlined, size: 16, color: Color(0xFF1E3A8A)),
                              SizedBox(width: 6),
                              Text(
                                'Preferências e Instruções do Cliente',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1E3A8A)),
                              ),
                            ],
                          ),
                          const Divider(height: 10),
                          Row(
                            children: [
                              const Text('• Falta de item: ', style: TextStyle(fontSize: 11, color: Colors.grey)),
                              Text(
                                (pedido['opcao_substituicao'] ?? 'reembolso').toString() == 'similar'
                                    ? 'Substituir por produto similar'
                                    : 'Reembolso do valor',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: (pedido['opcao_substituicao'] ?? '').toString() == 'similar'
                                      ? Colors.orange.shade800
                                      : Colors.blue.shade800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Text('• CPF na Nota: ', style: TextStyle(fontSize: 11, color: Colors.grey)),
                              Text(
                                pedido['deseja_cpf_nota'] == true ? 'SIM' : 'NÃO',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: pedido['deseja_cpf_nota'] == true ? Colors.green.shade800 : Colors.red.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Text('• Recebimento: ', style: TextStyle(fontSize: 11, color: Colors.grey)),
                              Expanded(
                                child: Text(
                                  '${(pedido['tipo_entrega'] ?? 'retirada').toString().toUpperCase()} - ${pedido['endereco_entrega'] ?? 'Retirada no Box Smart'}',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Text('• Pagamento: ', style: TextStyle(fontSize: 11, color: Colors.grey)),
                              Text(
                                '${(pedido['forma_pagamento'] ?? 'pix').toString().toUpperCase()}${((pedido['troco_para'] as num?)?.toDouble() ?? 0.0) > 0 ? " (Troco para R\$ ${((pedido['troco_para'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2).replaceAll('.', ',')})" : ""}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          if (pedido['cupom_codigo'] != null && pedido['cupom_codigo'].toString().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Text('• Cupom: ', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                Text(
                                  '${pedido['cupom_codigo']} (-R\$ ${((pedido['valor_desconto_cupom'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2).replaceAll('.', ',')})',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    // RESUMO FINANCEIRO
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Subtotal dos Produtos:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              Text('R\$ ${subtotal.toStringAsFixed(2).replaceAll('.', ',')}', style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Taxa de Entrega:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              Text(
                                taxaEntrega == 0.0 ? 'GRÁTIS' : 'R\$ ${taxaEntrega.toStringAsFixed(2).replaceAll('.', ',')}',
                                style: TextStyle(fontSize: 12, color: taxaEntrega == 0.0 ? Colors.green : Colors.black87),
                              ),
                            ],
                          ),
                          const Divider(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Valor Total:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              Text(
                                'R\$ ${total.toStringAsFixed(2).replaceAll('.', ',')}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    const Text(
                      'Itens para Separação (Agrupados por Categoria):',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 8),

                    // LISTA AGRUPADA POR CATEGORIA
                    ...itensPorCategoria.entries.map((entry) {
                      final String categoriaNome = entry.key;
                      final List<dynamic> itensCategoria = entry.value;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(top: 8, bottom: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.category_outlined, size: 14, color: Colors.amber),
                                    const SizedBox(width: 6),
                                    Text(
                                      categoriaNome.toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  '${itensCategoria.length} ${itensCategoria.length == 1 ? 'item' : 'itens'}',
                                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                                ),
                              ],
                            ),
                          ),

                          ...itensCategoria.map((item) {
                            final int itemId = item['id'] ?? 0;
                            final String nomeItem = item['nome'] ?? 'Produto';
                            final bool marcado = _checklistItens[pedidoId]?[itemId] ?? false;
                            final bool emFalta = _itensFaltantes[pedidoId]?[itemId] ?? false;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              decoration: BoxDecoration(
                                color: emFalta ? Colors.red.shade50 : Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: emFalta ? Colors.red.shade300 : Colors.grey.shade200,
                                ),
                              ),
                              child: ListTile(
                                dense: true,
                                onTap: () => _exibirModalProdutoExpandido(item),
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    color: Colors.grey.shade100,
                                    child: item['imagem_url'] != null && item['imagem_url'].toString().startsWith('http')
                                        ? Image.network(item['imagem_url'], fit: BoxFit.cover)
                                        : const Icon(Icons.image, size: 20, color: Colors.grey),
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        nomeItem,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: emFalta ? Colors.red.shade900 : Colors.black87,
                                          decoration: (marcado && !ehConcluido) || emFalta
                                              ? TextDecoration.lineThrough
                                              : null,
                                        ),
                                      ),
                                    ),
                                    if (emFalta)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade700,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'INDISPONÍVEL',
                                          style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                  ],
                                ),
                                subtitle: Text(
                                  'Qtd: ${item['quantidade']} x R\$ ${((item['preco_unitario'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)}',
                                ),
                                trailing: ehConcluido
                                    ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
                                    : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (podeFinalizar)
                                      IconButton(
                                        icon: Icon(
                                          emFalta ? Icons.report_problem : Icons.report_problem_outlined,
                                          color: emFalta ? Colors.red : Colors.grey.shade400,
                                          size: 20,
                                        ),
                                        tooltip: emFalta ? 'Item em falta' : 'Marcar como em falta',
                                        onPressed: () {
                                          setState(() {
                                            final novoEstadoFalta = !emFalta;
                                            _itensFaltantes[pedidoId]![itemId] = novoEstadoFalta;
                                            if (novoEstadoFalta) {
                                              _checklistItens[pedidoId]![itemId] = false;
                                            }
                                          });

                                          if (_itensFaltantes[pedidoId]![itemId] == true) {
                                            _abrirWhatsAppCliente(pedido, itemFaltanteNome: nomeItem);
                                          }
                                        },
                                      ),

                                    Checkbox(
                                      value: marcado,
                                      activeColor: Colors.green,
                                      onChanged: (podeFinalizar && !emFalta)
                                          ? (bool? val) {
                                        setState(() {
                                          _checklistItens[pedidoId]![itemId] = val ?? false;
                                        });
                                      }
                                          : null,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ],
                      );
                    }).toList(),

                    const SizedBox(height: 12),

                    // 📊 BARRA DE PROGRESSO AO ROLAR A TELA
                    if (podeFinalizar) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Progresso: ${itensConcluidos + itensFaltantesQtd} de ${itens.length} itens checados',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  '${(progressoChecklist * 100).toInt()}%',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: progressoChecklist == 1.0 ? Colors.green : Colors.amber.shade900,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progressoChecklist,
                                color: itensFaltantesQtd > 0 ? Colors.orange : Colors.green,
                                backgroundColor: Colors.grey.shade200,
                                minHeight: 8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // BOTÕES DE AÇÃO
                    if (podeIniciar) ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade800,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => _atualizarStatusPedido(pedidoId, 'EM_SEPARACAO'),
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('INICIAR SEPARAÇÃO', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],

                    if (podeFinalizar) ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => _atualizarStatusPedido(pedidoId, 'SEPARADO'),
                          icon: const Icon(Icons.check_circle_outline_rounded),
                          label: const Text('FINALIZAR SEPARAÇÃO (PRONTO)', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],

                    if (ehConcluido) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.lock_outline, size: 16, color: Colors.grey),
                            SizedBox(width: 6),
                            Text(
                              'Pedido finalizado / somente leitura',
                              style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}