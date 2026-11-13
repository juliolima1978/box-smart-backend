import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class GerenciarCuponsTab extends StatefulWidget {
  final String baseUrl;
  final String token;

  const GerenciarCuponsTab({
    super.key,
    required this.baseUrl,
    required this.token,
  });

  @override
  State<GerenciarCuponsTab> createState() => _GerenciarCuponsTabState();
}

class _GerenciarCuponsTabState extends State<GerenciarCuponsTab> {
  final _formKey = GlobalKey<FormState>();
  final _codigoController = TextEditingController();
  final _valorDescontoController = TextEditingController();
  final _valorMinimoController = TextEditingController(text: '0');
  final _limiteUsosController = TextEditingController();

  String _tipoDesconto = 'percentual'; // 'percentual' ou 'fixo'
  bool _usoUnicoPorCliente = true;
  DateTime? _dataValidade;

  List<dynamic> _cupons = [];
  bool _carregandoLista = true;
  bool _salvando = false;

  String get _urlBaseLimpa => widget.baseUrl.endsWith('/')
      ? widget.baseUrl.substring(0, widget.baseUrl.length - 1)
      : widget.baseUrl;

  @override
  void initState() {
    super.initState();
    _carregarCupons();
  }

  @override
  void dispose() {
    _codigoController.dispose();
    _valorDescontoController.dispose();
    _valorMinimoController.dispose();
    _limiteUsosController.dispose();
    super.dispose();
  }

  Future<void> _carregarCupons() async {
    setState(() => _carregandoLista = true);
    try {
      final response = await http.get(
        Uri.parse('$_urlBaseLimpa/admin/cupons/'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200 && mounted) {
        setState(() {
          _cupons = jsonDecode(utf8.decode(response.bodyBytes));
        });
      }
    } catch (e) {
      _mostrarSnack('Erro ao carregar cupons: $e', isErro: true);
    } finally {
      if (mounted) setState(() => _carregandoLista = false);
    }
  }

  Future<void> _criarCupom() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _salvando = true);

