import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:intl/intl.dart';

class AcompanharPedidoScreen extends StatefulWidget {
  final String baseUrl;
  final String token;
  final int pedidoId;

  const AcompanharPedidoScreen({
    super.key,
    required this.baseUrl,
    required this.token,
    required this.pedidoId,
  });

  @override
  State<AcompanharPedidoScreen> createState() => _AcompanharPedidoScreenState();
}

class _AcompanharPedidoScreenState extends State<AcompanharPedidoScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _pedido;

  final NumberFormat _formatoMoeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  final DateFormat _formatoDataHora = DateFormat("dd/MM/yyyy 'às' HH:mm");

  @override
  void initState() {
    super.initState();
    _buscarDetalhesPedido();
  }

  Future<void> _buscarDetalhesPedido() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('${widget.baseUrl}/pedidos/${widget.pedidoId}'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _pedido = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        _exibirErro('Não foi possível carregar os detalhes do pedido.');
      }
    } catch (e) {
      _exibirErro('Erro de conexão com o servidor: $e');
    }
  }

  void _exibirErro(String msg) {
    if (!mounted) return;
    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: const Color(0xFFB91C1C)),
    );
  }

  String _formatarData(String? dataIso) {
    if (dataIso == null || dataIso.isEmpty) return 'Aguardando...';
    try {
      final dateTime = DateTime.parse(dataIso).toLocal();
      return _formatoDataHora.format(dateTime);
    } catch (_) {
      return dataIso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final double total = double.tryParse(_pedido?['total']?.toString() ?? '0') ?? 0.0;
    final String statusAtual = (_pedido?['status'] ?? 'PENDENTE').toString().toUpperCase();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0.5,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Acompanhar Pedido',
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w800,
                fontSize: 18,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              'Pedido #${widget.pedidoId} • ${_formatoMoeda.format(total)}',
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            child: _buildBadgeStatus(statusAtual),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E3A8A)))
          : RefreshIndicator(
        onRefresh: _buscarDetalhesPedido,
        color: const Color(0xFF1E3A8A),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCardTimeline(statusAtual),
              const SizedBox(height: 20),
              _buildCardDetalhesEntrega(),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // BADGE DE STATUS SUPERIOR
  // ==========================================
  Widget _buildBadgeStatus(String status) {
    Color corFundo;
    Color corTexto;

    switch (status) {
      case 'CONCLUIDO':
      case 'ENTREGUE':
        corFundo = const Color(0xFFECFDF5);
        corTexto = const Color(0xFF059669);
        break;
      case 'CANCELADO':
        corFundo = const Color(0xFFFEF2F2);
        corTexto = const Color(0xFFDC2626);
        break;
      case 'SAIU_PARA_ENTREGA':
        corFundo = const Color(0xFFE0F2FE);
        corTexto = const Color(0xFF0284C7);
        break;
      case 'EM_SEPARACAO':
      case 'SEPARADO':
        corFundo = const Color(0xFFF5F3FF);
        corTexto = const Color(0xFF7C3AED);
        break;
      default:
        corFundo = const Color(0xFFFEF3C7);
        corTexto = const Color(0xFFD97706);
    }

    return Chip(
      label: Text(
        status.replaceAll('_', ' '),
        style: TextStyle(
          color: corTexto,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
      backgroundColor: corFundo,
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
    );
  }

  // ==========================================
  // CARD DE LINHA DO TEMPO (TIMELINE)
  // ==========================================
  Widget _buildCardTimeline(String statusAtual) {
    final List<_EtapaTimeline> etapas = [
      _EtapaTimeline(
        titulo: 'Pedido Realizado',
        subtitulo: 'Aguardando confirmação da loja',
        timestamp: _pedido?['data_criacao'],
        icone: Icons.receipt_long_rounded,
        chaveStatus: 'PENDENTE',
      ),
      _EtapaTimeline(
        titulo: 'Em Separação',
        subtitulo: _pedido?['separado_por'] != null
            ? 'Separador: ${_pedido!['separado_por']}'
            : 'Sua compra está sendo separada',
        timestamp: _pedido?['data_inicio_separacao'],
        icone: Icons.shopping_bag_rounded,
        chaveStatus: 'EM_SEPARACAO',
      ),
      _EtapaTimeline(
        titulo: 'Separação Concluída',
        subtitulo: 'Produtos prontos para envio',
        timestamp: _pedido?['data_separado'],
        icone: Icons.inventory_2_rounded,
        chaveStatus: 'SEPARADO',
      ),
      _EtapaTimeline(
        titulo: 'Saiu para Entrega',
        subtitulo: 'Entregador em deslocamento',
        timestamp: _pedido?['data_saiu_entrega'],
        icone: Icons.local_shipping_rounded,
        chaveStatus: 'SAIU_PARA_ENTREGA',
      ),
      _EtapaTimeline(
        titulo: 'Pedido Entregue',
        subtitulo: 'Entregue com sucesso ao cliente',
        timestamp: _pedido?['data_concluido'],
        icone: Icons.check_circle_rounded,
        chaveStatus: 'ENTREGUE',
      ),
    ];

    int indiceAtual = _definirIndiceProgresso(statusAtual);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Linha do Tempo',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 20),
          if (statusAtual == 'CANCELADO')
            _buildAlertaCancelamento()
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: etapas.length,
              itemBuilder: (context, index) {
                final etapa = etapas[index];
                final bool isConcluido = index <= indiceAtual;
                final bool isUltimo = index == etapas.length - 1;

                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Coluna com Ícone e Conector
                      Column(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isConcluido
                                  ? const Color(0xFF1E3A8A)
                                  : const Color(0xFFF1F5F9),
                              border: Border.all(
                                color: isConcluido
                                    ? const Color(0xFF1E3A8A)
                                    : const Color(0xFFCBD5E1),
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              etapa.icone,
                              size: 18,
                              color: isConcluido ? Colors.white : const Color(0xFF94A3B8),
                            ),
                          ),
                          if (!isUltimo)
                            Expanded(
                              child: Container(
                                width: 2,
                                color: index < indiceAtual
                                    ? const Color(0xFF1E3A8A)
                                    : const Color(0xFFE2E8F0),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 16),

                      // Informações do Passo
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                etapa.titulo,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: isConcluido
                                      ? const Color(0xFF0F172A)
                                      : const Color(0xFF94A3B8),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                etapa.subtitulo,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(
                                    Icons.access_time_rounded,
                                    size: 13,
                                    color: isConcluido
                                        ? const Color(0xFF059669)
                                        : const Color(0xFF94A3B8),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _formatarData(etapa.timestamp),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: isConcluido
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                      color: isConcluido
                                          ? const Color(0xFF059669)
                                          : const Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildAlertaCancelamento() {
    final String motivo = _pedido?['motivo_cancelamento'] ?? 'Cancelado pela administração';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cancel_rounded, color: Color(0xFFDC2626), size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pedido Cancelado',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF991B1B),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Motivo: $motivo',
                  style: const TextStyle(
                    color: Color(0xFFB91C1C),
                    fontSize: 12,
                  ),
                ),
                if (_pedido?['data_cancelado'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      'Data: ${_formatarData(_pedido!['data_cancelado'])}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF7F1D1D),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // CARD DE DETALHES DE ENTREGA E CLIENTE
  // ==========================================
  Widget _buildCardDetalhesEntrega() {
    final String endereco = _pedido?['endereco_entrega'] ?? 'Não informado';
    final String formaPagamento = _pedido?['forma_pagamento'] ?? 'Não informada';
    final String clienteNome = _pedido?['cliente_nome'] ?? 'Cliente';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Detalhes da Entrega',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 14),
          _buildItemDetalhe(
            icone: Icons.person_outline_rounded,
            titulo: 'Cliente',
            valor: clienteNome,
          ),
          const Divider(height: 20, color: Color(0xFFF1F5F9)),
          _buildItemDetalhe(
            icone: Icons.location_on_outlined,
            titulo: 'Endereço',
            valor: endereco,
          ),
          const Divider(height: 20, color: Color(0xFFF1F5F9)),
          _buildItemDetalhe(
            icone: Icons.payment_rounded,
            titulo: 'Pagamento',
            valor: formaPagamento,
          ),
        ],
      ),
    );
  }

  Widget _buildItemDetalhe({
    required IconData icone,
    required String titulo,
    required String valor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icone, size: 20, color: const Color(0xFF64748B)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                valor,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  int _definirIndiceProgresso(String status) {
    switch (status) {
      case 'PENDENTE':
        return 0;
      case 'EM_SEPARACAO':
        return 1;
      case 'SEPARADO':
        return 2;
      case 'SAIU_PARA_ENTREGA':
      case 'EM_TRANSITO':
        return 3;
      case 'ENTREGUE':
      case 'CONCLUIDO':
        return 4;
      default:
        return 0;
    }
  }
}

class _EtapaTimeline {
  final String titulo;
  final String subtitulo;
  final String? timestamp;
  final IconData icone;
  final String chaveStatus;

  _EtapaTimeline({
    required this.titulo,
    required this.subtitulo,
    this.timestamp,
    required this.icone,
    required this.chaveStatus,
  });
}