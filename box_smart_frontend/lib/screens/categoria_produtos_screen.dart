import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../main.dart';
import '../widgets/produto_card.dart';
import 'busca_rapida_screen.dart';
import 'cart_screen.dart';
import 'favorites_screen.dart';
import 'notificacoes_screen.dart';
import 'search_screen.dart';
import 'produto_detalhe_screen.dart';
//import 'profile_screen.dart';

class CategoriaProdutosScreen extends StatefulWidget {
  final int categoriaId;
  final String categoriaNome;
  final String baseUrl;
  final int clienteId;
  final String token;
  final Map<int, int> carrinho;
  final Set<int> favoritosIds;
  final List<dynamic> produtosListaGlobal;

  const CategoriaProdutosScreen({
    super.key,
    required this.categoriaId,
    required this.categoriaNome,
    required this.baseUrl,
    required this.clienteId,
    required this.token,
    required this.carrinho,
    required this.favoritosIds,
    required this.produtosListaGlobal,
  });

  @override
  State<CategoriaProdutosScreen> createState() =>
      _CategoriaProdutosScreenState();
}

class _CategoriaProdutosScreenState extends State<CategoriaProdutosScreen> {
  String _criterioOrdenacao = 'padrao';
  int? _subcategoriaSelecionadaId; // null = Todos
  List<dynamic> _subcategorias = [];
  bool _isLoadingSubcategorias = true;




  // 🔝 CONTROLADORES DE ROLAGEM E BOTÃO VOLTAR AO TOPO
  final ScrollController _scrollController = ScrollController();
  bool _mostrarBotaoTopo = false;

  // 🎛️ ESTADOS DOS FILTROS
  bool _apenasBoxPrime = false;
  bool _apenasPromocoes = false;
  bool _apenasDestaques = false;       // 👈 NOVO
  bool _apenasMaisVendidos = false;
  double _precoMinimoLimite = 0.0;
  double _precoMaximoLimite = 100.0;
  late RangeValues _faixaPreco;

  int get _filtrosAtivosCount {
    int count = 0;
    if (_apenasBoxPrime) count++;
    if (_apenasPromocoes) count++;
    if (_apenasDestaques) count++;       // 👈 NOVO
    if (_apenasMaisVendidos) count++;
    if (_faixaPreco.start > _precoMinimoLimite || _faixaPreco.end < _precoMaximoLimite) count++;
    return count;
  }

  @override
  void initState() {
    super.initState();
    _calcularLimitesPreco();
    _carregarSubcategorias();

    // Listener para exibir/ocultar o botão "Voltar ao Topo" após 300px de rolagem
    _scrollController.addListener(() {
      if (_scrollController.offset >= 300 && !_mostrarBotaoTopo) {
        setState(() => _mostrarBotaoTopo = true);
      } else if (_scrollController.offset < 300 && _mostrarBotaoTopo) {
        setState(() => _mostrarBotaoTopo = false);
      }
    });
  }

