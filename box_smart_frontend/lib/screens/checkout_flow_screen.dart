import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../main.dart';
import '../services/session_service.dart';
import 'endereco_screen.dart';

class CheckoutFlowScreen extends StatefulWidget {
  final int clienteId;
  final String clienteNome;
  final String token;
  final String baseUrl;
  final Map<int, int> carrinho;
  final List<dynamic> produtosListaGlobal;
  final Set<int> favoritosIds;

  const CheckoutFlowScreen({
    super.key,
    required this.clienteId,
    required this.clienteNome,
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

  // Variáveis efetivas de sessão e usuário
  int _clienteIdEfetivo = 0;
  String _tokenEfetivo = '';
  String _clienteNome = '';
  String _clienteEmail = 'Carregando...';
  String _clienteTelefone = 'Carregando...';
  String _clienteCpf = '';
  bool _carregandoDadosCliente = true;

  // 🎛️ Preferências (Iniciam null para forçar escolha)
  String? _opcaoSubstituicao; // 'reembolso' ou 'similar'
  String? _desejaCpfNota; // 'sim' ou 'nao'

  // 🎟️ Cupom de Desconto
  final TextEditingController _cupomController = TextEditingController();
  double _valorDescontoCupom = 0.0;
  String? _codigoCupomAplicado;
  bool _carregandoCupom = false;

  // 🚚 Entrega, Endereço e Frete Dinâmico
  String _tipoEntrega = 'retirada'; // 'retirada' ou 'delivery'
  int? _enderecoSelecionadoId;
  String _enderecoEntrega = 'Endereço não selecionado';
  double _valorFreteCalculado = 8.00; // Frete padrão delivery
  bool _carregandoFrete = false;

  // 💰 Pagamento e Troco
  String _formaPagamento = 'pix'; // 'pix', 'cartao_credito', 'dinheiro'
  bool _precisaTroco = false;
  final TextEditingController _trocoController = TextEditingController();

  final List<String> _titulosEtapas = ['Carrinho', 'Dados', 'Entrega', 'Pagamento'];

  @override
  void initState() {
    super.initState();
    _clienteIdEfetivo = widget.clienteId;
    _tokenEfetivo = widget.token;
    _clienteNome = widget.clienteNome;
    _carregarSessaoECliente();
  }

  // Carrega da sessão e complementa com a API do cliente
  Future<void> _carregarSessaoECliente() async {
    final sessao = await SessionService.carregarSessao();
    if (mounted) {
      setState(() {
        if (_clienteIdEfetivo <= 0) {
          _clienteIdEfetivo = sessao['clienteId'] ?? 0;
        }
        if (_tokenEfetivo.trim().isEmpty || _tokenEfetivo == 'null') {
          _tokenEfetivo = sessao['token'] ?? '';
        }
        if (_clienteNome.isEmpty || _clienteNome == 'Cliente') {
          _clienteNome = sessao['clienteNome'] ?? widget.clienteNome;
        }
        _clienteEmail = sessao['email'] ?? sessao['clienteEmail'] ?? 'Não informado';
        _clienteTelefone = sessao['telefone'] ?? sessao['clienteTelefone'] ?? 'Não informado';
        _clienteCpf = sessao['cpf'] ?? sessao['cpfCliente'] ?? '';
      });
    }
    await _buscarDadosClienteApi();
  }

  Future<void> _buscarDadosClienteApi() async {
    if (_clienteIdEfetivo <= 0) {
      if (mounted) setState(() => _carregandoDadosCliente = false);
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('${widget.baseUrl}/clientes/$_clienteIdEfetivo'),
        headers: {'Authorization': 'Bearer $_tokenEfetivo'},
      );
      if (response.statusCode == 200 && mounted) {
        final dados = jsonDecode(response.body);
        setState(() {
          _clienteNome = dados['nome'] ?? dados['name'] ?? _clienteNome;
          _clienteEmail = dados['email'] ?? dados['e_mail'] ?? dados['email_cliente'] ?? _clienteEmail;
          _clienteTelefone = dados['telefone'] ?? dados['celular'] ?? dados['whatsapp'] ?? dados['phone'] ?? _clienteTelefone;
          _clienteCpf = dados['cpf'] ?? dados['cpf_cliente'] ?? dados['documento'] ?? _clienteCpf;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _carregandoDadosCliente = false);
      }
    }
  }

  // 🚚 Cálculo de Frete Dinâmico com Backend e Fallback Robusto
  Future<void> _calcularFreteBackend() async {
    if (_tipoEntrega != 'delivery') {
      setState(() => _valorFreteCalculado = 0.0);
      return;
    }

    setState(() => _carregandoFrete = true);

    try {
      String url = '${widget.baseUrl}/api/frete/calcular?subtotal=$_subtotalCarrinho';
      if (_enderecoSelecionadoId != null) {
        url += '&endereco_id=$_enderecoSelecionadoId';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $_tokenEfetivo',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200 && mounted) {
        final dados = json.decode(response.body);
        setState(() {
          _valorFreteCalculado = (dados['valor_frete'] ?? dados['frete'] ?? 8.00).toDouble();
        });
      } else {
        setState(() => _valorFreteCalculado = 8.00);
      }
    } catch (_) {
      setState(() => _valorFreteCalculado = 8.00);
    } finally {
      if (mounted) setState(() => _carregandoFrete = false);
    }
  }

  @override
  void dispose() {
    _cupomController.dispose();
    _trocoController.dispose();
    super.dispose();
  }

  // 🔒 Validações por Etapa
  void _avancarEtapa() {
    if (widget.carrinho.isEmpty && _etapaAtual == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seu carrinho está vazio!')),
      );
      return;
    }

    if (_etapaAtual == 0) {
      if (_opcaoSubstituicao == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor, selecione o que fazer com itens indisponíveis.'), backgroundColor: Colors.orange),
        );
        return;
      }
      if (_desejaCpfNota == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor, informe se deseja CPF na nota.'), backgroundColor: Colors.orange),
        );
        return;
      }
      if (_desejaCpfNota == 'sim' && (_clienteCpf.trim().isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CPF não cadastrado. Altere para "Não" na nota ou cadastre seu CPF.'), backgroundColor: Colors.red),
        );
        return;
      }
    }

