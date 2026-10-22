import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../main.dart';

class CheckoutFlowScreen extends StatefulWidget {
  final int clienteId;
  final String token;
  final String baseUrl;
  final Map<int, int> carrinho;
  final List<dynamic> produtosListaGlobal;
  final Set<int> favoritosIds;

  const CheckoutFlowScreen({
    super.key,
    required this.clienteId,
    required this.token,
    required this.baseUrl,
    required this.carrinho,
    required this.produtosListaGlobal,
    required this.favoritosIds,
  });

  @override
  State<CheckoutFlowScreen> createState() => _CheckoutFlowScreenState();
}

class _CheckoutFlowScreenState extends State<CheckoutFlowScreen> {
  int _etapaAtual = 0; // 0: Carrinho, 1: Dados, 2: Entrega, 3: Pagamento

  // 🎛️ Preferências do Checkout
  String _opcaoSubstituicao = 'reembolso'; // 'reembolso' ou 'similar'
  String _desejaCpfNota = 'sim'; // 'sim' ou 'nao'
  String? _cpfCliente;

  // 🎟️ Cupom de Desconto
  final TextEditingController _cupomController = TextEditingController();
  double _valorDescontoCupom = 0.0;
  String? _codigoCupomAplicado;
  bool _carregandoCupom = false;

  // 💰 Pagamento e Troco
  String _formaPagamento = 'pix'; // 'pix', 'cartao_credito', 'dinheiro'
  bool _precisaTroco = false;
  final TextEditingController _trocoController = TextEditingController();

  // 🚚 Entrega
  String _tipoEntrega = 'retirada'; // 'retirada' ou 'delivery'

  final List<String> _titulosEtapas = ['Carrinho', 'Dados', 'Entrega', 'Pagamento'];

  @override
  void initState() {
    super.initState();
    _carregarDadosCliente();
  }

