import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class GerenciarNotificacoesTab extends StatefulWidget {
  final String baseUrl;
  final String token;

  const GerenciarNotificacoesTab({Key? key, required this.baseUrl, required this.token}) : super(key: key);

  @override
  State<GerenciarNotificacoesTab> createState() => _GerenciarNotificacoesTabState();
}

class _GerenciarNotificacoesTabState extends State<GerenciarNotificacoesTab> {
  final _formKey = GlobalKey<FormState>();
  final _tituloController = TextEditingController();
  final _mensagemController = TextEditingController();
  final _clienteIdController = TextEditingController();
  String _tipoSelecionado = 'alerta';

  bool _enviando = false;
  bool _carregandoHistorico = true;
  List<dynamic> _historico = [];

  @override
  void initState() {
    super.initState();
    _buscarHistorico();
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _mensagemController.dispose();
    _clienteIdController.dispose();
    super.dispose();
  }

  Future<void> _excluirNotificacao(int id) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Excluir Notificação?'),
        content: const Text('Isso removerá a notificação permanentemente do aplicativo dos clientes.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      final response = await http.delete(
        Uri.parse('${widget.baseUrl}/admin/notificacoes/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
      );

      if (response.statusCode == 204 || response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notificação excluída!'), backgroundColor: Colors.green),
        );
        _buscarHistorico();
      }
    } catch (e) {
      debugPrint('Erro ao excluir: $e');
    }
  }

  Future<void> _buscarHistorico() async {
    setState(() => _carregandoHistorico = true);
    try {
      final response = await http.get(
        Uri.parse('${widget.baseUrl}/admin/notificacoes'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
      );
      if (response.statusCode == 200) {
        setState(() {
          _historico = json.decode(response.body);
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar histórico: $e');
    } finally {
      setState(() => _carregandoHistorico = false);
    }
  }

  Future<void> _dispararNotificacao() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _enviando = true);

    try {
      final response = await http.post(
        Uri.parse('${widget.baseUrl}/admin/notificacoes'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: json.encode({
          'titulo': _tituloController.text,
          'mensagem': _mensagemController.text,
          'tipo': _tipoSelecionado,
          'cliente_id': _clienteIdController.text.isEmpty ? null : int.tryParse(_clienteIdController.text),
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notificação enviada!'), backgroundColor: Colors.green),
        );
        _tituloController.clear();
        _mensagemController.clear();
        _clienteIdController.clear();
        _buscarHistorico();
      }
    } catch (e) {
      debugPrint('Erro: $e');
    } finally {
      setState(() => _enviando = false);
    }
  }

  String _formatarData(String? dataIso) {
    if (dataIso == null || dataIso.isEmpty) return '';
    try {
      final data = DateTime.parse(dataIso).toLocal();
      final dia = data.day.toString().padLeft(2, '0');
      final mes = data.month.toString().padLeft(2, '0');
      final ano = data.year;
      final hora = data.hour.toString().padLeft(2, '0');
      final minuto = data.minute.toString().padLeft(2, '0');

      return '$dia/$mes/$ano às $hora:$minuto';
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          bool telaEstreita = constraints.maxWidth < 900;

          final formularioSection = Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  const Text(
                    'Disparar Nova Campanha',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _tituloController,
                    decoration: const InputDecoration(labelText: 'Título *', border: OutlineInputBorder()),
                    validator: (value) => value!.isEmpty ? 'Campo obrigatório' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _mensagemController,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Mensagem *', border: OutlineInputBorder()),
                    validator: (value) => value!.isEmpty ? 'Campo obrigatório' : null,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _tipoSelecionado,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Tipo', border: OutlineInputBorder()),
                          items: const [
                            DropdownMenuItem(value: 'alerta', child: Text('Alerta Geral', overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 'oferta', child: Text('Oferta', overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 'pedido', child: Text('Pedido', overflow: TextOverflow.ellipsis)),
                          ],
                          onChanged: (value) => setState(() => _tipoSelecionado = value!),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _clienteIdController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'ID Cliente (Opc.)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A8A),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _enviando ? null : _dispararNotificacao,
                    icon: _enviando
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.send, color: Colors.white),
                    label: Text(
                      _enviando ? 'Enviando...' : 'Disparar Notificação',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          );

          final historicoSection = Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Histórico de Envios',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _carregandoHistorico
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E3A8A)))
                      : _historico.isEmpty
                      ? const Center(child: Text('Nenhuma notificação enviada.', style: TextStyle(color: Color(0xFF94A3B8))))
                      : ListView.separated(
                    itemCount: _historico.length,
                    separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    itemBuilder: (context, index) {
                      final item = _historico[index];
                      final isOferta = item['tipo'] == 'oferta';

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: isOferta ? Colors.orange.shade100 : Colors.blue.shade100,
                          child: Icon(
                            isOferta ? Icons.local_offer : Icons.notifications,
                            color: isOferta ? Colors.orange : Colors.blue,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          item['titulo'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          item['mensagem'] ?? '',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        // 🌟 TRAILING BLINDADO CONTRA OVERFLOW USANDO CONSTRAINEDBOX E WRAP
                        trailing: SizedBox(
                          width: 140,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      item['cliente_id'] != null ? 'ID: ${item['cliente_id']}' : 'Para Todos',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: item['cliente_id'] != null ? Colors.blue.shade700 : Colors.green.shade700,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _formatarData(item['data_envio']),
                                      style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                                tooltip: 'Excluir',
                                onPressed: () => _excluirNotificacao(item['id']),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );

          if (telaEstreita) {
            return ListView(
              children: [
                SizedBox(height: 380, child: formularioSection),
                const SizedBox(height: 16),
                SizedBox(height: 400, child: historicoSection),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 4, child: formularioSection),
              const SizedBox(width: 20),
              Expanded(flex: 6, child: historicoSection),
            ],
          );
        },
      ),
    );
  }
}