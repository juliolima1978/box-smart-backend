import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../main.dart'; // Importa AppColors se houver

class AdminFreteScreen extends StatefulWidget {
  final String token;
  final String baseUrl;

  const AdminFreteScreen({
    super.key,
    required this.token,
    this.baseUrl = "http://192.168.15.175:8000",
  });

  @override
  State<AdminFreteScreen> createState() => _AdminFreteScreenState();
}

class _AdminFreteScreenState extends State<AdminFreteScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _taxaPadraoController = TextEditingController();
  final TextEditingController _valorMinimoController = TextEditingController();
  bool _freteGratisHoje = false;

  bool _carregando = true;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _carregarConfiguracoes();
  }

  @override
  void dispose() {
    _taxaPadraoController.dispose();
    _valorMinimoController.dispose();
    super.dispose();
  }

  // ==========================================
  // LÓGICA DE API (GET & PUT)
  // ==========================================

  Future<void> _carregarConfiguracoes() async {
    setState(() => _carregando = true);
    try {
      final response = await http.get(
        Uri.parse('${widget.baseUrl}/admin/frete/config'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
        },
      );

      if (response.statusCode == 200) {
        final dados = json.decode(response.body);
        setState(() {
          _taxaPadraoController.text =
              (dados['taxa_padrao'] as num).toDouble().toStringAsFixed(2);
          _valorMinimoController.text =
              (dados['valor_minimo_frete_gratis'] as num).toDouble().toStringAsFixed(2);
          _freteGratisHoje = dados['frete_gratis_hoje'] ?? false;
        });
      } else {
        _exibirSnackBar('Erro ao carregar configurações de frete.', isErro: true);
      }
    } catch (e) {
      _exibirSnackBar('Erro de conexão ao carregar frete: $e', isErro: true);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _salvarConfiguracoes() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _salvando = true);

    final double taxa = double.parse(_taxaPadraoController.text.replaceAll(',', '.'));
    final double minimo = double.parse(_valorMinimoController.text.replaceAll(',', '.'));

    final bodyPayload = json.encode({
      "taxa_padrao": taxa,
      "valor_minimo_frete_gratis": minimo,
      "frete_gratis_hoje": _freteGratisHoje,
    });

    try {
      final response = await http.put(
        Uri.parse('${widget.baseUrl}/admin/frete/config'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: bodyPayload,
      );

      if (response.statusCode == 200) {
        _exibirSnackBar('Regras de entrega atualizadas com sucesso! 🛵');
      } else {
        final erro = json.decode(response.body);
        _exibirSnackBar(erro['detail'] ?? 'Falha ao salvar regras de entrega.', isErro: true);
      }
    } catch (e) {
      _exibirSnackBar('Erro ao conectar ao servidor: $e', isErro: true);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  void _exibirSnackBar(String mensagem, {bool isErro = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: isErro ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ==========================================
  // BUILD DA TELA ADMIN
  // ==========================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          'Gestão de Taxa e Frete',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaria))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // CARD 1: PROMOÇÃO HOJE É FRETE GRÁTIS
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _freteGratisHoje ? Colors.green.shade50 : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _freteGratisHoje ? Colors.green : Colors.grey.shade300,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _freteGratisHoje ? Colors.green.shade100 : Colors.grey.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.card_giftcard_rounded,
                        color: _freteGratisHoje ? Colors.green.shade800 : Colors.grey.shade600,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Promoção "Frete Grátis Hoje"',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _freteGratisHoje
                                ? 'Ativo: Todos os clientes têm frete grátis sem limite de valor.'
                                : 'Desativado: Aplica a taxa padrão e o limite de compras.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _freteGratisHoje,
                      activeColor: Colors.green,
                      onChanged: (val) {
                        setState(() => _freteGratisHoje = val);
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // CARD 2: CONFIGURAÇÕES DE REGRAS PADRÃO
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.tune_rounded, color: AppColors.primaria),
                        SizedBox(width: 8),
                        Text(
                          'Regras Padrão de Cobrança',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),

                    // CAMPO: TAXA PADRÃO
                    TextFormField(
                      controller: _taxaPadraoController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*[\.,]?\d{0,2}')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Taxa Padrão de Entrega (R\$)',
                        hintText: 'Ex: 7.00',
                        prefixIcon: Icon(Icons.delivery_dining_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Informe a taxa padrão.';
                        }
                        if (double.tryParse(val.replaceAll(',', '.')) == null) {
                          return 'Valor numérico inválido.';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // CAMPO: VALOR MÍNIMO FRETE GRÁTIS
                    TextFormField(
                      controller: _valorMinimoController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*[\.,]?\d{0,2}')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Valor Mínimo para Frete Grátis (R\$)',
                        hintText: 'Ex: 100.00',
                        prefixIcon: Icon(Icons.shopping_cart_checkout_rounded),
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Informe o valor mínimo para frete grátis.';
                        }
                        if (double.tryParse(val.replaceAll(',', '.')) == null) {
                          return 'Valor numérico inválido.';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // BOTÃO SALVAR
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaria,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _salvando ? null : _salvarConfiguracoes,
                  icon: _salvando
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : const Icon(Icons.save_rounded),
                  label: Text(
                    _salvando ? 'Salvando...' : 'Salvar Alterações',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}