  Future<void> _carregarDadosCliente() async {
    try {
      final response = await http.get(
        Uri.parse('${widget.baseUrl}/clientes/${widget.clienteId}'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (response.statusCode == 200) {
        final dados = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _cpfCliente = dados['cpf'];
          });
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _cupomController.dispose();
    _trocoController.dispose();
    super.dispose();
  }

  void _avancarEtapa() {
    if (widget.carrinho.isEmpty && _etapaAtual == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seu carrinho está vazio!')),
      );
      return;
    }

    // Validação de CPF na nota (Ponto 2)
    if (_etapaAtual == 0 && _desejaCpfNota == 'sim' && (_cpfCliente == null || _cpfCliente!.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, informe seu CPF no cadastro ou altere para "Não" na nota.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_etapaAtual < 3) {
      setState(() => _etapaAtual++);
    } else {
      _processarFinalizacaoPedido();
    }
  }

  void _voltarEtapa() {
    if (_etapaAtual > 0) {
      setState(() => _etapaAtual--);
    } else {
      Navigator.pop(context);
    }
  }

  // 🎟️ Lógica de Validação e Aplicação do Cupom (Ponto 3)
  Future<void> _aplicarCupom() async {
    final codigo = _cupomController.text.trim();
    if (codigo.isEmpty) return;

    setState(() => _carregandoCupom = true);

    try {
      final response = await http.post(
        Uri.parse('${widget.baseUrl}/api/cupons/validar'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: jsonEncode({
          'codigo': codigo,
          'subtotal': _subtotalCarrinho,
        }),
      );

      if (response.statusCode == 200) {
        final dados = jsonDecode(response.body);
        setState(() {
          _valorDescontoCupom = (dados['valor_desconto'] as num).toDouble();
          _codigoCupomAplicado = codigo;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cupom aplicado com sucesso!'), backgroundColor: Colors.green),
          );
        }
      } else {
        final erro = jsonDecode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(erro['detail'] ?? 'Cupom inválido ou expirado.'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao validar cupom.'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _carregandoCupom = false);
    }
  }

  // Cálculos de Totais
  double get _subtotalCarrinho {
    double subtotal = 0.0;
    widget.carrinho.forEach((prodId, qtdOrGramas) {
      final prod = _encontrarProdutoGlobal(prodId);
      if (prod != null) {
        final double precoNormal = double.tryParse(prod['preco']?.toString().replaceAll(',', '.') ?? '') ?? 0.0;
        final dynamic precoClubeRaw = prod['preco_clube'];
        final double precoClube = precoClubeRaw != null ? (double.tryParse(precoClubeRaw.toString().replaceAll(',', '.')) ?? 0.0) : 0.0;
        final double precoEfetivo = (precoClube > 0) ? precoClube : precoNormal;

        final bool pesavel = _eVariavelPorPeso(prod);
        if (pesavel) {
          subtotal += precoEfetivo * (qtdOrGramas / 1000.0);
        } else {
          subtotal += precoEfetivo * qtdOrGramas;
        }
      }
    });
    return subtotal;
  }

  double get _valorTotalFinal {
    double total = _subtotalCarrinho - _valorDescontoCupom;
    return total < 0 ? 0.0 : total;
  }

  Map<String, dynamic>? _encontrarProdutoGlobal(int id) {
    try {
      return widget.produtosListaGlobal.firstWhere((p) {
        if (p is! Map) return false;
        final pid = int.tryParse(p['id']?.toString() ?? p['codigo']?.toString() ?? '') ?? -1;
        return pid == id;
      }) as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  bool _eVariavelPorPeso(Map<String, dynamic> prod) {
    final String nome = (prod['nome'] ?? '').toString().toLowerCase();
    final String un = (prod['unidade'] ?? prod['unidade_medida'] ?? '').toString().trim().toLowerCase();
    final dynamic varPeso = prod['variavel_por_peso'] ?? prod['peso_variavel'] ?? prod['fracionado'] ?? prod['pesavel'];
    if (varPeso == true || varPeso == 1 || varPeso.toString().toLowerCase() == 'true') return true;
    if (['kg', 'quilo', 'quilos', 'g', 'gramas'].contains(un) || un.startsWith('kg')) return true;
    return nome.contains('patinho') || nome.contains('alcatra') || nome.contains('carne') || nome.contains('frango') || nome.contains('queijo');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Finalizar Compra', style: TextStyle(fontSize: 16)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: _voltarEtapa,
        ),
      ),
      body: Column(
        children: [
          // 📊 BARRA DE PROGRESSO SUPERIOR (Steppers)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_titulosEtapas.length, (index) {
                bool selecionado = _etapaAtual == index;
                bool concluido = _etapaAtual > index;

                return Row(
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: concluido || selecionado ? AppColors.primaria : Colors.grey.shade300,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: concluido
                                ? const Icon(Icons.check, color: Colors.white, size: 16)
                                : Text(
                              '${index + 1}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _titulosEtapas[index],
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: selecionado ? FontWeight.bold : FontWeight.normal,
                            color: selecionado ? AppColors.primaria : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    if (index < _titulosEtapas.length - 1)
                      Container(
                        width: 24,
                        height: 2,
                        color: _etapaAtual > index ? AppColors.primaria : Colors.grey.shade300,
                        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                      ),
                  ],
                );
              }),
            ),
          ),
          const Divider(height: 1),

          // 📄 CONTEÚDO DAS ETAPAS
          Expanded(
            child: IndexedStack(
              index: _etapaAtual,
              children: [
                _buildEtapaCarrinhoCompleto(),
                _buildEtapaDadosPessoais(),
                _buildEtapaEntrega(),
                _buildEtapaPagamento(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 🛒 ETAPA 1: Carrinho, Preferências, Substituição e CPF na Nota
  Widget _buildEtapaCarrinhoCompleto() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 1. Substituir Itens Indisponíveis (Ponto 1)
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('1. Substituir itens indisponíveis?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                const Text('As substituições serão enviadas ao separador caso haja itens semelhantes.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(height: 8),
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Reembolso do valor', style: TextStyle(fontSize: 12)),
                  value: 'reembolso',
                  groupValue: _opcaoSubstituicao,
                  onChanged: (val) => setState(() => _opcaoSubstituicao = val!),
                ),
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Substituir por produto similar', style: TextStyle(fontSize: 12)),
                  value: 'similar',
                  groupValue: _opcaoSubstituicao,
                  onChanged: (val) => setState(() => _opcaoSubstituicao = val!),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 2. Deseja CPF na Nota (Ponto 2)
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('2. Deseja CPF na nota?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Sim', style: TextStyle(fontSize: 12)),
                        value: 'sim',
                        groupValue: _desejaCpfNota,
                        onChanged: (val) => setState(() => _desejaCpfNota = val!),
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Não', style: TextStyle(fontSize: 12)),
                        value: 'nao',
                        groupValue: _desejaCpfNota,
                        onChanged: (val) => setState(() => _desejaCpfNota = val!),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 3. Cupom de Desconto & Resumo (Ponto 3)
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('3. Cupom e Resumo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _cupomController,
                        decoration: const InputDecoration(
                          hintText: 'Insira seu cupom',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF15803D)),
                      onPressed: _carregandoCupom ? null : _aplicarCupom,
                      child: _carregandoCupom
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Aplicar', style: TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                  ],
                ),
                if (_codigoCupomAplicado != null) ...[
                  const SizedBox(height: 6),
                  Text('Cupom "$_codigoCupomAplicado" aplicado!', style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold)),
                ],
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Subtotal', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    Text('R\$ ${_subtotalCarrinho.toStringAsFixed(2).replaceAll('.', ',')}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
                if (_valorDescontoCupom > 0) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Desconto Cupom', style: TextStyle(fontSize: 12, color: Colors.green)),
                      Text('- R\$ ${_valorDescontoCupom.toStringAsFixed(2).replaceAll('.', ',')}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green)),
                    ],
                  ),
                ],
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Parcial', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    Text(
                      'R\$ ${_valorTotalFinal.toStringAsFixed(2).replaceAll('.', ',')}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.primaria),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaria,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _avancarEtapa,
                    child: const Text('Continuar para Dados Pessoais', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 👤 ETAPA 2: Dados Pessoais
  Widget _buildEtapaDadosPessoais() {
    return FutureBuilder<http.Response>(
      future: http.get(
        Uri.parse('${widget.baseUrl}/clientes/${widget.clienteId}'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        Map<String, dynamic> clienteData = {};
        if (snapshot.hasData && snapshot.data!.statusCode == 200) {
          try {
            clienteData = jsonDecode(snapshot.data!.body);
          } catch (_) {}
        }

        final String nome = clienteData['nome'] ?? 'Cliente Box Smart';
        final String email = clienteData['email'] ?? 'Não informado';
        final String telefone = clienteData['telefone'] ?? 'Não informado';
        final String cpf = clienteData['cpf'] ?? 'Não informado';

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Confirme seus dados cadastrais', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 12),
                    _buildInfoRow(Icons.person_outline, 'Nome', nome),
                    const Divider(height: 16),
                    _buildInfoRow(Icons.email_outlined, 'E-mail', email),
                    const Divider(height: 16),
                    _buildInfoRow(Icons.phone_outlined, 'Telefone', telefone),
                    const Divider(height: 16),
                    _buildInfoRow(Icons.badge_outlined, 'CPF', cpf),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaria,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _avancarEtapa,
              child: const Text('Continuar para Entrega', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primaria),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87)),
          ],
        ),
      ],
    );
  }

  // 🚚 ETAPA 3: Entrega
  Widget _buildEtapaEntrega() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Escolha a forma de recebimento', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 12),
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Retirada no Box Smart (Grátis)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Retire diretamente no armário inteligente', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  value: 'retirada',
                  groupValue: _tipoEntrega,
                  onChanged: (val) => setState(() => _tipoEntrega = val!),
                ),
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Entrega em Domicílio (Delivery)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Receba no conforto da sua casa', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  value: 'delivery',
                  groupValue: _tipoEntrega,
                  onChanged: (val) => setState(() => _tipoEntrega = val!),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaria,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _avancarEtapa,
          child: const Text('Continuar para Pagamento', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  // 💳 ETAPA 4: Pagamento com suporte a Dinheiro/Troco (Ponto 4)
  Widget _buildEtapaPagamento() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Forma de Pagamento', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 12),
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.qr_code_rounded, color: Colors.teal),
                  title: const Text('PIX (Aprovação imediata)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  value: 'pix',
                  groupValue: _formaPagamento,
                  onChanged: (val) => setState(() {
                    _formaPagamento = val!;
                    _precisaTroco = false;
                  }),
                ),
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.credit_card_rounded, color: Colors.blue),
                  title: const Text('Cartão de Crédito / Débito', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  value: 'cartao_credito',
                  groupValue: _formaPagamento,
                  onChanged: (val) => setState(() {
                    _formaPagamento = val!;
                    _precisaTroco = false;
                  }),
                ),
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.money_rounded, color: Colors.green),
                  title: const Text('Dinheiro na Retirada/Entrega', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  value: 'dinheiro',
                  groupValue: _formaPagamento,
                  onChanged: (val) => setState(() => _formaPagamento = val!),
                ),

                // Estrutura de Troco (Ponto 4)
                if (_formaPagamento == 'dinheiro') ...[
                  const Divider(height: 20),
                  Row(
                    children: [
                      Checkbox(
                        value: _precisaTroco,
                        onChanged: (val) => setState(() => _precisaTroco = val ?? false),
                      ),
                      const Text('Precisa de troco?', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  if (_precisaTroco)
                    Padding(
                      padding: const EdgeInsets.only(left: 12, top: 8),
                      child: TextField(
                        controller: _trocoController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Troco para quanto? (Ex: 100,00)',
                          prefixText: 'R\$ ',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF15803D),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _processarFinalizacaoPedido,
          child: const Text('Finalizar Pedido Agora', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
        ),
      ],
    );
  }

  // 🚀 Envio do Pedido com todos os dados consolidados para o Backend
  Future<void> _processarFinalizacaoPedido() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      List<Map<String, dynamic>> itensPayload = [];
      widget.carrinho.forEach((prodId, qtdOrGramas) {
        itensPayload.add({
          'produto_id': prodId,
          'quantidade': qtdOrGramas,
        });
      });

      double valorTrocoPara = 0.0;
      if (_formaPagamento == 'dinheiro' && _precisaTroco) {
        valorTrocoPara = double.tryParse(_trocoController.text.replaceAll('.', '').replaceAll(',', '.').trim()) ?? 0.0;
      }

      final response = await http.post(
        Uri.parse('${widget.baseUrl}/pedidos'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: jsonEncode({
          'cliente_id': widget.clienteId,
          'itens': itensPayload,
          'opcao_substituicao': _opcaoSubstituicao,
          'deseja_cpf_nota': _desejaCpfNota == 'sim',
          'tipo_entrega': _tipoEntrega,
          'forma_pagamento': _formaPagamento,
          'troco_para': valorTrocoPara,
          'cupom_codigo': _codigoCupomAplicado,
          'valor_desconto_cupom': _valorDescontoCupom,
          'valor_total': _valorTotalFinal,
        }),
      );

      if (mounted) Navigator.pop(context); // Fecha loading

      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() => widget.carrinho.clear());

        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
                  SizedBox(width: 8),
                  Text('Pedido Realizado!', style: TextStyle(fontSize: 16)),
                ],
              ),
              content: const Text('Seu pedido foi registrado com sucesso e já está sendo preparado no Box Smart!'),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaria),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  child: const Text('OK', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao finalizar pedido: ${response.body}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro de conexão: $e')),
        );
      }
    }
  }
}