  void _calcularLimitesPreco() {
    double maxP = 100.0;
    for (var prod in widget.produtosListaGlobal) {
      double p = double.tryParse(prod['preco']?.toString().replaceAll(',', '.') ?? '') ?? 0.0;
      if (p > maxP) maxP = p;
    }
    _precoMaximoLimite = (maxP / 10).ceil() * 10.0;
    if (_precoMaximoLimite <= 0) _precoMaximoLimite = 100.0;
    _faixaPreco = RangeValues(_precoMinimoLimite, _precoMaximoLimite);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _voltarAoTopo() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  // Helper para remover acentos e comparar strings de categorias com segurança
  String _removerAcentos(String texto) {
    var comAcento =
        'ÀÁÂÃÄÅàáâãäåÒÓÔÕÕÖØòóôõöøÈÉÊËèéêëðÇçÐÌÍÎÏìíîïÙÚÛÜùúûüÑñŠšŸÿýŽž';
    var semAcento =
        'AAAAAAaaaaaaOOOOOOOooooooEEEEeeeeeccDIIIIiiiiUUUUuuuuNnSsYyyZz';
    for (int i = 0; i < comAcento.length; i++) {
      texto = texto.replaceAll(comAcento[i], semAcento[i]);
    }
    return texto.toLowerCase().trim();
  }

  Color _corPorCategoria(String nome) {
    final n = _removerAcentos(nome);

    if (n.contains('acougue') || n.contains('carnes') || n.contains('peixes')) {
      return const Color(0xFF991B1B);
    }
    if (n.contains('horti') ||
        n.contains('verduras') ||
        n.contains('feirinha') ||
        n.contains('frutas')) {
      return const Color(0xFF15803D);
    }
    if (n.contains('padaria') || n.contains('paes') || n.contains('bolos')) {
      return const Color(0xFFB45309);
    }
    if (n.contains('bebida') ||
        n.contains('cerveja') ||
        n.contains('limpeza') ||
        n.contains('vinhos')) {
      return const Color(0xFF1E3A8A);
    }
    if (n.contains('frios') ||
        n.contains('laticinios') ||
        n.contains('queijos')) {
      return const Color(0xFFD97706);
    }

    return AppColors.primaria;
  }

  Future<void> _carregarSubcategorias() async {
    try {
      final response = await http.get(
        Uri.parse(
          '${widget.baseUrl}/api/categorias/${widget.categoriaId}/subcategorias',
        ),
      );
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _subcategorias = jsonDecode(response.body);
            _isLoadingSubcategorias = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingSubcategorias = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingSubcategorias = false);
    }
  }