    if (_etapaAtual == 2 && _tipoEntrega == 'delivery' && (_enderecoSelecionadoId == null || _enderecoEntrega == 'Endereço não selecionado')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, selecione um endereço de entrega.'), backgroundColor: Colors.red),
      );
      return;
    }

    if (_etapaAtual < 3) {
      setState(() => _etapaAtual++);
      if (_etapaAtual == 3 && _tipoEntrega == 'delivery') {
        _calcularFreteBackend();
      }
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

  // 🎟️ Validação de Cupom
  Future<void> _aplicarCupom() async {
    final codigo = _cupomController.text.trim();
    if (codigo.isEmpty) return;

    setState(() => _carregandoCupom = true);

    try {
      final response = await http.post(
        Uri.parse('${widget.baseUrl}/api/cupons/validar'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_tokenEfetivo',
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
        if (codigo.toUpperCase() == 'BOX10') {
          setState(() {
            _valorDescontoCupom = _subtotalCarrinho * 0.10;
            _codigoCupomAplicado = 'BOX10';
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Cupom BOX10 aplicado (10% de desconto)!'), backgroundColor: Colors.green),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Cupom inválido ou expirado.'), backgroundColor: Colors.red),
            );
          }
        }
      }
    } catch (_) {
      if (codigo.toUpperCase() == 'BOX10') {
        setState(() {
          _valorDescontoCupom = _subtotalCarrinho * 0.10;
          _codigoCupomAplicado = 'BOX10';
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cupom BOX10 aplicado!'), backgroundColor: Colors.green),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erro ao validar cupom.'), backgroundColor: Colors.red),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _carregandoCupom = false);
    }
  }

  // Cálculos de Totais com suporte a peso fracionado
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
        double fator = pesavel ? (qtdOrGramas / 1000.0) : qtdOrGramas.toDouble();
        subtotal += precoEfetivo * fator;
      }
    });
    return subtotal;
  }

  double get _valorTaxaEntrega => _tipoEntrega == 'delivery' ? _valorFreteCalculado : 0.0;

  double get _valorTotalFinal {
    double total = _subtotalCarrinho - _valorDescontoCupom + _valorTaxaEntrega;
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
          // 📊 BARRA DE PROGRESSO SUPERIOR
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

  // 🛒 ETAPA 1: Carrinho
  Widget _buildEtapaCarrinhoCompleto() {
    if (widget.carrinho.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('Seu carrinho está vazio', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaria),
              onPressed: () => Navigator.pop(context),
              child: const Text('Voltar às compras', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('1. Substituir itens indisponíveis? *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
                const SizedBox(height: 4),
                const Text('Selecione uma opção para continuar.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(height: 8),
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Reembolso do valor', style: TextStyle(fontSize: 12)),
                  value: 'reembolso',
                  groupValue: _opcaoSubstituicao,
                  onChanged: (val) => setState(() => _opcaoSubstituicao = val),
                ),
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Substituir por produto similar', style: TextStyle(fontSize: 12)),
                  value: 'similar',
                  groupValue: _opcaoSubstituicao,
                  onChanged: (val) => setState(() => _opcaoSubstituicao = val),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('2. Lista de produtos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: widget.carrinho.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) {
                    final entry = widget.carrinho.entries.elementAt(index);
                    final prodId = entry.key;
                    final qtdOrGramas = entry.value;
                    final prod = _encontrarProdutoGlobal(prodId);

                    if (prod == null) return const SizedBox.shrink();

                    final String nome = prod['nome'] ?? 'Produto';
                    final String? imgUrl = prod['imagem_url'];
                    final double precoNormal = double.tryParse(prod['preco']?.toString().replaceAll(',', '.') ?? '') ?? 0.0;
                    final dynamic precoClubeRaw = prod['preco_clube'];
                    final double precoClube = precoClubeRaw != null ? (double.tryParse(precoClubeRaw.toString().replaceAll(',', '.')) ?? 0.0) : 0.0;
                    final double precoEfetivo = (precoClube > 0) ? precoClube : precoNormal;

                    final bool pesavel = _eVariavelPorPeso(prod);
                    double totalItem = pesavel ? precoEfetivo * (qtdOrGramas / 1000.0) : precoEfetivo * qtdOrGramas;

                    return Row(
                      children: [
                        Container(
                          width: 45,
                          height: 45,
                          padding: const EdgeInsets.all(2),
                          child: imgUrl != null && imgUrl.startsWith('http')
                              ? Image.network(imgUrl, fit: BoxFit.contain)
                              : const Icon(Icons.shopping_bag, color: Colors.grey),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(nome, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 2),
                              Text('R\$ ${precoEfetivo.toStringAsFixed(2).replaceAll('.', ',')}${pesavel ? '/kg' : ''}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'R\$ ${totalItem.toStringAsFixed(2).replaceAll('.', ',')}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaria),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      if (pesavel) {
                                        if (qtdOrGramas > 250) {
                                          widget.carrinho[prodId] = qtdOrGramas - 250;
                                        } else {
                                          widget.carrinho.remove(prodId);
                                        }
                                      } else {
                                        if (qtdOrGramas > 1) {
                                          widget.carrinho[prodId] = qtdOrGramas - 1;
                                        } else {
                                          widget.carrinho.remove(prodId);
                                        }
                                      }
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(4)),
                                    child: const Icon(Icons.remove, size: 12),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: Text(
                                    pesavel ? '${(qtdOrGramas / 1000.0).toStringAsFixed(3).replaceAll('.', ',')}kg' : '$qtdOrGramas',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      if (pesavel) {
                                        widget.carrinho[prodId] = qtdOrGramas + 250;
                                      } else {
                                        widget.carrinho[prodId] = qtdOrGramas + 1;
                                      }
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(4)),
                                    child: const Icon(Icons.add, size: 12),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () => setState(() => widget.carrinho.remove(prodId)),
                                  child: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('3. Deseja CPF na nota? *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Sim', style: TextStyle(fontSize: 12)),
                        value: 'sim',
                        groupValue: _desejaCpfNota,
                        onChanged: (val) => setState(() => _desejaCpfNota = val),
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Não', style: TextStyle(fontSize: 12)),
                        value: 'nao',
                        groupValue: _desejaCpfNota,
                        onChanged: (val) => setState(() => _desejaCpfNota = val),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('4. Cupom e Resumo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _cupomController,
                        decoration: const InputDecoration(
                          hintText: 'Insira seu cupom (Ex: BOX10)',
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
                  Text('Cupom "$_codigoCupomAplicado" aplicado com sucesso!', style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold)),
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

  // 👤 ETAPA 2: Dados Pessoais (Completos e robustos)
  Widget _buildEtapaDadosPessoais() {
    if (_carregandoDadosCliente) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primaria));
    }

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
                _buildInfoRow(Icons.person_outline, 'Nome', _clienteNome),
                const Divider(height: 16),
                _buildInfoRow(Icons.email_outlined, 'E-mail', _clienteEmail),
                const Divider(height: 16),
                _buildInfoRow(Icons.phone_outlined, 'Telefone', _clienteTelefone),
                const Divider(height: 16),
                _buildInfoRow(Icons.badge_outlined, 'CPF', _clienteCpf.isNotEmpty ? _clienteCpf : 'Não informado'),
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

  // 🚚 ETAPA 3: Entrega e Frete Dinâmico
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
                  onChanged: (val) {
                    setState(() {
                      _tipoEntrega = val!;
                      _valorFreteCalculado = 0.0;
                    });
                  },
                ),
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Entrega em Domicílio (Delivery)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Receba no conforto da sua casa', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  value: 'delivery',
                  groupValue: _tipoEntrega,
                  onChanged: (val) {
                    setState(() {
                      _tipoEntrega = val!;
                    });
                    _calcularFreteBackend();
                  },
                ),
              ],
            ),
          ),
        ),
        if (_tipoEntrega == 'delivery') ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.location_on, color: Colors.redAccent, size: 20),
                        SizedBox(width: 8),
                        Text('Endereço de Entrega', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    TextButton(
                      onPressed: () async {
                        final enderecoSelecionado = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EnderecoScreen(
                              clienteId: _clienteIdEfetivo,
                              token: _tokenEfetivo,
                              baseUrl: widget.baseUrl,
                            ),
                          ),
                        );

                        if (enderecoSelecionado != null && enderecoSelecionado is Map) {
                          setState(() {
                            _enderecoSelecionadoId = enderecoSelecionado['id'];
                            final String rua = enderecoSelecionado['rua'] ?? enderecoSelecionado['logradouro'] ?? '';
                            final String numero = enderecoSelecionado['numero']?.toString() ?? '';
                            final String bairro = enderecoSelecionado['bairro'] ?? '';
                            if (rua.isNotEmpty) {
                              _enderecoEntrega = '$rua, $numero${bairro.isNotEmpty ? " - $bairro" : ""}';
                            } else {
                              _enderecoEntrega = 'Endereço selecionado';
                            }
                          });
                          _calcularFreteBackend();
                        }
                      },
                      child: const Text('Selecionar / Trocar', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _enderecoEntrega,
                  style: TextStyle(
                    fontSize: 13,
                    color: _enderecoEntrega == 'Endereço não selecionado' ? Colors.red.shade700 : Colors.black87,
                    fontWeight: _enderecoEntrega == 'Endereço não selecionado' ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                if (_carregandoFrete) ...[
                  const SizedBox(height: 8),
                  const LinearProgressIndicator(minHeight: 2),
                ],
              ],
            ),
          ),
        ],
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

  // 💳 ETAPA 4: Pagamento
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
                const Text('Resumo da Compra', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Subtotal dos Itens', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    Text('R\$ ${_subtotalCarrinho.toStringAsFixed(2).replaceAll('.', ',')}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
                if (_valorDescontoCupom > 0) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Desconto (Cupom)', style: TextStyle(fontSize: 12, color: Colors.green)),
                      Text('- R\$ ${_valorDescontoCupom.toStringAsFixed(2).replaceAll('.', ',')}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green)),
                    ],
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Taxa de Entrega (${_tipoEntrega == 'delivery' ? 'Delivery' : 'Retirada'})', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    Text(_valorTaxaEntrega == 0 ? 'GRÁTIS' : 'R\$ ${_valorTaxaEntrega.toStringAsFixed(2).replaceAll('.', ',')}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Final', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    Text(
                      'R\$ ${_valorTotalFinal.toStringAsFixed(2).replaceAll('.', ',')}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primaria),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
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

  // 🚀 Envio do Pedido
  Future<void> _processarFinalizacaoPedido() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      List<Map<String, dynamic>> itensPayload = [];
      widget.carrinho.forEach((prodId, qtdOrGramas) {
        final prod = _encontrarProdutoGlobal(prodId);
        final bool pesavel = prod != null && _eVariavelPorPeso(prod);
        double quantidadeFinal = pesavel ? (qtdOrGramas / 1000.0) : qtdOrGramas.toDouble();

        itensPayload.add({
          'produto_id': prodId,
          'quantidade': quantidadeFinal,
        });
      });

      double valorTrocoPara = 0.0;
      if (_formaPagamento == 'dinheiro' && _precisaTroco) {
        valorTrocoPara = double.tryParse(_trocoController.text.replaceAll('.', '').replaceAll(',', '.').trim()) ?? 0.0;
      }

      String enderecoFinal = _tipoEntrega == 'delivery' ? _enderecoEntrega : 'Retirada no Box Smart';

      final response = await http.post(
        Uri.parse('${widget.baseUrl}/pedidos'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_tokenEfetivo',
        },
        body: jsonEncode({
          'cliente_id': _clienteIdEfetivo,
          'itens': itensPayload,
          'opcao_substituicao': _opcaoSubstituicao,
          'deseja_cpf_nota': _desejaCpfNota == 'sim',
          'tipo_entrega': _tipoEntrega,
          'endereco_entrega': enderecoFinal,
          'forma_pagamento': _formaPagamento,
          'troco_para': valorTrocoPara,
          'cupom_codigo': _codigoCupomAplicado,
          'valor_desconto_cupom': _valorDescontoCupom,
          'valor_total': _valorTotalFinal,
        }),
      );

      if (mounted) Navigator.pop(context);

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
                  onPressed: () => () {
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