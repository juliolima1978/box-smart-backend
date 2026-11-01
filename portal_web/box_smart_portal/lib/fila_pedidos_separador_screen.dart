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

    try {
      await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      debugPrint('Erro ao abrir o WhatsApp: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível abrir o WhatsApp. Verifique se o aplicativo está instalado.'),
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
        await _carregarPedidos();

        if (novoStatus == 'EM_SEPARACAO' && mounted) {
          setState(() {
            _tabController.index = 1;
          });
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                novoStatus == 'EM_SEPARACAO'
                    ? 'Pedido #$pedidoId movido para Em Separação!'
                    : 'Pedido #$pedidoId atualizado para $novoStatus!',
              ),
              backgroundColor: Colors.green.shade700,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Erro ao atualizar status: $e');
    }
  }

  // ==========================================
  // 🔍 MODAL DE VISUALIZAÇÃO EXPANDIDA DO PRODUTO
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
              height: 200,
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Fila de Separação', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                  Text('Operador: ${widget.nomeSeparador}', style: const TextStyle(fontSize: 11, color: Colors.white70), overflow: TextOverflow.ellipsis),
                ],
              ),
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
          isScrollable: true,
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: TextField(
              controller: _buscaController,
              onChanged: (val) {
                setState(() => _termoBusca = val);
              },
              decoration: InputDecoration(
                hintText: 'Buscar #Pedido, Cliente ou Produto...',
                hintStyle: const TextStyle(fontSize: 12),
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF1E293B), size: 20),
                suffixIcon: _termoBusca.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  onPressed: () {
                    _buscaController.clear();
                    setState(() => _termoBusca = '');
                  },
                )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
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
  // CONSTRUTOR DA LISTA DE CARDS RESPONSIVA
  // ==========================================
  Widget _buildListaPedidos(
      List<dynamic> lista, {
        required bool podeIniciar,
        required bool podeFinalizar,
        bool ehConcluido = false,
      }) {
    if (lista.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.assignment_turned_in_outlined, size: 50, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text(
                _termoBusca.isNotEmpty
                    ? 'Nenhum pedido encontrado para "$_termoBusca".'
                    : 'Nenhum pedido nesta aba no momento.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: lista.length,
      itemBuilder: (context, index) {
        final pedido = lista[index];
        final int pedidoId = pedido['id'];
        final List<dynamic> itens = pedido['itens'] ?? [];
        final double total = (pedido['total'] as num?)?.toDouble() ?? 0.0;
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

        // Variáveis de Troco em Dinheiro
        final String formaPagamento = (pedido['forma_pagamento'] ?? '').toString();
        final double trocoPara = (pedido['troco_para'] as num?)?.toDouble() ?? 0.0;
        final bool ehDinheiro = formaPagamento.toLowerCase().contains('dinheiro');
        final double valorTrocoDevolver = trocoPara > total ? (trocoPara - total) : 0.0;
        final bool temTrocoParaDinheiro = ehDinheiro && trocoPara > 0;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
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
            tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6.0,
                    runSpacing: 4.0,
                    children: [
                      Text(
                        '#$pedidoId',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: ehConcluido ? Colors.green.shade100 : Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          pedido['status'],
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: ehConcluido ? Colors.green.shade900 : Colors.blue.shade900,
                          ),
                        ),
                      ),
                      if (itensFaltantesQtd > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '⚠️ $itensFaltantesQtd falta',
                            style: TextStyle(fontSize: 9, color: Colors.red.shade900, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  'R\$ ${total.toStringAsFixed(2).replaceAll('.', ',')}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.person_outline, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(clienteNome, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12), overflow: TextOverflow.ellipsis),
                    ),
                    InkWell(
                      onTap: () => _abrirWhatsAppCliente(pedido),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.green.shade300),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.chat, color: Colors.green, size: 12),
                            SizedBox(width: 3),
                            Text('WhatsApp', style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 13, color: Colors.grey),
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
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.badge_outlined, size: 13, color: Color(0xFF1E293B)),
                      const SizedBox(width: 4),
                      Text(
                        'Separador: $separadoPor',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                    ],
                  ),
                ],
                if (podeFinalizar) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          value: progressoChecklist,
                          color: itensFaltantesQtd > 0 ? Colors.orange : Colors.green,
                          backgroundColor: Colors.grey.shade200,
                          minHeight: 5,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${itensConcluidos + itensFaltantesQtd}/${itens.length}',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
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
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // INSTRUÇÕES DO CLIENTE
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.assignment_ind_outlined, size: 14, color: Color(0xFF1E3A8A)),
                              SizedBox(width: 5),
                              Text('Instruções e Preferências', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF1E3A8A))),
                            ],
                          ),
                          const Divider(height: 8),
                          Text(
                            '• Falta de item: ${(pedido['opcao_substituicao'] ?? 'reembolso').toString() == 'similar' ? 'Substituir por similar' : 'Reembolso'}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '• CPF na Nota: ${pedido['deseja_cpf_nota'] == true ? 'SIM' : 'NÃO'}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '• Pagamento: ${formaPagamento.toUpperCase()}',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    ),

                    // 🧮 ALERTA DE TROCO EM DINHEIRO (INSERIDO AQUI DE FORMA LIMPA)
                    if (temTrocoParaDinheiro)
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.payments_rounded, color: Color(0xFFD97706), size: 16),
                                SizedBox(width: 5),
                                Text(
                                  'Atenção: Pagamento em Dinheiro com Troco',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    color: Color(0xFF92400E),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 8, color: Color(0xFFFCD34D)),
                            Text(
                              '• O cliente vai pagar com: R\$ ${trocoPara.toStringAsFixed(2).replaceAll('.', ',')}',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF78350F)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '• Levar Troco de: R\$ ${valorTrocoDevolver.toStringAsFixed(2).replaceAll('.', ',')}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFB45309),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // LISTA DE ITENS POR CATEGORIA
                    ...itensPorCategoria.entries.map((entry) {
                      final String categoriaNome = entry.key;
                      final List<dynamic> itensCategoria = entry.value;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(top: 6, bottom: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              categoriaNome.toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                            ),
                          ),
                          ...itensCategoria.map((item) {
                            final int itemId = item['id'] ?? 0;
                            final String nomeItem = item['nome'] ?? 'Produto';
                            final bool marcado = _checklistItens[pedidoId]?[itemId] ?? false;
                            final bool emFalta = _itensFaltantes[pedidoId]?[itemId] ?? false;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              decoration: BoxDecoration(
                                color: emFalta ? Colors.red.shade50 : Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: emFalta ? Colors.red.shade300 : Colors.grey.shade200),
                              ),
                              child: ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                onTap: () => _exibirModalProdutoExpandido(item),
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    color: Colors.grey.shade100,
                                    child: item['imagem_url'] != null && item['imagem_url'].toString().startsWith('http')
                                        ? Image.network(item['imagem_url'], fit: BoxFit.cover)
                                        : const Icon(Icons.image, size: 16, color: Colors.grey),
                                  ),
                                ),
                                title: Text(
                                  nomeItem,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: emFalta ? Colors.red.shade900 : Colors.black87,
                                    decoration: (marcado && !ehConcluido) || emFalta ? TextDecoration.lineThrough : null,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  'Qtd: ${item['quantidade']} | R\$ ${((item['preco_unitario'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)}',
                                  style: const TextStyle(fontSize: 10),
                                ),
                                trailing: ehConcluido
                                    ? const Icon(Icons.check_circle, color: Colors.green, size: 18)
                                    : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (podeFinalizar)
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        icon: Icon(
                                          emFalta ? Icons.report_problem : Icons.report_problem_outlined,
                                          color: emFalta ? Colors.red : Colors.grey.shade400,
                                          size: 18,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            final novoEstadoFalta = !emFalta;
                                            _itensFaltantes[pedidoId]![itemId] = novoEstadoFalta;
                                            if (novoEstadoFalta) _checklistItens[pedidoId]![itemId] = false;
                                          });
                                          if (_itensFaltantes[pedidoId]![itemId] == true) {
                                            _abrirWhatsAppCliente(pedido, itemFaltanteNome: nomeItem);
                                          }
                                        },
                                      ),
                                    const SizedBox(width: 4),
                                    Checkbox(
                                      visualDensity: VisualDensity.compact,
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

                    const SizedBox(height: 10),

                    // BOTÕES DE AÇÃO
                    if (podeIniciar)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade800,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => _atualizarStatusPedido(pedidoId, 'EM_SEPARACAO'),
                          icon: const Icon(Icons.play_arrow_rounded, size: 18),
                          label: const Text('INICIAR SEPARAÇÃO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ),

                    if (podeFinalizar)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => _atualizarStatusPedido(pedidoId, 'SEPARADO'),
                          icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                          label: const Text('FINALIZAR SEPARAÇÃO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ),
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