    try {
      final double valorDesconto =
          double.tryParse(_valorDescontoController.text.replaceAll(',', '.')) ??
              0.0;
      final double valorMinimo =
          double.tryParse(_valorMinimoController.text.replaceAll(',', '.')) ??
              0.0;
      final int? limiteUsos = _limiteUsosController.text.trim().isEmpty
          ? null
          : int.tryParse(_limiteUsosController.text.trim());

      final payload = {
        'codigo': _codigoController.text.trim().toUpperCase(),
        'tipo_desconto': _tipoDesconto,
        'valor_desconto': valorDesconto,
        'valor_minimo_pedido': valorMinimo,
        'limite_usos': limiteUsos,
        'uso_unico_por_cliente': _usoUnicoPorCliente,
        'validade': _dataValidade?.toIso8601String(),
      };

      final response = await http.post(
        Uri.parse('$_urlBaseLimpa/admin/cupons/'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        _codigoController.clear();
        _valorDescontoController.clear();
        _valorMinimoController.text = '0';
        _limiteUsosController.clear();
        setState(() {
          _tipoDesconto = 'percentual';
          _usoUnicoPorCliente = true;
          _dataValidade = null;
        });
        _mostrarSnack('Cupom criado com sucesso!');
        await _carregarCupons();
      } else {
        final erro = jsonDecode(utf8.decode(response.bodyBytes));
        _mostrarSnack(
          erro['detail'] ?? 'Erro ao cadastrar cupom.',
          isErro: true,
        );
      }
    } catch (e) {
      _mostrarSnack('Falha de conexão: $e', isErro: true);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _alternarStatusCupom(int cupomId) async {
    try {
      final response = await http.patch(
        Uri.parse('$_urlBaseLimpa/admin/cupons/$cupomId/toggle'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        await _carregarCupons();
        _mostrarSnack('Status do cupom atualizado!');
      } else {
        _mostrarSnack('Não foi possível alterar o status.', isErro: true);
      }
    } catch (e) {
      _mostrarSnack('Erro de conexão: $e', isErro: true);
    }
  }

  Future<void> _selecionarDataValidade() async {
    final agora = DateTime.now();
    final escolhida = await showDatePicker(
      context: context,
      initialDate: _dataValidade ?? agora.add(const Duration(days: 7)),
      firstDate: agora,
      lastDate: DateTime(agora.year + 5),
    );

    if (escolhida != null) {
      setState(() {
        // Define validade até o fim do dia escolhido
        _dataValidade = DateTime(
          escolhida.year,
          escolhida.month,
          escolhida.day,
          23,
          59,
          59,
        );
      });
    }
  }

  void _mostrarSnack(String msg, {bool isErro = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isErro ? Colors.red : const Color(0xFF15803D),
      ),
    );
  }

  String _formatarData(String? iso) {
    if (iso == null || iso.isEmpty) return 'Sem validade';
    try {
      final dt = DateTime.parse(iso);
      final dia = dt.day.toString().padLeft(2, '0');
      final mes = dt.month.toString().padLeft(2, '0');
      return '$dia/$mes/${dt.year}';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gestão de Cupons Promocionais',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Crie campanhas de desconto e controle os limites de uso no aplicativo.',
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                ],
              ),
              IconButton(
                onPressed: _carregarCupons,
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Atualizar lista',
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Formulário de Criação
          Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Novo Cupom de Desconto',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        SizedBox(
                          width: 220,
                          child: TextFormField(
                            controller: _codigoController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              labelText: 'Código do Cupom *',
                              hintText: 'Ex: BOX10',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Informe o código'
                                : null,
                          ),
                        ),
                        SizedBox(
                          width: 200,
                          child: DropdownButtonFormField<String>(
                            value: _tipoDesconto,
                            decoration: const InputDecoration(
                              labelText: 'Tipo de Desconto',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'percentual',
                                child: Text('Percentual (%)'),
                              ),
                              DropdownMenuItem(
                                value: 'fixo',
                                child: Text('Valor Fixo (R\$)'),
                              ),
                            ],
                            onChanged: (val) =>
                                setState(() => _tipoDesconto = val!),
                          ),
                        ),
                        SizedBox(
                          width: 180,
                          child: TextFormField(
                            controller: _valorDescontoController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: _tipoDesconto == 'percentual'
                                  ? 'Desconto (%) *'
                                  : 'Desconto (R\$) *',
                              hintText: _tipoDesconto == 'percentual'
                                  ? 'Ex: 10'
                                  : 'Ex: 15,00',
                              border: const OutlineInputBorder(),
                              isDense: true,
                            ),
                            validator: (v) {
                              final val = double.tryParse(
                                (v ?? '').replaceAll(',', '.'),
                              );
                              if (val == null || val <= 0) {
                                return 'Valor inválido';
                              }
                              return null;
                            },
                          ),
                        ),
                        SizedBox(
                          width: 200,
                          child: TextFormField(
                            controller: _valorMinimoController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Pedido Mínimo (R\$)',
                              hintText: 'Ex: 50,00',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 190,
                          child: TextFormField(
                            controller: _limiteUsosController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Limite Total de Usos',
                              hintText: 'Vazio = ilimitado',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 220,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                vertical: 15,
                                horizontal: 12,
                              ),
                            ),
                            onPressed: _selecionarDataValidade,
                            icon: const Icon(Icons.calendar_today, size: 16),
                            label: Text(
                              _dataValidade == null
                                  ? 'Definir Validade (Opcional)'
                                  : 'Válido até ${_formatarData(_dataValidade!.toIso8601String())}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Checkbox(
                              value: _usoUnicoPorCliente,
                              onChanged: (v) => setState(
                                    () => _usoUnicoPorCliente = v ?? true,
                              ),
                            ),
                            const Text(
                              'Permitir apenas 1 uso por cliente',
                              style: TextStyle(fontSize: 13),
                            ),
                            if (_dataValidade != null) ...[
                              const SizedBox(width: 16),
                              TextButton(
                                onPressed: () =>
                                    setState(() => _dataValidade = null),
                                child: const Text(
                                  'Limpar data',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ],
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF15803D),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 14,
                            ),
                          ),
                          onPressed: _salvando ? null : _criarCupom,
                          icon: _salvando
                              ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                              : const Icon(
                            Icons.local_offer,
                            color: Colors.white,
                            size: 18,
                          ),
                          label: const Text(
                            'Cadastrar Cupom',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),
          const Text(
            'Cupons Cadastrados',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          if (_carregandoLista)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_cupons.isEmpty)
            Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: const Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    'Nenhum cupom cadastrado ainda.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            )
          else
            Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Código')),
                    DataColumn(label: Text('Desconto')),
                    DataColumn(label: Text('Mínimo')),
                    DataColumn(label: Text('Usos')),
                    DataColumn(label: Text('Regra Cliente')),
                    DataColumn(label: Text('Validade')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Ação')),
                  ],
                  rows: _cupons.map((c) {
                    final bool ativo = c['ativo'] == true;
                    final String tipo = c['tipo_desconto'] ?? 'percentual';
                    final double valor =
                        (c['valor_desconto'] as num?)?.toDouble() ?? 0.0;
                    final double minimo =
                        (c['valor_minimo_pedido'] as num?)?.toDouble() ?? 0.0;
                    final int usosAtuais = c['usos_atuais'] ?? 0;
                    final int? limiteUsos = c['limite_usos'];
                    final bool usoUnico = c['uso_unico_por_cliente'] == true;

                    final String textoDesconto = tipo == 'percentual'
                        ? '${valor.toStringAsFixed(0)}%'
                        : 'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';

                    final String textoUsos = limiteUsos != null
                        ? '$usosAtuais / $limiteUsos'
                        : '$usosAtuais (Ilimitado)';

                    return DataRow(
                      cells: [
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              c['codigo'] ?? '',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade900,
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            textoDesconto,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataCell(
                          Text(
                            'R\$ ${minimo.toStringAsFixed(2).replaceAll('.', ',')}',
                          ),
                        ),
                        DataCell(Text(textoUsos)),
                        DataCell(
                          Text(usoUnico ? '1x por cliente' : 'Múltiplos usos'),
                        ),
                        DataCell(Text(_formatarData(c['validade']))),
                        DataCell(
                          Chip(
                            label: Text(
                              ativo ? 'Ativo' : 'Pausado',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: ativo
                                    ? Colors.green.shade800
                                    : Colors.red.shade800,
                              ),
                            ),
                            backgroundColor: ativo
                                ? Colors.green.shade50
                                : Colors.red.shade50,
                            side: BorderSide.none,
                          ),
                        ),
                        DataCell(
                          Switch(
                            value: ativo,
                            activeColor: const Color(0xFF15803D),
                            onChanged: (_) => _alternarStatusCupom(c['id']),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}