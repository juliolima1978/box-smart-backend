import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart'; // 🌟 Import para capturar GPS
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

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

class _EntregadorScreenState extends State<EntregadorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _pedidosParaColetar = [];
  List<dynamic> _pedidosEmRota = [];
  List<dynamic> _pedidosConcluidos = [];
  bool _isLoading = true;
  bool _mostrarPainelFinanceiro = true;

  // 🌟 Instância do Serviço de Rastreamento GPS
  final ServicoRastreamentoEntregador _servicoRastreamento =
  ServicoRastreamentoEntregador();

  final NumberFormat _formatoMoeda =
  NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _carregarPedidos();
  }

  @override
  void dispose() {
    _servicoRastreamento.pararEnvio(); // 🌟 Para a transmissão ao fechar a tela
    _tabController.dispose();
    super.dispose();
  }

  // ==========================================
  // FORMATADORES E UTILITÁRIOS
  // ==========================================

  String _formatarDataHora(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '--';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      return DateFormat("dd/MM/yyyy 'às' HH:mm").format(dt);
    } catch (_) {
      return '--';
    }
  }

  String _obterEnderecoEntregaFormatado(dynamic pedido) {
    final String? endPedido = pedido['endereco_entrega']?.toString().trim();
    if (endPedido != null &&
        endPedido.isNotEmpty &&
        endPedido != 'Endereço não informado') {
      return endPedido;
    }

    final Map<String, dynamic> cliente =
    pedido['cliente'] is Map<String, dynamic> ? pedido['cliente'] : {};
    final String? endCliente = cliente['endereco']?.toString().trim();
    if (endCliente != null && endCliente.isNotEmpty) {
      return endCliente;
    }

    return 'Endereço não informado';
  }

  // ==========================================
  // REQUISIÇÕES HTTP
  // ==========================================

  Future<void> _carregarPedidos() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final response = await http.get(
        Uri.parse('${widget.baseUrl}/admin/pedidos'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> todosPedidos = jsonDecode(response.body);

        List<dynamic> coletar = [];
        List<dynamic> emRota = [];
        List<dynamic> concluidos = [];

        for (var p in todosPedidos) {
          String status = (p['status'] ?? '').toString().toUpperCase();
          if (status == 'SAIU_PARA_ENTREGA' || status == 'EM_TRANSITO') {
            emRota.add(p);
          } else if (status == 'ENTREGUE' ||
              status == 'CONCLUIDO' ||
              status == 'CANCELADO') {
            concluidos.add(p);
          } else {
            coletar.add(p);
          }
        }

        if (mounted) {
          setState(() {
            _pedidosParaColetar = coletar;
            _pedidosEmRota = emRota;
            _pedidosConcluidos = concluidos;
            _isLoading = false;
          });

          // 🌟 Se já houver um pedido em rota ativo, inicia o rastreamento GPS automaticamente
          if (emRota.isNotEmpty) {
            _servicoRastreamento.iniciarEnvioLocalizacao(
              pedidoId: emRota.first['id'],
              token: widget.token,
              baseUrl: widget.baseUrl,
            );
          }
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
        _mostrarSnackBar('Erro ao carregar entregas (${response.statusCode}).',
            eErro: true);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      _mostrarSnackBar('Erro de conexão: $e', eErro: true);
    }
  }

  Future<void> _atualizarStatus(int pedidoId, String novoStatus,
      {String? codigoOtp}) async {
    try {
      final response = await http.put(
        Uri.parse('${widget.baseUrl}/pedidos/$pedidoId/status'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'status': novoStatus,
          if (codigoOtp != null && codigoOtp.isNotEmpty)
            'codigo_confirmacao': codigoOtp,
        }),
      );

      if (response.statusCode == 200) {
        _mostrarSnackBar('Pedido #$pedidoId atualizado com sucesso!');

        // 🌟 CONTROLE INTELIGENTE DO RASTREAMENTO POR GPS:
        if (novoStatus == 'SAIU_PARA_ENTREGA' || novoStatus == 'EM_TRANSITO') {
          // Inicia a transmissão das coordenadas de 10 em 10 segundos
          _servicoRastreamento.iniciarEnvioLocalizacao(
            pedidoId: pedidoId,
            token: widget.token,
            baseUrl: widget.baseUrl,
          );
        } else if (novoStatus == 'ENTREGUE' || novoStatus == 'CANCELADO') {
          // Desliga a transmissão do GPS ao concluir a entrega
          _servicoRastreamento.pararEnvio();
        }

        _carregarPedidos();
      } else {
        final err = jsonDecode(response.body);
        _mostrarSnackBar(
            err['detail'] ?? 'Erro ao atualizar o status do pedido.',
            eErro: true);
      }
    } catch (e) {
      _mostrarSnackBar('Erro de conexão: $e', eErro: true);
    }
  }

  // ==========================================
  // INTEGRAÇÃO COM MAPAS E WHATSAPP
  // ==========================================

  Future<void> _abrirNavegacaoRota(String endereco) async {
    final String query = Uri.encodeComponent(endereco);
    final Uri mapsUrl = Uri.parse(
        "https://www.google.com/maps/dir/?api=1&destination=$query&travelmode=driving");

    try {
      bool launched = await launchUrl(
        mapsUrl,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        _mostrarSnackBar('Não foi possível abrir o aplicativo de mapas.',
            eErro: true);
      }
    } catch (e) {
      _mostrarSnackBar('Erro ao disparar rota: $e', eErro: true);
    }
  }

  Future<void> _abrirWhatsApp(
      String telefone, String nomeCliente, int pedidoId) async {
    String numLimpo = telefone.replaceAll(RegExp(r'\D'), '');
    if (numLimpo.isEmpty) {
      _mostrarSnackBar('Número de telefone inválido.', eErro: true);
      return;
    }

    if (!numLimpo.startsWith('55') && numLimpo.length <= 11) {
      numLimpo = '55$numLimpo';
    }

    final String msg = Uri.encodeComponent(
      'Olá $nomeCliente, sou o entregador do Box Smart! Estou a caminho do seu endereço para entregar o Pedido #$pedidoId. 🛵📦',
    );

    final Uri waUrl = Uri.parse('https://wa.me/$numLimpo?text=$msg');

    try {
      bool launched =
      await launchUrl(waUrl, mode: LaunchMode.externalApplication);
      if (!launched) {
        _mostrarSnackBar('Não foi possível abrir o WhatsApp.', eErro: true);
      }
    } catch (e) {
      _mostrarSnackBar('Erro ao abrir o WhatsApp: $e', eErro: true);
    }
  }

  void _mostrarSnackBar(String mensagem, {bool eErro = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor:
        eErro ? const Color(0xFFDC2626) : const Color(0xFF059669),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ==========================================
  // MODAL DE CONFIRMAÇÃO DE ENTREGA
  // ==========================================

  void _exibirModalConfirmacaoEntrega(int pedidoId, String formaPagamento,
      double valorTotal, double trocoPara, bool estaPago) {
    final TextEditingController otpController = TextEditingController();
    bool cobrancaConferida = estaPago;
    final double trocoALevar =
    (trocoPara > valorTotal) ? (trocoPara - valorTotal) : 0.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return Padding(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Finalizar Entrega #$pedidoId',
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 10),

                  if (!estaPago) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFF59E0B)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.payments,
                                  color: Color(0xFFD97706)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Cobrar do Cliente: ${_formatoMoeda.format(valorTotal)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF92400E),
                                      fontSize: 15),
                                ),
                              ),
                            ],
                          ),
                          if (trocoPara > 0) ...[
                            const SizedBox(height: 6),
                            Text(
                              '• Forma: $formaPagamento',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFFB45309),
                                  fontWeight: FontWeight.w500),
                            ),
                            Text(
                              '• Troco recebido para: ${_formatoMoeda.format(trocoPara)}',
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFFB45309),
                                  fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '• Entregar de troco: ${_formatoMoeda.format(trocoALevar)}',
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFFB45309),
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Confirmo que recebi o valor e entreguei o troco (se houver)',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      value: cobrancaConferida,
                      onChanged: (val) =>
                          setStateModal(() => cobrancaConferida = val ?? false),
                    ),
                    const SizedBox(height: 12),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF22C55E)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle, color: Color(0xFF15803D)),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Pedido pago via Aplicativo. Não cobrar do cliente.',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF14532D),
                                  fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  const Text(
                    'Código de Confirmação / OTP (Opcional):',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF334155)),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: InputDecoration(
                      hintText: 'Ex: 4821',
                      prefixIcon: const Icon(Icons.pin),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.check_circle, color: Colors.white),
                      label: const Text(
                        'CONFIRMAR E FINALIZAR',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                      onPressed: !cobrancaConferida
                          ? null
                          : () {
                        Navigator.pop(context);
                        _atualizarStatus(
                          pedidoId,
                          'ENTREGUE',
                          codigoOtp: otpController.text.trim().isNotEmpty
                              ? otpController.text.trim()
                              : null,
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ==========================================
  // WIDGET DE GESTÃO FINANCEIRA
  // ==========================================

  Widget _buildCardGestaoFinanceira() {
    double totalDinheiro = 0.0;
    double totalCartao = 0.0;
    double totalApp = 0.0;
    int qtdConcluidas = 0;

    for (var p in _pedidosConcluidos) {
      String status = (p['status'] ?? '').toString().toUpperCase();
      if (status == 'ENTREGUE' || status == 'CONCLUIDO') {
        qtdConcluidas++;
        double valor = double.tryParse(p['total']?.toString() ?? '0') ?? 0.0;

        String formaRaw =
        (p['forma_pagamento'] ?? p['metodo_pagamento'] ?? '').toString();
        String forma = formaRaw
            .toUpperCase()
            .replaceAll('ÃO', 'AO')
            .replaceAll('Ã', 'A')
            .replaceAll('É', 'E')
            .replaceAll('Ê', 'E')
            .replaceAll('Á', 'A');

        bool estaPago = p['esta_pago'] == true ||
            (forma.contains('PIX') && !forma.contains('ENTREGA')) ||
            forma.contains('PAGO') ||
            forma.contains('ONLINE');

        if (estaPago) {
          totalApp += valor;
        } else if (forma.contains('CARTAO') ||
            forma.contains('CREDITO') ||
            forma.contains('DEBITO') ||
            forma.contains('MAQUININHA')) {
          totalCartao += valor;
        } else if (forma.contains('DINHEIRO')) {
          totalDinheiro += valor;
        } else {
          totalApp += valor;
        }
      }
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _mostrarPainelFinanceiro = !_mostrarPainelFinanceiro;
              });
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.account_balance_wallet,
                          color: Color(0xFF38BDF8), size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Prestação de Contas do Dia',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$qtdConcluidas entregas',
                          style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        _mostrarPainelFinanceiro
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: Colors.white70,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_mostrarPainelFinanceiro) ...[
            const Divider(color: Color(0xFF334155), height: 1),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: _buildItemFinanceiro(
                      rotulo: 'A prestar em Dinheiro',
                      valor: _formatoMoeda.format(totalDinheiro),
                      cor: const Color(0xFF22C55E),
                      icone: Icons.attach_money,
                      destaque: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildItemFinanceiro(
                      rotulo: 'Cartão (Maquininha)',
                      valor: _formatoMoeda.format(totalCartao),
                      cor: const Color(0xFF38BDF8),
                      icone: Icons.credit_card,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildItemFinanceiro(
                      rotulo: 'Pago no App',
                      valor: _formatoMoeda.format(totalApp),
                      cor: const Color(0xFFA855F7),
                      icone: Icons.mobile_friendly,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildItemFinanceiro({
    required String rotulo,
    required String valor,
    required Color cor,
    required IconData icone,
    bool destaque = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: destaque ? cor.withOpacity(0.15) : const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: destaque ? cor : const Color(0xFF334155),
          width: destaque ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icone, size: 14, color: cor),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  rotulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade400,
                      fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              valor,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: destaque ? cor : Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // CONSTRUÇÃO DA TELA (BUILD)
  // ==========================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text(
          'Central do Entregador',
          style: TextStyle(
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.bold,
              fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF0F172A)),
            onPressed: _carregarPedidos,
            tooltip: 'Atualizar',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF1E3A8A),
          unselectedLabelColor: Colors.grey.shade600,
          indicatorColor: const Color(0xFF1E3A8A),
          indicatorWeight: 3.5,
          labelStyle:
          const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: [
            Tab(
                child: _buildBadgeTab(
                    'Coletar', _pedidosParaColetar.length, Colors.blue)),
            Tab(
                child: _buildBadgeTab(
                    'Em Rota', _pedidosEmRota.length, Colors.orange)),
            Tab(
                child: _buildBadgeTab(
                    'Concluídas', _pedidosConcluidos.length, Colors.green)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          _buildCardGestaoFinanceira(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildListaAba(_pedidosParaColetar, statusAba: 'COLETAR'),
                _buildListaAba(_pedidosEmRota, statusAba: 'ROTA'),
                _buildListaAba(_pedidosConcluidos,
                    statusAba: 'CONCLUIDAS'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeTab(String label, int quantidade, Color cor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(label),
        if (quantidade > 0) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
                color: cor, borderRadius: BorderRadius.circular(10)),
            child: Text('$quantidade',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ],
    );
  }

  Widget _buildListaAba(List<dynamic> lista, {required String statusAba}) {
    if (lista.isEmpty) {
      return RefreshIndicator(
        onRefresh: _carregarPedidos,
        child: ListView(
          children: [
            const SizedBox(height: 100),
            Center(
              child: Column(
                children: [
                  Icon(
                    statusAba == 'CONCLUIDAS'
                        ? Icons.task_alt
                        : Icons.two_wheeler,
                    size: 56,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    statusAba == 'COLETAR'
                        ? 'Nenhum pedido aguardando coleta.'
                        : statusAba == 'ROTA'
                        ? 'Nenhuma entrega em andamento.'
                        : 'Nenhum histórico recente.',
                    style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _carregarPedidos,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: lista.length,
        itemBuilder: (context, index) {
          return _buildCardPedidoOtimizado(lista[index], statusAba: statusAba);
        },
      ),
    );
  }

  // ==========================================
  // CARD DE PEDIDO INDIVIDUAL
  // ==========================================

  Widget _buildCardPedidoOtimizado(dynamic pedido,
      {required String statusAba}) {
    final int id = pedido['id'];
    final double total =
        double.tryParse(pedido['total']?.toString() ?? '0') ?? 0.0;

    final String endereco = _obterEnderecoEntregaFormatado(pedido);

    final Map<String, dynamic> cliente =
    pedido['cliente'] is Map<String, dynamic> ? pedido['cliente'] : {};
    final String nomeCliente =
        cliente['nome'] ?? pedido['cliente_nome'] ?? 'Cliente';
    final String telefone = cliente['telefone'] ?? 'Sem telefone';
    final List itens = pedido['itens'] ?? [];

    final String formaPagamento = pedido['forma_pagamento'] ??
        pedido['metodo_pagamento'] ??
        'Dinheiro na Entrega';

    String formaNorm = formaPagamento
        .toUpperCase()
        .replaceAll('ÃO', 'AO')
        .replaceAll('Ã', 'A')
        .replaceAll('Á', 'A');

    final bool estaPago = pedido['esta_pago'] == true ||
        (formaNorm.contains('PIX') && !formaNorm.contains('ENTREGA'));

    final double trocoPara =
        double.tryParse(pedido['troco_para']?.toString() ?? '0') ?? 0.0;
    final double valorTrocoALevar =
    (trocoPara > total) ? (trocoPara - total) : 0.0;

    final String separadorNome = pedido['separado_por'] ?? 'Não informado';
    final String entregadorNome =
        pedido['entregador_nome'] ?? 'Entregador Box Smart';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(
            backgroundColor: statusAba == 'CONCLUIDAS'
                ? Colors.green.shade100
                : statusAba == 'ROTA'
                ? Colors.orange.shade100
                : Colors.blue.shade100,
            child: Icon(
              statusAba == 'CONCLUIDAS'
                  ? Icons.check
                  : statusAba == 'ROTA'
                  ? Icons.navigation
                  : Icons.inventory_2,
              color: statusAba == 'CONCLUIDAS'
                  ? Colors.green.shade800
                  : statusAba == 'ROTA'
                  ? Colors.orange.shade800
                  : Colors.blue.shade800,
            ),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Pedido #$id',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: Color(0xFF0F172A)),
              ),
              Text(
                _formatoMoeda.format(total),
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF1E3A8A)),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.location_on,
                        size: 14, color: Colors.redAccent),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        endereco,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade800,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: estaPago
                        ? const Color(0xFFDCFCE7)
                        : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    estaPago
                        ? '✓ PAGO NO APP'
                        : (trocoPara > 0
                        ? '⚠️ COBRAR NA ENTREGA (TROCO P/ ${_formatoMoeda.format(trocoPara)})'
                        : '⚠️ COBRAR NA ENTREGA'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: estaPago
                          ? const Color(0xFF166534)
                          : const Color(0xFF92400E),
                    ),
                  ),
                ),
              ],
            ),
          ),
          children: [
            const Divider(height: 1, indent: 16, endIndent: 16),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: estaPago
                          ? Colors.green.shade50
                          : Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: estaPago
                              ? Colors.green.shade200
                              : Colors.amber.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(
                            estaPago
                                ? Icons.verified
                                : Icons.account_balance_wallet,
                            color: estaPago
                                ? Colors.green.shade700
                                : Colors.amber.shade900),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                estaPago
                                    ? 'Pagamento Confirmado'
                                    : 'Cobrança Pendente na Entrega',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: estaPago
                                      ? Colors.green.shade900
                                      : Colors.amber.shade900,
                                ),
                              ),
                              Text(
                                estaPago
                                    ? 'Cliente pagou via aplicativo ($formaPagamento).'
                                    : (trocoPara > 0
                                    ? 'Receber ${_formatoMoeda.format(total)} | Levar ${_formatoMoeda.format(valorTrocoALevar)} de troco (Troco p/ ${_formatoMoeda.format(trocoPara)})'
                                    : 'Receber ${_formatoMoeda.format(total)} via $formaPagamento.'),
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey.shade800),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  Row(
                    children: [
                      const Icon(Icons.person, size: 18, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          nomeCliente,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Color(0xFF1E293B)),
                        ),
                      ),
                      if (telefone != 'Sem telefone') ...[
                        IconButton(
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.all(8),
                            minimumSize: Size.zero,
                          ),
                          icon: const Icon(Icons.chat, size: 18),
                          tooltip: 'Conversar no WhatsApp',
                          onPressed: () =>
                              _abrirWhatsApp(telefone, nomeCliente, id),
                        ),
                        const SizedBox(width: 6),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: const Icon(Icons.phone, size: 14),
                          label: const Text('Ligar',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold)),
                          onPressed: () =>
                              launchUrl(Uri.parse("tel:$telefone")),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 12),

                  Text('Endereço de Entrega:',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade600)),
                  const SizedBox(height: 4),
                  Text(endereco,
                      style: const TextStyle(
                          fontSize: 14, color: Color(0xFF334155), height: 1.3)),
                  const SizedBox(height: 10),

                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.map_outlined, size: 20),
                      label: const Text('TRAÇAR ROTA NO GOOGLE MAPS',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                      onPressed: () => _abrirNavegacaoRota(endereco),
                    ),
                  ),

                  const SizedBox(height: 16),

                  _buildTimelineWidget(pedido),

                  const SizedBox(height: 16),

                  Text('Itens do Pedido (${itens.length}):',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade600)),
                  const SizedBox(height: 4),
                  ...itens.map((item) {
                    final String nomeProd =
                        item['nome'] ?? item['nome_produto'] ?? 'Produto';
                    final int qtd = item['quantidade'] ?? 1;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                      child: Text('• $qtd x $nomeProd',
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF334155))),
                    );
                  }),

                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.inventory_2_outlined,
                                size: 15, color: Color(0xFF0284C7)),
                            const SizedBox(width: 6),
                            Text(
                              'Separado no Estoque por: ',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade700),
                            ),
                            Text(
                              separadorNome,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                        if (statusAba == 'CONCLUIDAS' ||
                            statusAba == 'ROTA') ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.two_wheeler,
                                  size: 15, color: Color(0xFF059669)),
                              const SizedBox(width: 6),
                              Text(
                                'Entregue por: ',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey.shade700),
                              ),
                              Text(
                                entregadorNome,
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF059669)),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  if (statusAba == 'COLETAR')
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E3A8A),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        icon:
                        const Icon(Icons.two_wheeler, color: Colors.white),
                        label: const Text('INICIAR ROTA DE ENTREGA',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15)),
                        onPressed: () =>
                            _atualizarStatus(id, 'SAIU_PARA_ENTREGA'),
                      ),
                    ),

                  if (statusAba == 'ROTA')
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.check_circle_outline,
                            color: Colors.white),
                        label: const Text('CONCLUIR ENTREGA',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15)),
                        onPressed: () => _exibirModalConfirmacaoEntrega(
                            id, formaPagamento, total, trocoPara, estaPago),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // WIDGET DE TIMELINE
  // ==========================================

  Widget _buildTimelineWidget(dynamic pedido) {
    final String dCriacao = _formatarDataHora(pedido['data_criacao']);
    final String dSeparado = _formatarDataHora(pedido['data_separado']);
    final String dSaiu = _formatarDataHora(pedido['data_saiu_entrega']);
    final String dConcluido = _formatarDataHora(pedido['data_concluido']);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Timeline do Pedido:',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Color(0xFF334155)),
          ),
          const SizedBox(height: 8),
          _buildTimelineStep('Pedido Recebido', dCriacao, dCriacao != '--',
              ePrimeiro: true),
          _buildTimelineStep(
              'Separado no Estoque', dSeparado, dSeparado != '--'),
          _buildTimelineStep('Saiu para Entrega', dSaiu, dSaiu != '--'),
          _buildTimelineStep(
              'Entrega Concluída', dConcluido, dConcluido != '--',
              eUltimo: true),
        ],
      ),
    );
  }

  Widget _buildTimelineStep(String titulo, String dataHora, bool concluido,
      {bool ePrimeiro = false, bool eUltimo = false}) {
    final Color corBase =
    concluido ? Colors.green.shade700 : Colors.grey.shade400;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: corBase,
                shape: BoxShape.circle,
              ),
            ),
            if (!eUltimo)
              Container(
                width: 2,
                height: 20,
                color: concluido ? Colors.green.shade300 : Colors.grey.shade300,
              ),
          ],
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                titulo,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: concluido ? FontWeight.bold : FontWeight.normal,
                  color: concluido
                      ? const Color(0xFF0F172A)
                      : Colors.grey.shade600,
                ),
              ),
              Text(
                dataHora,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: concluido ? FontWeight.w600 : FontWeight.normal,
                  color:
                  concluido ? Colors.grey.shade800 : Colors.grey.shade400,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ==========================================
// 🌟 PASSO 4: SERVIÇO DE RASTREAMENTO GPS
// ==========================================
class ServicoRastreamentoEntregador {
  Timer? _timer;

  void iniciarEnvioLocalizacao({
    required int pedidoId,
    required String token,
    required String baseUrl,
  }) {
    pararEnvio(); // Evita múltiplos timers rodando em paralelo

    _timer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      try {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) return;
        }

        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        final url = Uri.parse('$baseUrl/admin/pedidos/$pedidoId/localizacao');
        await http.patch(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'latitude': position.latitude,
            'longitude': position.longitude,
          }),
        );
      } catch (e) {
        debugPrint('Erro ao enviar coordenadas do GPS: $e');
      }
    });
  }

  void pararEnvio() {
    _timer?.cancel();
    _timer = null;
  }
}