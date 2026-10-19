import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../main.dart';

class NotificacoesScreen extends StatefulWidget {
  final int clienteId;
  final String token;
  final String baseUrl;
  final Map<int, int> carrinho;
  final Set<int> favoritosIds;
  final List<dynamic> produtosListaGlobal;

  const NotificacoesScreen({
    super.key,
    required this.clienteId,
    required this.token,
    required this.baseUrl,
    this.carrinho = const {},
    this.favoritosIds = const {},
    this.produtosListaGlobal = const [],
  });

  @override
  State<NotificacoesScreen> createState() => _NotificacoesScreenState();
}

class _NotificacoesScreenState extends State<NotificacoesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<dynamic> _alertas = [];
  List<dynamic> _ofertas = [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _buscarNotificacoesDaApi();
  }

  // Helper para formatar a data ISO em formato amigável
  String _formatarData(String? dataRaw) {
    if (dataRaw == null || dataRaw.isEmpty) return '';
    try {
      final dt = DateTime.parse(dataRaw);
      final dia = dt.day.toString().padLeft(2, '0');
      final mes = dt.month.toString().padLeft(2, '0');
      final hora = dt.hour.toString().padLeft(2, '0');
      final minuto = dt.minute.toString().padLeft(2, '0');
      return '$dia/$mes às $hora:$minuto';
    } catch (_) {
      return dataRaw;
    }
  }

  Future<void> _buscarNotificacoesDaApi() async {
    try {
      final response = await http.get(
        Uri.parse('${widget.baseUrl}/clientes/${widget.clienteId}/notificacoes'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        if (mounted) {
          setState(() {
            _alertas = data.where((item) => item['tipo'] != 'oferta').toList();
            _ofertas = data.where((item) => item['tipo'] == 'oferta').toList();
            _carregando = false;
          });
        }
      } else {
        if (mounted) setState(() => _carregando = false);
      }
    } catch (e) {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Column(
          children: [
            // Topo Limpo: Botão Voltar, Breadcrumb e Título
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () {
                          if (Navigator.of(context).canPop()) {
                            Navigator.of(context).pop();
                          } else {
                            Navigator.of(context).popUntil((route) => route.isFirst);
                          }
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 4.0, horizontal: 2.0),
                          child: Row(
                            children: [
                              Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: Colors.black87),
                              SizedBox(width: 4),
                              Text(
                                'Voltar',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Página Inicial / NOTIFICAÇÕES',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      'NOTIFICAÇÕES E ALERTAS',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.caveatBrush(
                        fontSize: 34,
                        color: AppColors.primaria,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // TabBar Limpa para Alternar entre Alertas e Ofertas
            Container(
              color: AppColors.primaria,
              child: TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: const [
                  Tab(text: 'Alertas e Pedidos'),
                  Tab(text: 'Ofertas e Clube'),
                ],
              ),
            ),

            // Conteúdo das Notificações
            Expanded(
              child: _carregando
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primaria))
                  : TabBarView(
                controller: _tabController,
                children: [
                  _buildListaNotificacoes(_alertas, 'Nenhum alerta recente no momento.'),
                  _buildListaNotificacoes(_ofertas, 'Nenhuma oferta ativa no momento.'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListaNotificacoes(List<dynamic> itens, String mensagemVazia) {
    if (itens.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_off_outlined, size: 50, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(mensagemVazia, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: itens.length,
      itemBuilder: (context, index) {
        final item = itens[index];
        final bool isOferta = (item['tipo'] ?? '') == 'oferta';
        final bool lida = item['lida'] ?? false;

        final String dataRaw = item['tempo'] ?? item['data_envio'] ?? item['created_at'] ?? '';
        final String dataFormatada = _formatarData(dataRaw);

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(
              color: lida ? Colors.grey.shade200 : AppColors.primaria.withOpacity(0.4),
              width: lida ? 1 : 1.5,
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: isOferta ? Colors.amber.shade100 : Colors.blue.shade50,
              child: Icon(
                isOferta ? Icons.local_offer_rounded : Icons.notifications_active_rounded,
                color: isOferta ? Colors.amber.shade800 : AppColors.primaria,
                size: 20,
              ),
            ),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    item['titulo'] ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: lida ? FontWeight.w600 : FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  dataFormatada,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                item['descricao'] ?? item['mensagem'] ?? '',
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black54,
                ),
              ),
            ),
            onTap: () async {
              if (lida) return;

              setState(() {
                item['lida'] = true;
              });

              try {
                await http.patch(
                  Uri.parse('${widget.baseUrl}/clientes/${widget.clienteId}/notificacoes/${item['id']}/lida'),
                  headers: {
                    'Authorization': 'Bearer ${widget.token}',
                    'Content-Type': 'application/json',
                  },
                );
              } catch (e) {
                debugPrint('Erro na requisição ao marcar notificação como lida: $e');
              }
            },
          ),
        );
      },
    );
  }
}