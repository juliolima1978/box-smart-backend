import 'package:box_smart_frontend/screens/painel/entregador_screen.dart';
import 'package:box_smart_frontend/screens/search_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'box_prime_screen.dart';
import 'categoria_produtos_screen.dart';
import 'favorites_screen.dart';
import 'notificacoes_screen.dart';
import '../main.dart';
import 'cart_screen.dart';
import 'produto_detalhe_screen.dart';
import 'busca_rapida_screen.dart';
import 'package:box_smart_frontend/widgets/produto_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  final int clienteId;
  final String clienteNome;
  final String token;

  const HomeScreen({
    super.key,
    required this.clienteId,
    required this.clienteNome,
    required this.token,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _indiceAtual = 0;
  late final Map<int, int> _carrinho = {};
  List<dynamic> _produtosBackend = [];
  Set<int> _favoritosIds = {};

  String _logoUrl = '';
  Map<String, dynamic> _footerData = {};
  bool _carregandoConfig = true;

  List<dynamic> _departamentosBackend = [];
  bool _carregandoDepartamentos = true;

  // Mapa para controlar a página atual (dots) de cada seção horizontal de produtos
  final Map<String, int> _paginasSecoes = {};

  // Retorna a lista de produtos cujos IDs estão presentes no Set _favoritosIds
  List<dynamic> get _produtosFavoritos {
    return _produtosBackend.where((prod) {
      if (prod is! Map) return false;
      final dynamic rawId = prod['id'] ?? prod['codigo'];
      final int? id = int.tryParse(rawId.toString());
      return id != null && _favoritosIds.contains(id);
    }).toList();
  }

  late final PageController _bannerController;
  int _paginaBannerAtual = 0;

  late Future<List<dynamic>> _futuroHome;
  String get baseUrl => "https://box-smart-backend.onrender.com";

  int _totalNotificacoesNaoLidas = 0;
  DateTime? _ultimoTempoVoltar;

  @override
  void initState() {
    super.initState();
    _bannerController = PageController();
    _futuroHome = _buscarHomeDinamica();
    _verificarNotificacoesNaoLidas();
    _carregarFavoritos();
    _carregarDepartamentos();
    _carregarProdutosGerais();
    _carregarConfiguracoesApp();
    _carregarCarrinhoLocal();
  }

  Future<void> _recarregarHome() async {
    _verificarNotificacoesNaoLidas();
    _carregarFavoritos();
    _carregarDepartamentos();
    _carregarProdutosGerais();
    _carregarConfiguracoesApp();

    setState(() {
      _futuroHome = _buscarHomeDinamica();
    });

    await _futuroHome;
  }

  Future<void> _salvarCarrinhoLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final Map<String, int> carrinhoStringKeys = _carrinho.map(
            (key, value) => MapEntry(key.toString(), value),
      );
      final String jsonCarrinho = json.encode(carrinhoStringKeys);
      await prefs.setString(
        'carrinho_box_smart_${widget.clienteId}',
        jsonCarrinho,
      );
    } catch (e) {
      debugPrint('Erro ao salvar carrinho localmente: $e');
    }
  }

  Future<void> _carregarCarrinhoLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonCarrinho = prefs.getString(
        'carrinho_box_smart_${widget.clienteId}',
      );

      if (jsonCarrinho != null && jsonCarrinho.isNotEmpty) {
        final Map<String, dynamic> decoded = json.decode(jsonCarrinho);
        if (mounted) {
          setState(() {
            _carrinho.clear();
            decoded.forEach((key, value) {
              final int? id = int.tryParse(key);
              final int? qtd = int.tryParse(value.toString());
              if (id != null && qtd != null && qtd > 0) {
                _carrinho[id] = qtd;
              }
            });
          });
        }
      }
    } catch (e) {
      debugPrint('Erro ao carregar carrinho local: $e');
    }
  }

  Future<void> _carregarConfiguracoesApp() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/config'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _logoUrl = data['logo_url'] ?? '';
            _footerData = data['footer'] ?? {};
            _carregandoConfig = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Erro ao carregar configurações visuais: $e');
      if (mounted) setState(() => _carregandoConfig = false);
    }
  }

  Future<void> _verificarNotificacoesNaoLidas() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/clientes/${widget.clienteId}/notificacoes'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _totalNotificacoesNaoLidas = data
                .where((item) => (item['lida'] ?? false) == false)
                .length;
          });
        }
      }
    } catch (e) {
      debugPrint('Erro ao buscar notificações: $e');
    }
  }

  void _proximoSlideBanner(int totalImagens) {
    if (_bannerController.hasClients && totalImagens > 0) {
      final proximaPagina = _bannerController.page!.round() + 1;
      _bannerController.animateToPage(
        proximaPagina,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _anteriorSlideBanner() {
    if (_bannerController.hasClients) {
      final paginaAnterior = _bannerController.page!.round() - 1;
      _bannerController.animateToPage(
        paginaAnterior,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Color _parseCor(String? hexColor) {
    if (hexColor == null || hexColor.isEmpty) return const Color(0xFFFFFFFF);
    try {
      var buffer = StringBuffer();
      String hex = hexColor.replaceFirst('#', '');
      if (hex.length == 6) {
        buffer.write('ff');
        buffer.write(hex);
        return Color(int.parse(buffer.toString(), radix: 16));
      } else if (hex.length == 8) {
        buffer.write(hex);
        return Color(int.parse(buffer.toString(), radix: 16));
      }
    } catch (_) {}
    return const Color(0xFFFFFFFF);
  }

  Future<void> _carregarProdutosGerais() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/produtos/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
      );
      if (response.statusCode == 200) {
        final List<dynamic> prodsRaw = json.decode(response.body);

        final List<dynamic> prodsFiltrados = prodsRaw.where((prod) {
          final String imgUrl =
              prod['imagem_url']?.toString().toLowerCase() ?? '';
          if (imgUrl.contains('seu-storage.com.br') ||
              imgUrl.contains('seustorage')) {
            return false;
          }

          final dynamic rawEstoque =
              prod['estoque'] ??
                  prod['qtd_estoque'] ??
                  prod['quantidade_estoque'];
          if (rawEstoque != null) {
            final double? estoqueNum = double.tryParse(
              rawEstoque.toString().replaceAll(',', '.'),
            );
            if (estoqueNum != null && estoqueNum <= 0) {
              return false;
            }
          }

          return true;
        }).toList();

        if (mounted) {
          setState(() {
            _produtosBackend = prodsFiltrados;
          });
        }
      }
    } catch (e) {
      debugPrint('Erro ao carregar produtos gerais: $e');
    }
  }

  Future<void> _carregarDepartamentos() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/departamentos/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
      );

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _departamentosBackend = jsonDecode(response.body);
          });
        }
      }
    } catch (e) {
      debugPrint('Erro ao carregar departamentos: $e');
    } finally {
      if (mounted) {
        setState(() {
          _carregandoDepartamentos = false;
        });
      }
    }
  }

  Future<void> _carregarFavoritos() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/clientes/${widget.clienteId}/favoritos/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
      );
      if (response.statusCode == 200) {
        final List<dynamic> ids = json.decode(response.body);
        if (mounted) {
          setState(() {
            _favoritosIds = ids.map((e) => int.parse(e.toString())).toSet();
          });
        }
      }
    } catch (e) {
      debugPrint('Erro ao carregar favoritos: $e');
    }
  }

  Future<void> _toggleFavorito(int produtoId) async {
    setState(() {
      if (_favoritosIds.contains(produtoId)) {
        _favoritosIds.remove(produtoId);
      } else {
        _favoritosIds.add(produtoId);
      }
    });

    try {
      await http.post(
        Uri.parse('$baseUrl/clientes/${widget.clienteId}/favoritos/$produtoId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
      );
    } catch (e) {
      debugPrint('Erro ao sincronizar favorito: $e');
    }
  }

  @override
  void dispose() {
    _bannerController.dispose();
    super.dispose();
  }

  Future<List<dynamic>> _buscarHomeDinamica() async {
    try {
      final response = await http
          .get(
        Uri.parse('$baseUrl/api/home'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
      )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 &&
          response.body.isNotEmpty &&
          response.body != 'null') {
        final decoded = await compute(json.decode, response.body);
        if (decoded is List) {
          return decoded;
        } else if (decoded is Map && decoded.containsKey('secoes')) {
          return decoded['secoes'] ?? [];
        }
      }
    } catch (e) {
      debugPrint('Erro na API da Home: $e');
    }

    return [];
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> telas = [
      _buildHomeConteudo(context),
      BuscaRapidaScreen(
        clienteId: widget.clienteId,
        token: widget.token,
        carrinho: _carrinho,
        favoritosIds: _favoritosIds,
        produtosListaGlobal: _produtosBackend,
        baseUrl: baseUrl,
        onMudarAba: (novoIndice) {
          setState(() {
            _indiceAtual = novoIndice;
          });
        },
      ),
      CartScreen(
        carrinho: _carrinho,
        produtos: _produtosBackend.isNotEmpty ? _produtosBackend : [],
        clienteId: widget.clienteId,
        clienteNome: widget.clienteNome,
        favoritosIds: _favoritosIds,
        token: widget.token,
        onMudarAba: (novoIndice) {
          setState(() {
            _indiceAtual = novoIndice;
          });
        },
        onLimparCarrinho: () {
          setState(() {
            _carrinho.clear();
          });
          _salvarCarrinhoLocal();
        },
      ),
      ProfileScreen(clienteId: widget.clienteId, token: widget.token),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        if (_indiceAtual != 0) {
          setState(() {
            _indiceAtual = 0;
          });
          return;
        }

        final agora = DateTime.now();
        const limiteTempo = Duration(seconds: 2);

        if (_ultimoTempoVoltar == null ||
            agora.difference(_ultimoTempoVoltar!) > limiteTempo) {
          _ultimoTempoVoltar = agora;

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pressione novamente para sair do Box Smart'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }

        Navigator.of(context).pop();
      },
      child: Scaffold(
        body: telas[_indiceAtual],
        bottomNavigationBar: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BottomNavigationBar(
              currentIndex: _indiceAtual > 2 ? 2 : _indiceAtual,
              onTap: (index) {
                if (index == 2) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => BoxPrimeScreen(
                        clienteId: widget.clienteId,
                        token: widget.token,
                        baseUrl: baseUrl,
                      ),
                    ),
                  );
                } else {
                  setState(() {
                    _indiceAtual = index;
                  });
                }
              },
              selectedItemColor: AppColors.primaria,
              unselectedItemColor: Colors.black,
              selectedLabelStyle: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
              unselectedLabelStyle: const TextStyle(fontSize: 10),
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.white,
              elevation: 0,
              selectedIconTheme: const IconThemeData(size: 24),
              unselectedIconTheme: const IconThemeData(size: 24),
              items: [
                BottomNavigationBarItem(
                  icon: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Image.asset(
                      'assets/icones/home_thin.png',
                      width: 22,
                      height: 22,
                      fit: BoxFit.contain,
                      color: _indiceAtual == 0
                          ? AppColors.primaria
                          : Colors.grey.shade400,
                      colorBlendMode: BlendMode.srcIn,
                    ),
                  ),
                  label: 'Início',
                ),
                BottomNavigationBarItem(
                  icon: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Image.asset(
                      'assets/icones/catalog-magazine_thin.png',
                      width: 22,
                      height: 22,
                      fit: BoxFit.contain,
                      color: _indiceAtual == 1
                          ? AppColors.primaria
                          : Colors.grey.shade400,
                      colorBlendMode: BlendMode.srcIn,
                    ),
                  ),
                  label: 'Lista Rápida',
                ),
                BottomNavigationBarItem(
                  icon: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade700,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.workspace_premium_rounded,
                            size: 15,
                            color: Colors.white,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Prime',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  label: 'Box Prime',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHomeConteudo(BuildContext context) {
    final double topPadding = MediaQuery.of(context).padding.top;
    final double alturaCabecalho = 155 + topPadding;

    return Container(
      color: Colors.grey.shade50,
      child: Stack(
        children: [
          RefreshIndicator(
            color: AppColors.primaria,
            backgroundColor: Colors.white,
            displacement: alturaCabecalho + 20,
            onRefresh: _recarregarHome,
            child: FutureBuilder<List<dynamic>>(
              future: _futuroHome,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                final secoes = snapshot.data ?? [];

                return CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: SizedBox(height: alturaCabecalho),
                    ),
                    for (var secao in secoes) _buildSliverSecao(secao),
                    SliverToBoxAdapter(child: _buildFooter(context)),
                  ],
                );
              },
            ),
          ),
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
                            iconSize: 22,
                            tooltip: 'Perfil',
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
                                  fit: BoxFit.contain,
                                  color: AppColors.primaria,
                                  colorBlendMode: BlendMode.srcIn,
                                ),
                                tooltip: 'Carrinho',
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => CartScreen(
                                        clienteId: widget.clienteId,
                                        token: widget.token,
                                        carrinho: _carrinho,
                                        produtos: _produtosBackend,
                                        clienteNome: widget.clienteNome,
                                        favoritosIds: _favoritosIds,
                                        onLimparCarrinho: () {
                                          setState(() {
                                            _carrinho.clear();
                                          });
                                          _salvarCarrinhoLocal();
                                        },
                                      ),
                                    ),
                                  ).then((_) {
                                    if (mounted) {
                                      setState(() {});
                                      _salvarCarrinhoLocal();
                                    }
                                  });
                                },
                              ),
                              if (_carrinho.values.fold(
                                0,
                                    (sum, element) => sum + element,
                              ) >
                                  0)
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
                                      '${_carrinho.entries.where((e) => e.value > 0).length}',
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
                          child: SizedBox(
                            height: 75,
                            child: _logoUrl.isNotEmpty
                                ? (_logoUrl.startsWith('http')
                                ? Image.network(
                              _logoUrl,
                              fit: BoxFit.contain,
                              errorBuilder:
                                  (
                                  context,
                                  error,
                                  stackTrace,
                                  ) => Image.asset(
                                'assets/logogimptesc.png',
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) =>
                                const Text(
                                  'BOX SMART',
                                  style: TextStyle(
                                    color:
                                    AppColors.primaria,
                                    fontSize: 15,
                                    fontWeight:
                                    FontWeight.w900,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ),
                            )
                                : Image.asset(
                              _logoUrl,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) =>
                                  Image.asset(
                                    'assets/logogimptesc.png',
                                    fit: BoxFit.contain,
                                  ),
                            ))
                                : Image.asset(
                              'assets/logogimptesc.png',
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return const Text(
                                  'BOX SMART',
                                  style: TextStyle(
                                    color: AppColors.primaria,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.5,
                                  ),
                                );
                              },
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
                              fit: BoxFit.contain,
                              color: AppColors.primaria,
                              colorBlendMode: BlendMode.srcIn,
                            ),
                            tooltip: 'Meus Favoritos',
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => FavoritesScreen(
                                    clienteId: widget.clienteId,
                                    token: widget.token,
                                    baseUrl: baseUrl,
                                    carrinho: _carrinho,
                                    favoritosIds: _favoritosIds,
                                    produtosListaGlobal: _produtosBackend,
                                    onAtualizouCarrinho: () {},
                                  ),
                                ),
                              ).then((_) {
                                if (mounted) {
                                  setState(() {});
                                  _salvarCarrinhoLocal();
                                }
                              });
                            },
                          ),
                          IconButton(
                            icon: Stack(
                              children: [
                                Image.asset(
                                  'assets/icones/bell (1).png',
                                  color: AppColors.primaria,
                                  height: 22,
                                ),
                                if (_totalNotificacoesNaoLidas > 0)
                                  Positioned(
                                    right: 1,
                                    top: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      constraints: const BoxConstraints(
                                        minWidth: 14,
                                        minHeight: 14,
                                      ),
                                      child: Text(
                                        '$_totalNotificacoesNaoLidas',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => NotificacoesScreen(
                                    clienteId: widget.clienteId,
                                    token: widget.token,
                                    baseUrl: baseUrl,
                                  ),
                                ),
                              ).then((_) {
                                _verificarNotificacoesNaoLidas();
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
                              carrinho: _carrinho,
                              favoritosIds: _favoritosIds,
                              produtosListaGlobal: _produtosBackend,
                            ),
                          ),
                        ).then((_) {
                          if (mounted) {
                            setState(() {});
                            _salvarCarrinhoLocal();
                          }
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'O que você procura hoje?',
                        hintStyle: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: Colors.grey.shade500,
                          size: 20,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10,
                        ),
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

  Widget _buildSliverSecao(Map<String, dynamic> secao) {
    final String tipo = (secao['tipo'] ?? 'padrao').toString().toLowerCase();
    final String tituloSecao = secao['titulo'] ?? 'Seção';
    // Chave única para identificar a página atual dos dots desta seção no mapa
    final String secaoKey = '${tituloSecao}_${secao.hashCode}';

    switch (tipo) {
      case 'banner_principal':
        List imagens = [];
        if (secao['itens'] != null && (secao['itens'] as List).isNotEmpty) {
          imagens = secao['itens'];
        } else if (secao['banner_url'] != null &&
            secao['banner_url'].toString().isNotEmpty) {
          imagens = [
            {'imagem_url': secao['banner_url']},
          ];
        }

        if (imagens.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }

        final int totalImagens = imagens.length;

        return SliverToBoxAdapter(
          child: Container(
            color: AppColors.primaria,
            child: SizedBox(
              height: 220,
              child: Stack(
                children: [
                  PageView.builder(
                    controller: _bannerController,
                    onPageChanged: (index) {
                      if (totalImagens > 0) {
                        setState(() {
                          _paginaBannerAtual = index % totalImagens;
                        });
                      }
                    },
                    itemCount: totalImagens == 0 ? 1 : 1000,
                    itemBuilder: (context, index) {
                      if (totalImagens == 0) return const SizedBox.shrink();
                      final int realIndex = index % totalImagens;
                      final dynamic bannerObj = imagens[realIndex];

                      final String url = bannerObj is Map
                          ? (bannerObj['imagem_url'] ??
                          bannerObj['banner_url'] ??
                          '')
                          : bannerObj.toString();
                      final String? acaoTipo = bannerObj is Map
                          ? bannerObj['acao_tipo']
                          : null;
                      final String? acaoValor = bannerObj is Map
                          ? bannerObj['acao_valor']
                          : null;

                      final bool eRede =
                          url.startsWith('http://') ||
                              url.startsWith('https://');

                      return GestureDetector(
                        onTap: () async {
                          if (acaoTipo == null || acaoTipo.isEmpty) return;
                          if (acaoTipo == 'categoria' && acaoValor != null) {
                            final categoriaEncontrada = _departamentosBackend
                                .firstWhere(
                                  (cat) =>
                              (cat['nome'] ?? '')
                                  .toString()
                                  .trim()
                                  .toLowerCase() ==
                                  acaoValor.trim().toLowerCase(),
                              orElse: () => null,
                            );
                            final int catIdEncontrado =
                            categoriaEncontrada != null
                                ? categoriaEncontrada['id']
                                : 0;

                            final int? abaSelecionada =
                            await Navigator.push<int>(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    CategoriaProdutosScreen(
                                      categoriaId: catIdEncontrado,
                                      categoriaNome: acaoValor,
                                      baseUrl: baseUrl,
                                      clienteId: widget.clienteId,
                                      token: widget.token,
                                      carrinho: _carrinho,
                                      favoritosIds: _favoritosIds,
                                      produtosListaGlobal: _produtosBackend,
                                    ),
                              ),
                            );

                            if (abaSelecionada != null && mounted) {
                              setState(() {
                                _indiceAtual = abaSelecionada;
                              });
                            } else if (mounted) {
                              setState(() {});
                              _salvarCarrinhoLocal();
                            }
                          } else if (acaoTipo == 'clube_prime') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => BoxPrimeScreen(
                                  clienteId: widget.clienteId,
                                  token: widget.token,
                                  baseUrl: baseUrl,
                                ),
                              ),
                            );
                          }
                        },
                        child: Container(
                          color: Colors.grey.shade300,
                          child: eRede
                              ? Image.network(
                            url,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(
                                Icons.broken_image_outlined,
                                size: 50,
                                color: Colors.grey,
                              ),
                            ),
                          )
                              : Image.asset(
                            url,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(
                                Icons.image_not_supported_outlined,
                                size: 50,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  if (totalImagens > 1)
                    Positioned(
                      right: 8,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: SizedBox(
                          width: 32,
                          height: 32,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            style: IconButton.styleFrom(
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(
                              Icons.chevron_right_rounded,
                              size: 24,
                            ),
                            onPressed: () => _proximoSlideBanner(totalImagens),
                          ),
                        ),
                      ),
                    ),
                  if (totalImagens > 1)
                    Positioned(
                      left: 8,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: SizedBox(
                          width: 32,
                          height: 32,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            style: IconButton.styleFrom(
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(
                              Icons.chevron_left_rounded,
                              size: 24,
                            ),
                            onPressed: _anteriorSlideBanner,
                          ),
                        ),
                      ),
                    ),
                  if (totalImagens > 1)
                    Positioned(
                      bottom: 10,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(totalImagens, (index) {
                          final bool eAtivo =
                              (_paginaBannerAtual % totalImagens) == index;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            height: 8,
                            width: eAtivo ? 20 : 8,
                            decoration: BoxDecoration(
                              color: eAtivo
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        }),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );

      case 'departamentos':
        return SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  tituloSecao,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaria,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 115,
                child: _carregandoDepartamentos
                    ? const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : _departamentosBackend.isEmpty
                    ? const Center(
                  child: Text(
                    'Nenhum departamento encontrado',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                )
                    : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _departamentosBackend.length,
                  itemBuilder: (context, index) {
                    final realIndex =
                        index % _departamentosBackend.length;
                    final cat = _departamentosBackend[realIndex];

                    final int catId = cat['id'] ?? 0;
                    final String nome = cat['nome'] ?? 'Setor';
                    final String? imagemUrl =
                        cat['imagem_url'] ?? cat['imagem'];

                    final String? corFundoHex = cat['cor_fundo'];
                    final Color corFundoAplicada =
                    (corFundoHex != null && corFundoHex.isNotEmpty)
                        ? _parseCor(corFundoHex)
                        : Colors.white;

                    final String? corTextoHex = cat['cor_texto'];
                    final Color corTextoAplicada =
                    (corTextoHex != null && corTextoHex.isNotEmpty)
                        ? _parseCor(corTextoHex)
                        : Colors.black87;

                    final String? corIconeHex = cat['cor_icone'];
                    final bool temCorIcone =
                        corIconeHex != null &&
                            corIconeHex.toString().trim().isNotEmpty;
                    final bool eFotoCompleta =
                        cat['is_foto'] == true ||
                            cat['e_foto'] == true ||
                            (!temCorIcone &&
                                imagemUrl != null &&
                                imagemUrl.startsWith('http'));

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: GestureDetector(
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  CategoriaProdutosScreen(
                                    categoriaId: catId,
                                    categoriaNome: nome,
                                    baseUrl: baseUrl,
                                    clienteId: widget.clienteId,
                                    token: widget.token,
                                    carrinho: _carrinho,
                                    favoritosIds: _favoritosIds,
                                    produtosListaGlobal: _produtosBackend,
                                  ),
                            ),
                          );

                          if (mounted) {
                            setState(() {});
                            _salvarCarrinhoLocal();
                          }
                        },
                        child: Column(
                          children: [
                            Container(
                              width: 68,
                              height: 68,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: eFotoCompleta
                                    ? Colors.white
                                    : corFundoAplicada,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
                                    blurRadius: 6,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child:
                              eFotoCompleta &&
                                  imagemUrl != null &&
                                  imagemUrl.startsWith('http')
                                  ? ClipOval(
                                child: Image.network(
                                  imagemUrl,
                                  width: 68,
                                  height: 68,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      Padding(
                                        padding:
                                        const EdgeInsets.all(
                                          14.0,
                                        ),
                                        child: Icon(
                                          Icons.storefront,
                                          color: _parseCor(
                                            corIconeHex,
                                          ),
                                          size: 26,
                                        ),
                                      ),
                                ),
                              )
                                  : Padding(
                                padding: const EdgeInsets.all(14.0),
                                child:
                                imagemUrl != null &&
                                    imagemUrl.startsWith('http')
                                    ? Image.network(
                                  imagemUrl,
                                  width: 28,
                                  height: 28,
                                  fit: BoxFit.contain,
                                  color: _parseCor(
                                    corIconeHex,
                                  ),
                                  colorBlendMode:
                                  BlendMode.srcIn,
                                  errorBuilder:
                                      (_, __, ___) => Icon(
                                    Icons.storefront,
                                    color: _parseCor(
                                      corIconeHex,
                                    ),
                                    size: 26,
                                  ),
                                )
                                    : Icon(
                                  Icons.storefront,
                                  color: _parseCor(
                                    corIconeHex,
                                  ),
                                  size: 26,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              width: 75,
                              child: Text(
                                nome,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: corTextoAplicada,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );

      case 'grade_produtos':
      case 'ofertas':
      case 'ofertas_clube':
      case 'clube_prime':
      case 'destaques':
      case 'mais_vendidos':
      case 'livre':
      case 'curadoria':
      case 'padrao':
      case 'carrossel':
        List produtosSecao = secao['produtos'] ?? [];

        if (produtosSecao.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }

        final int paginaAtualSecao = _paginasSecoes[secaoKey] ?? 0;

        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    tituloSecao,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // 🔄 Carrossel com PageView para suportar os dots dinâmicos
                SizedBox(
                  height: 310,
                  child: PageView.builder(
                    controller: PageController(viewportFraction: 0.52),
                    itemCount: produtosSecao.length,
                    onPageChanged: (index) {
                      setState(() {
                        _paginasSecoes[secaoKey] = index;
                      });
                    },
                    itemBuilder: (context, index) {
                      final prod = produtosSecao[index];
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        child: ProdutoCard(
                          produto: prod,
                          carrinho: _carrinho,
                          favoritosIds: _favoritosIds,
                          produtosListaGlobal: _produtosBackend,
                          onCarrinhoAlterado: () {
                            setState(() {});
                            _salvarCarrinhoLocal();
                          },
                          onToggleFavorito: (produtoId) {
                            _toggleFavorito(produtoId);
                          },
                          onTapDetalhes: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ProdutoDetalheScreen(
                                  clienteId: widget.clienteId,
                                  token: widget.token,
                                  favoritosIds: _favoritosIds,
                                  produto: prod,
                                  carrinho: _carrinho,
                                  produtosListaGlobal: _produtosBackend,
                                ),
                              ),
                            ).then((_) {
                              if (mounted) {
                                setState(() {});
                                _salvarCarrinhoLocal();
                              }
                            });
                          },
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                // 🔘 Indicadores de Página (Dots em formato de pílula) abaixo do carrossel
                if (produtosSecao.length > 1)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(produtosSecao.length, (index) {
                      bool selecionado = paginaAtualSecao == index;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 3.0),
                        height: 6.0,
                        width: selecionado ? 20.0 : 6.0,
                        decoration: BoxDecoration(
                          color: selecionado
                              ? AppColors.primaria
                              : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(3.0),
                        ),
                      );
                    }),
                  ),
              ],
            ),
          ),
        );

      case 'banner_secundario':
        List imagens = [];
        if (secao['itens'] != null && (secao['itens'] as List).isNotEmpty) {
          imagens = secao['itens'];
        } else if (secao['banner_url'] != null &&
            secao['banner_url'].toString().isNotEmpty) {
          imagens = [
            {'imagem_url': secao['banner_url']},
          ];
        }

        if (imagens.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }

        return SliverToBoxAdapter(
          child: Column(
            children: [
              SizedBox(
                height: 140,
                child: PageView.builder(
                  itemCount: imagens.length,
                  itemBuilder: (context, index) {
                    final dynamic bannerObj = imagens[index];
                    final String bannerUrl = bannerObj is Map
                        ? (bannerObj['imagem_url'] ??
                        bannerObj['banner_url'] ??
                        '')
                        : bannerObj.toString();
                    final String? acaoTipo = bannerObj is Map
                        ? bannerObj['acao_tipo']
                        : null;
                    final String? acaoValor = bannerObj is Map
                        ? bannerObj['acao_valor']
                        : null;

                    final bool eRede =
                        bannerUrl.startsWith('http://') ||
                            bannerUrl.startsWith('https://');

                    return GestureDetector(
                      onTap: () async {
                        if (acaoTipo == null || acaoTipo.isEmpty) return;
                        if (acaoTipo == 'categoria' && acaoValor != null) {
                          final categoriaEncontrada = _departamentosBackend
                              .firstWhere(
                                (cat) =>
                            (cat['nome'] ?? '')
                                .toString()
                                .trim()
                                .toLowerCase() ==
                                acaoValor.trim().toLowerCase(),
                            orElse: () => null,
                          );

                          final int catIdEncontrado =
                          categoriaEncontrada != null
                              ? categoriaEncontrada['id']
                              : 0;

                          final int? abaSelecionada = await Navigator.push<int>(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CategoriaProdutosScreen(
                                categoriaId: catIdEncontrado,
                                categoriaNome: acaoValor,
                                baseUrl: baseUrl,
                                clienteId: widget.clienteId,
                                token: widget.token,
                                carrinho: _carrinho,
                                favoritosIds: _favoritosIds,
                                produtosListaGlobal: _produtosBackend,
                              ),
                            ),
                          );

                          if (abaSelecionada != null && mounted) {
                            setState(() {
                              _indiceAtual = abaSelecionada;
                            });
                          } else if (mounted) {
                            setState(() {});
                            _salvarCarrinhoLocal();
                          }
                        } else if (acaoTipo == 'clube_prime') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => BoxPrimeScreen(
                                clienteId: widget.clienteId,
                                token: widget.token,
                                baseUrl: baseUrl,
                              ),
                            ),
                          );
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          color: Colors.grey.shade300,
                          image: DecorationImage(
                            image: eRede
                                ? NetworkImage(bannerUrl)
                                : AssetImage(bannerUrl) as ImageProvider,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );

      default:
        if (secao['produtos'] != null &&
            (secao['produtos'] as List).isNotEmpty) {
          final List produtosSecao = secao['produtos'];

          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tituloSecao,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.49,
                    ),
                    itemCount: produtosSecao.length,
                    itemBuilder: (context, index) {
                      final prod = produtosSecao[index];
                      return ProdutoCard(
                        produto: prod,
                        carrinho: _carrinho,
                        favoritosIds: _favoritosIds,
                        produtosListaGlobal: _produtosBackend,
                        onCarrinhoAlterado: () {
                          setState(() {});
                          _salvarCarrinhoLocal();
                        },
                        onToggleFavorito: (produtoId) {
                          _toggleFavorito(produtoId);
                        },
                        onTapDetalhes: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ProdutoDetalheScreen(
                                clienteId: widget.clienteId,
                                token: widget.token,
                                favoritosIds: _favoritosIds,
                                produto: prod,
                                carrinho: _carrinho,
                                produtosListaGlobal: _produtosBackend,
                              ),
                            ),
                          ).then((_) {
                            if (mounted) {
                              setState(() {});
                              _salvarCarrinhoLocal();
                            }
                          });
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        }
        return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
  }

  final TextEditingController _newsletterController = TextEditingController();

  Future<void> _inscreverNewsletter() async {
    final email = _newsletterController.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, insira um e-mail válido.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/newsletter/inscrever'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: jsonEncode({'email': email}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _newsletterController.clear();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Inscrição realizada com sucesso! Obrigado.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao se inscrever. Tente novamente mais tarde.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Falha de conexão: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _abrirPaginaInstitucionalDinamica(BuildContext context, String titulo, String conteudo) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).padding.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    titulo,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaria,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 10),
            Text(
              conteudo.isNotEmpty ? conteudo : 'Informações institucionais do Box Smart.',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaria,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('Entendido', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _lancarUrlExterna(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      debugPrint('Não foi possível abrir o link: $urlString');
    }
  }

  Widget _buildFooter(BuildContext context) {
    final String copyrightText = _footerData['texto_copyright'] ??
        '© 2026 Supermercado Tescarollo. Todos os direitos reservados.';

    final List institucionalItens = _footerData['coluna_institucional'] ?? [
      {'titulo': 'Sobre Nós', 'conteudo': 'O Tescarollo revoluciona suas compras.'},
      {'titulo': 'Fale Conosco', 'conteudo': 'Atendimento via comercial@tescarollo.com.br'}
    ];
    final List plataformaItens = _footerData['coluna_plataforma'] ?? [
      {'titulo': 'Funcionalidades', 'conteudo': 'Aplicativo inteligente de supermercado.'}
    ];
    final List suporteItens = _footerData['coluna_suporte'] ?? [
      {'titulo': 'Central de Ajuda', 'conteudo': 'Estamos prontos para ajudar.'}
    ];
    final Map redesSociais = _footerData['redes_sociais'] ?? {};

    return Container(
      color: AppColors.primaria,
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 50),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              bool isDesktop = constraints.maxWidth > 900;
              if (isDesktop) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildColunaLogo(redesSociais),
                    _buildColunaLinksDinamica('Institucional', institucionalItens),
                    _buildColunaLinksDinamica('Plataforma', plataformaItens),
                    _buildColunaLinksDinamica('Suporte', suporteItens),
                    _buildColunaNewsletter(),
                  ],
                );
              } else {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildColunaLogo(redesSociais),
                    const SizedBox(height: 30),
                    _buildColunaLinksDinamica('Institucional', institucionalItens),
                    const SizedBox(height: 25),
                    _buildColunaLinksDinamica('Plataforma', plataformaItens),
                    const SizedBox(height: 25),
                    _buildColunaLinksDinamica('Suporte', suporteItens),
                    const SizedBox(height: 30),
                    _buildColunaNewsletter(),
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 40),
          const Divider(color: Colors.white24, thickness: 1),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              bool isDesktop = constraints.maxWidth > 700;
              if (isDesktop) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        copyrightText,
                        style: const TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                    ),
                    Row(
                      children: [
                        const Text(
                          'Métodos de pagamento (Visa, MasterCard, Elo, Pix)',
                          style: TextStyle(color: Colors.white60, fontSize: 11),
                        ),
                        const SizedBox(width: 15),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Feito com ❤️ no Brasil',
                            style: TextStyle(
                              color: Colors.black87,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              } else {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      copyrightText,
                      style: const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Métodos de pagamento: Visa, MasterCard, Elo, Pix',
                      style: TextStyle(color: Colors.white60, fontSize: 11),
                    ),
                    const SizedBox(height: 15),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Feito com ❤️ no Brasil',
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildColunaLogo(Map redesSociais) {
    return SizedBox(
      width: 250,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _logoUrl.isNotEmpty && _logoUrl.startsWith('http')
              ? Image.network(
            _logoUrl,
            height: 38,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _buildLogoDefaultFooter(),
          )
              : _buildLogoDefaultFooter(),
          const SizedBox(height: 12),
          Text(
            _footerData['subtitulo'] ?? 'Soluções inteligentes para organização e gestão de espaços.',
            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              if (redesSociais['whatsapp'] != null)
                _buildSocialIcon(Icons.phone, () => _lancarUrlExterna(redesSociais['whatsapp'])),
              if (redesSociais['whatsapp'] != null) const SizedBox(width: 12),

              if (redesSociais['instagram'] != null)
                _buildSocialIcon(Icons.camera_alt, () => _lancarUrlExterna(redesSociais['instagram'])),
              if (redesSociais['instagram'] != null) const SizedBox(width: 12),

              if (redesSociais['facebook'] != null)
                _buildSocialIcon(Icons.facebook, () => _lancarUrlExterna(redesSociais['facebook'])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogoDefaultFooter() {
    return const Row(
      children: [
        Icon(Icons.store, color: Colors.white, size: 28),
        SizedBox(width: 8),
        Text(
          'Box Smart',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildSocialIcon(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }

  Widget _buildColunaLinksDinamica(String tituloColuna, List itens) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tituloColuna,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 14),
        ...itens.map((item) {
          final String nomeItem = item['titulo'] ?? '';
          final String conteudoItem = item['conteudo'] ?? '';

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              onTap: () => _abrirPaginaInstitucionalDinamica(context, nomeItem, conteudoItem),
              child: Text(
                nomeItem,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.white30,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildColunaNewsletter() {
    return SizedBox(
      width: 280,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Assine a Newsletter',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Receba novidades e dicas exclusivas diretamente no seu e-mail.',
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: TextField(
                    controller: _newsletterController,
                    decoration: const InputDecoration(
                      hintText: 'Seu melhor e-mail',
                      hintStyle: TextStyle(fontSize: 12, color: Colors.grey),
                      border: InputBorder.none,
                    ),
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  elevation: 0,
                ),
                onPressed: _inscreverNewsletter,
                child: const Text(
                  'Inscrever',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}