  void _abrirModalFiltros() {
    bool tempBoxPrime = _apenasBoxPrime;
    bool tempPromocoes = _apenasPromocoes;
    bool tempDestaques = _apenasDestaques;          // 👈 NOVO
    bool tempMaisVendidos = _apenasMaisVendidos;
    RangeValues tempFaixaPreco = _faixaPreco;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom +
                    MediaQuery.of(context).padding.bottom +
                    20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filtros de Produtos',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 10),

                  // 1. Switch Ofertas Box Prime
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(Icons.workspace_premium_rounded, color: Colors.amber),
                    title: const Text(
                      'Ofertas Exclusivas Box Prime',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'Apenas itens com desconto CPF ativado',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    value: tempBoxPrime,
                    activeColor: Colors.amber.shade800,
                    onChanged: (val) {
                      setModalState(() => tempBoxPrime = val);
                    },
                  ),

                  // 2. Switch Promoções
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(Icons.local_offer_rounded, color: Colors.redAccent),
                    title: const Text(
                      'Apenas Produtos em Promoção',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    value: tempPromocoes,
                    activeColor: Colors.redAccent,
                    onChanged: (val) {
                      setModalState(() => tempPromocoes = val);
                    },
                  ),
// 3. Switch Destaques (NOVO)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(Icons.auto_awesome_rounded, color: Colors.purple),
                    title: const Text(
                      'Apenas Produtos em Destaque',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    value: tempDestaques,
                    activeColor: Colors.purple,
                    onChanged: (val) {
                      setModalState(() => tempDestaques = val);
                    },
                  ),

                  // 4. Switch Mais Vendidos (NOVO)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(Icons.local_fire_department_rounded, color: Colors.orange),
                    title: const Text(
                      'Apenas Mais Vendidos',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    value: tempMaisVendidos,
                    activeColor: Colors.orange.shade800,
                    onChanged: (val) {
                      setModalState(() => tempMaisVendidos = val);
                    },
                  ),

                  const SizedBox(height: 12),
                  const Text(
                    'Faixa de Preço',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'R\$ ${tempFaixaPreco.start.toStringAsFixed(2).replaceAll('.', ',')}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaria),
                      ),
                      Text(
                        'R\$ ${tempFaixaPreco.end.toStringAsFixed(2).replaceAll('.', ',')}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaria),
                      ),
                    ],
                  ),
                  RangeSlider(
                    values: tempFaixaPreco,
                    min: _precoMinimoLimite,
                    max: _precoMaximoLimite,
                    divisions: 50,
                    activeColor: AppColors.primaria,
                    labels: RangeLabels(
                      'R\$ ${tempFaixaPreco.start.toStringAsFixed(0)}',
                      'R\$ ${tempFaixaPreco.end.toStringAsFixed(0)}',
                    ),
                    onChanged: (RangeValues values) {
                      setModalState(() => tempFaixaPreco = values);
                    },
                  ),

                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () {
                            setModalState(() {
                              tempBoxPrime = false;
                              tempPromocoes = false;
                              tempDestaques = false;       // 👈 NOVO
                              tempMaisVendidos = false;    // 👈 NOVO
                              tempFaixaPreco = RangeValues(_precoMinimoLimite, _precoMaximoLimite);
                            });
                          },
                          child: const Text('Limpar', style: TextStyle(color: Colors.black87)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E7D32),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () {
                            setState(() {
                              _apenasBoxPrime = tempBoxPrime;
                              _apenasPromocoes = tempPromocoes;
                              _apenasDestaques = tempDestaques;       // 👈 NOVO
                              _apenasMaisVendidos = tempMaisVendidos; // 👈 NOVO
                              _faixaPreco = tempFaixaPreco;
                            });
                            Navigator.pop(context);
                          },
                          child: const Text('Aplicar Filtros', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. Filtragem de produtos por Categoria, Subcategoria e Filtros Ativos
    List<dynamic> produtosFiltrados = widget.produtosListaGlobal.where((prod) {
      final String catProduto = _removerAcentos(
        (prod['categoria'] ?? prod['categoria_nome'] ?? '').toString(),
      );
      final String catAlvo = _removerAcentos(widget.categoriaNome);

      final int? prodCatId = int.tryParse(
        prod['categoria_id']?.toString() ?? '',
      );

      bool pertenceCategoria =
          (catProduto == catAlvo) ||
              (catProduto.contains(catAlvo) || catAlvo.contains(catProduto)) ||
              (prodCatId == widget.categoriaId);

      if (!pertenceCategoria) return false;

      if (_subcategoriaSelecionadaId != null) {
        final int? prodSubId = int.tryParse(
          prod['subcategoria_id']?.toString() ?? '',
        );
        if (prodSubId != _subcategoriaSelecionadaId) return false;
      }

      // 🎛️ FILTROS ATIVOS DO MODAL
      if (_apenasBoxPrime) {
        final bool temClube = prod['preco_clube'] != null;
        if (!temClube) return false;
      }

      if (_apenasPromocoes) {
        final bool emPromo = prod['em_oferta'] == true ||
            prod['preco_promocional'] != null ||
            prod['preco_clube'] != null;
        if (!emPromo) return false;
      }

      // 👈 NOVO: Filtro de Destaques
      if (_apenasDestaques) {
        final dynamic rawDestaque = prod['destaque'] ?? prod['is_destaque'] ?? prod['destacado'];
        final bool eDestaque = rawDestaque == true || rawDestaque == 1 || rawDestaque.toString().toLowerCase() == 'true' || rawDestaque.toString() == '1';
        if (!eDestaque) return false;
      }

      // 👈 NOVO: Filtro de Mais Vendidos
      if (_apenasMaisVendidos) {
        final dynamic rawMaisVendido = prod['mais_vendido'] ?? prod['is_mais_vendido'] ?? prod['maisVendido'];
        final bool eMaisVendido = rawMaisVendido == true || rawMaisVendido == 1 || rawMaisVendido.toString().toLowerCase() == 'true' || rawMaisVendido.toString() == '1';
        if (!eMaisVendido) return false;
      }

      final double preco = double.tryParse(prod['preco']?.toString().replaceAll(',', '.') ?? '') ?? 0.0;
      if (preco < _faixaPreco.start || preco > _faixaPreco.end) {
        return false;
      }

      return true;
    }).toList();

    // 2. Lógica de Ordenação
    if (_criterioOrdenacao == 'menor_preco') {
      produtosFiltrados.sort((a, b) {
        double precoA =
            double.tryParse(a['preco'].toString().replaceAll(',', '.')) ?? 0.0;
        double precoB =
            double.tryParse(b['preco'].toString().replaceAll(',', '.')) ?? 0.0;
        return precoA.compareTo(precoB);
      });
    } else if (_criterioOrdenacao == 'maior_preco') {
      produtosFiltrados.sort((a, b) {
        double precoA =
            double.tryParse(a['preco'].toString().replaceAll(',', '.')) ?? 0.0;
        double precoB =
            double.tryParse(b['preco'].toString().replaceAll(',', '.')) ?? 0.0;
        return precoB.compareTo(precoA);
      });
    } else if (_criterioOrdenacao == 'alfabetica') {
      produtosFiltrados.sort((a, b) {
        String nomeA = (a['nome'] ?? '').toString();
        String nomeB = (b['nome'] ?? '').toString();
        return nomeA.compareTo(nomeB);
      });
    }

    final double topPadding = MediaQuery.of(context).padding.top;
    final double alturaCabecalho = 155 + topPadding;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,

      // 🔝 Botões Flutuantes Empilhados com Badge do Filtro
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_mostrarBotaoTopo) ...[
            FloatingActionButton.small(
              heroTag: 'btnVoltarTopo',
              onPressed: _voltarAoTopo,
              backgroundColor: _corPorCategoria(widget.categoriaNome),
              elevation: 4,
              child: const Icon(
                Icons.keyboard_arrow_up_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(height: 10),
          ],
          FloatingActionButton.extended(
            heroTag: 'btnFiltrosCategoria',
            onPressed: _abrirModalFiltros,
            backgroundColor: _filtrosAtivosCount > 0 ? Colors.amber.shade900 : const Color(0xFF2E7D32),
            elevation: 4,
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.tune_rounded, color: Colors.white, size: 18),
                if (_filtrosAtivosCount > 0)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      child: Text(
                        '$_filtrosAtivosCount',
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
            label: Text(
              _filtrosAtivosCount > 0 ? 'Filtros ($_filtrosAtivosCount)' : 'Filtros',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),

      body: Stack(
        children: [
          SingleChildScrollView(
            controller: _scrollController,
            padding: EdgeInsets.only(top: alturaCabecalho),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => Navigator.of(context).pop(),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 4.0,
                            horizontal: 2.0,
                          ),
                          child: Row(
                            children: const [
                              Icon(
                                Icons.arrow_back_ios_new_rounded,
                                size: 14,
                                color: Colors.black87,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Voltar',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Página Inicial / ${widget.categoriaNome.toUpperCase()}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Text(
                      widget.categoriaNome.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.caveatBrush(
                        fontSize: 44,
                        color: _corPorCategoria(widget.categoriaNome),
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                if (!_isLoadingSubcategorias && _subcategorias.isNotEmpty)
                  SizedBox(
                    height: 110,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _subcategorias.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return _buildSubcategoriaCircular(
                            nome: 'Todos',
                            imagemUrl: '',
                            isSelected: _subcategoriaSelecionadaId == null,
                            onTap: () => setState(
                                  () => _subcategoriaSelecionadaId = null,
                            ),
                          );
                        }
                        final sub = _subcategorias[index - 1];
                        final int subId =
                            int.tryParse(sub['id']?.toString() ?? '') ?? 0;
                        final bool isSelected =
                            _subcategoriaSelecionadaId == subId;
                        return _buildSubcategoriaCircular(
                          nome: sub['nome'] ?? '',
                          imagemUrl: sub['imagem_url'] ?? '',
                          isSelected: isSelected,
                          onTap: () => setState(
                                () => _subcategoriaSelecionadaId = subId,
                          ),
                        );
                      },
                    ),
                  ),

                const SizedBox(height: 16),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _criterioOrdenacao,
                            icon: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 20,
                            ),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'padrao',
                                child: Text('Relevância'),
                              ),
                              DropdownMenuItem(
                                value: 'menor_preco',
                                child: Text('Menor Preço'),
                              ),
                              DropdownMenuItem(
                                value: 'maior_preco',
                                child: Text('Maior Preço'),
                              ),
                              DropdownMenuItem(
                                value: 'alfabetica',
                                child: Text('Nome (A-Z)'),
                              ),
                            ],
                            onChanged: (novo) {
                              if (novo != null)
                                setState(() => _criterioOrdenacao = novo);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => BuscaRapidaScreen(
                                  clienteId: widget.clienteId,
                                  token: widget.token,
                                  baseUrl: widget.baseUrl,
                                  carrinho: widget.carrinho,
                                  favoritosIds: widget.favoritosIds,
                                  produtosListaGlobal: widget.produtosListaGlobal,
                                ),
                              ),
                            );
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Text(
                                'Lista Rápida',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 16,
                                color: Colors.black87,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Barra de Contagem de Produtos
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.symmetric(
                      horizontal: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  child: Text(
                    'Mostrando ${produtosFiltrados.length} de ${widget.produtosListaGlobal.length} produtos',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Grade de Produtos
                produtosFiltrados.isEmpty
                    ? const Padding(
                  padding: EdgeInsets.all(40.0),
                  child: Center(
                    child: Text(
                      'Nenhum produto encontrado com os filtros selecionados.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
                    : GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(12),
                  gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.49,
                  ),
                  itemCount: produtosFiltrados.length,
                  itemBuilder: (context, index) {
                    final prod = produtosFiltrados[index];

                    return ProdutoCard(
                      produto: prod,
                      carrinho: widget.carrinho,
                      favoritosIds: widget.favoritosIds,
                      produtosListaGlobal: widget.produtosListaGlobal,
                      onCarrinhoAlterado: () => setState(() {}),
                      onToggleFavorito: (id) async {
                        setState(() {
                          if (widget.favoritosIds.contains(id)) {
                            widget.favoritosIds.remove(id);
                          } else {
                            widget.favoritosIds.add(id);
                          }
                        });

                        try {
                          await http.post(
                            Uri.parse(
                              '${widget.baseUrl}/clientes/${widget.clienteId}/favoritos/$id',
                            ),
                            headers: {
                              'Content-Type': 'application/json',
                              'Authorization': 'Bearer ${widget.token}',
                            },
                          );
                        } catch (e) {
                          debugPrint('Erro ao sincronizar favorito: $e');
                        }
                      },
                      onTapDetalhes: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProdutoDetalheScreen(
                              clienteId: widget.clienteId,
                              token: widget.token,
                              favoritosIds: widget.favoritosIds,
                              produto: prod,
                              carrinho: widget.carrinho,
                              produtosListaGlobal:
                              widget.produtosListaGlobal,
                            ),
                          ),
                        ).then((_) {
                          if (mounted) setState(() {});
                        });
                      },
                    );
                  },
                ),

                const SizedBox(height: 80),
              ],
            ),
          ),

          // Cabeçalho fixo no topo
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: alturaCabecalho,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 3,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              padding: EdgeInsets.only(
                top: topPadding + 8,
                left: 16,
                right: 16,
                bottom: 10,
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Image.asset(
                              'assets/icones/circle-user (2).png',
                              color: AppColors.primaria,
                              height: 26,
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ProfileScreen(
                                    clienteId: widget.clienteId,
                                    token: widget.token,
                                  ),
                                ),
                              );
                            },
                          ),
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              IconButton(
                                icon: Image.asset(
                                  'assets/icones/order-history_thin.png',
                                  width: 24,
                                  height: 24,
                                  color: AppColors.primaria,
                                  colorBlendMode: BlendMode.srcIn,
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => CartScreen(
                                        clienteId: widget.clienteId,
                                        token: widget.token,
                                        carrinho: widget.carrinho,
                                        produtos: widget.produtosListaGlobal,
                                        clienteNome: 'Cliente',
                                        favoritosIds: widget.favoritosIds,
                                        onLimparCarrinho: () {
                                          setState(() {
                                            widget.carrinho.clear();
                                          });
                                        },
                                      ),
                                    ),
                                  ).then((_) {
                                    if (mounted) setState(() {});
                                  });
                                },
                              ),
                              if (widget.carrinho.isNotEmpty)
                                Positioned(
                                  right: 9,
                                  top: 5,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    constraints: const BoxConstraints(
                                      minWidth: 16,
                                      minHeight: 16,
                                    ),
                                    child: Text(
                                      '${widget.carrinho.length}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      Expanded(
                        child: Center(
                          child: GestureDetector(
                            onTap: () => Navigator.of(
                              context,
                            ).popUntil((route) => route.isFirst),
                            child: Image.asset(
                              'assets/logogimptesc.png',
                              height: 75,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Text(
                                'BOX SMART',
                                style: TextStyle(
                                  color: AppColors.primaria,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Image.asset(
                              'assets/icones/heart_thin.png',
                              width: 22,
                              height: 22,
                              color: AppColors.primaria,
                              colorBlendMode: BlendMode.srcIn,
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => FavoritesScreen(
                                    clienteId: widget.clienteId,
                                    token: widget.token,
                                    baseUrl: widget.baseUrl,
                                    carrinho: widget.carrinho,
                                    favoritosIds: widget.favoritosIds,
                                    produtosListaGlobal:
                                    widget.produtosListaGlobal,
                                    onAtualizouCarrinho: () => setState(() {}),
                                  ),
                                ),
                              ).then((_) {
                                if (mounted) setState(() {});
                              });
                            },
                          ),
                          IconButton(
                            icon: Image.asset(
                              'assets/icones/bell (1).png',
                              color: AppColors.primaria,
                              height: 22,
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => NotificacoesScreen(
                                    clienteId: widget.clienteId,
                                    token: widget.token,
                                    baseUrl: widget.baseUrl,
                                  ),
                                ),
                              ).then((_) {
                                if (mounted) setState(() {});
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: TextField(
                      readOnly: true,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SearchScreen(
                              clienteId: widget.clienteId,
                              token: widget.token,
                              carrinho: widget.carrinho,
                              favoritosIds: widget.favoritosIds,
                              produtosListaGlobal: widget.produtosListaGlobal,
                             // baseUrl: '',
                            ),
                          ),
                        ).then((_) {
                          if (mounted) setState(() {});
                        });
                      },
                      decoration: const InputDecoration(
                        hintText: 'O que você procura hoje?',
                        hintStyle: TextStyle(fontSize: 12, color: Colors.grey),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: Colors.grey,
                          size: 20,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubcategoriaCircular({
    required String nome,
    required String imagemUrl,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final Color corDestaque = _corPorCategoria(widget.categoriaNome);

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(right: 16.0),
        child: Column(
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? corDestaque : Colors.grey.shade300,
                  width: isSelected ? 2.5 : 1.0,
                ),
                color: Colors.white,
              ),
              child: Padding(
                padding: const EdgeInsets.all(3.0),
                child: ClipOval(
                  child: imagemUrl.isNotEmpty && imagemUrl.startsWith('http')
                      ? Image.network(
                    imagemUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.restaurant_rounded,
                      color: Colors.grey,
                    ),
                  )
                      : Container(
                    color: isSelected
                        ? corDestaque.withOpacity(0.1)
                        : Colors.grey.shade100,
                    child: Icon(
                      Icons.grid_view_rounded,
                      color: isSelected
                          ? corDestaque
                          : Colors.grey.shade600,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 72,
              child: Text(
                nome,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? corDestaque : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}