import 'package:flutter/material.dart';
import '../main.dart'; // Ajuste conforme a localização de AppColors no seu projeto

class ProdutoCard extends StatefulWidget {
  final Map<String, dynamic> produto;
  final Map<int, int> carrinho;
  final Set<int> favoritosIds;
  final List<dynamic> produtosListaGlobal;
  final VoidCallback onCarrinhoAlterado;
  final Function(int) onToggleFavorito;
  final VoidCallback onTapDetalhes;

  const ProdutoCard({
    super.key,
    required this.produto,
    required this.carrinho,
    required this.favoritosIds,
    required this.produtosListaGlobal,
    required this.onCarrinhoAlterado,
    required this.onToggleFavorito,
    required this.onTapDetalhes,
  });

  @override
  State<ProdutoCard> createState() => _ProdutoCardState();
}

class _ProdutoCardState extends State<ProdutoCard> {
  Map<String, dynamic> get _produtoCompleto {
    final Map<String, dynamic> prodMap = Map<String, dynamic>.from(widget.produto);

    if (widget.produtosListaGlobal.isNotEmpty) {
      final idBusca = prodMap['id']?.toString() ?? prodMap['codigo']?.toString();
      if (idBusca != null) {
        final completo = widget.produtosListaGlobal.firstWhere((p) {
          if (p is! Map) return false;
          final idGlobal = p['id']?.toString() ?? p['codigo']?.toString();
          return idGlobal == idBusca;
        }, orElse: () => <String, dynamic>{});

        if (completo.isNotEmpty && completo is Map<String, dynamic>) {
          prodMap.addAll(completo);
        }
      }
    }
    return prodMap;
  }

  int get _produtoId {
    final prod = _produtoCompleto;
    final dynamic rawId = prod['id'] ?? prod['codigo'];
    return int.tryParse(rawId.toString()) ?? (rawId is int ? rawId : widget.produto.hashCode);
  }

  bool get _eVariavelPorPeso {
    final prod = _produtoCompleto;
    final String nome = (prod['nome'] ?? '').toString().toLowerCase();
    final String un = (prod['unidade'] ?? prod['unidade_medida'] ?? '').toString().trim().toLowerCase();

    final dynamic varPeso = prod['variavel_por_peso'] ?? prod['peso_variavel'] ?? prod['fracionado'] ?? prod['pesavel'];
    if (varPeso == true || varPeso == 1 || varPeso.toString().toLowerCase() == 'true') return true;
    if (['kg', 'quilo', 'quilos', 'g', 'gramas'].contains(un) || un.startsWith('kg')) return true;

    return nome.contains('patinho') || nome.contains('alcatra') || nome.contains('contra') ||
        nome.contains('moída') || nome.contains('carne') || nome.contains('frango') ||
        nome.contains('queijo') || nome.contains('presunto') || nome.contains('banana') ||
        nome.contains('kg');
  }

  bool get _semEstoque {
    final prod = _produtoCompleto;
    final dynamic rawEstoque = prod['estoque'] ?? prod['qtd_estoque'] ?? prod['quantidade_estoque'] ?? prod['saldo_estoque'];
    if (rawEstoque == null) return false;
    final double? estoqueNum = double.tryParse(rawEstoque.toString().replaceAll(',', '.'));
    return estoqueNum != null && estoqueNum <= 0;
  }

  int get _quantidadeNoCarrinho => widget.carrinho[_produtoId] ?? 0;

  void _alterarQuantidade(int novaQuantidade) {
    setState(() {
      if (novaQuantidade <= 0) {
        widget.carrinho.remove(_produtoId);
      } else {
        widget.carrinho[_produtoId] = novaQuantidade;
      }
    });
    widget.onCarrinhoAlterado();
  }

  void _abrirModalPeso() {
    final prod = _produtoCompleto;
    int gramasAtuais = _quantidadeNoCarrinho > 0 ? _quantidadeNoCarrinho : 250;
    double kgInicial = gramasAtuais / 1000.0;

    final TextEditingController pesoController = TextEditingController(
      text: kgInicial.toStringAsFixed(3).replaceAll('.', ','),
    );

    showDialog(
      context: context,
      builder: (modalContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.scale_rounded, color: AppColors.primaria),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Selecionar Peso: ${prod['nome'] ?? ''}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 300,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Informe a quantidade (kg):', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: pesoController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Peso (ex: 0,500 para 500g)', border: OutlineInputBorder(), suffixText: 'kg'),
                    autofocus: true,
                  ),
                  const SizedBox(height: 14),
                  const Text('Sugestões rápidas:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _botaoSugestao('250g', 0.25, pesoController),
                      _botaoSugestao('500g', 0.50, pesoController),
                      _botaoSugestao('1 kg', 1.00, pesoController),
                      _botaoSugestao('1,5 kg', 1.50, pesoController),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(modalContext), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaria, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              onPressed: () {
                final double? pesoKg = double.tryParse(pesoController.text.replaceAll(',', '.'));
                if (pesoKg == null || pesoKg <= 0) return;
                final int gramas = (pesoKg * 1000).round();
                _alterarQuantidade(gramas);
                Navigator.pop(modalContext);
              },
              child: const Text('Confirmar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _botaoSugestao(String texto, double pesoKg, TextEditingController controller) {
    return InkWell(
      onTap: () => controller.text = pesoKg.toStringAsFixed(3).replaceAll('.', ','),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Text(texto, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prod = _produtoCompleto;
    final bool pesavel = _eVariavelPorPeso;
    final bool semEstoque = _semEstoque;
    final String unidadeDisplay = pesavel ? 'kg' : (prod['unidade'] ?? 'un');

    // 🌟 FLAGS
    final dynamic rawMaisVendido = prod['mais_vendido'] ?? prod['is_mais_vendido'] ?? prod['maisVendido'];
    final bool eMaisVendido = rawMaisVendido == true || rawMaisVendido == 1 || rawMaisVendido.toString().toLowerCase() == 'true' || rawMaisVendido.toString() == '1';

    final dynamic rawDestaque = prod['destaque'] ?? prod['is_destaque'] ?? prod['destacado'];
    final bool eDestaque = rawDestaque == true || rawDestaque == 1 || rawDestaque.toString().toLowerCase() == 'true' || rawDestaque.toString() == '1';

    // 🌟 PREÇOS
    final double precoNormal = double.tryParse(prod['preco'].toString().replaceAll(',', '.')) ?? 0.0;

    final dynamic precoClubeRaw = prod['preco_clube'];
    final double precoClube = (precoClubeRaw != null)
        ? (double.tryParse(precoClubeRaw.toString().replaceAll(',', '.')) ?? 0.0)
        : 0.0;

    final bool ehOferta = precoClube > 0 && precoClube < precoNormal;
    final bool eFavorito = widget.favoritosIds.contains(_produtoId);
    final String nomeProduto = prod['nome'] ?? '';

    return GestureDetector(
      onTap: widget.onTapDetalhes,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade200, width: 0.5),
        ),
        child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // --- TOPO: Favorito e Imagem ---
                        Align(
                          alignment: Alignment.topRight,
                          child: GestureDetector(
                            onTap: () => widget.onToggleFavorito(_produtoId),
                            child: Icon(
                              eFavorito ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                              size: 18,
                              color: eFavorito ? Colors.red : Colors.grey.shade400,
                            ),
                          ),
                        ),

                        // 🖼️ Imagem (Encolhe de forma segura)
                        Expanded(
                          flex: 5,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: prod['imagem_url'] != null && prod['imagem_url'].toString().startsWith('http')
                                ? Image.network(
                              prod['imagem_url'],
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Icon(Icons.shopping_bag_outlined, size: 40, color: Colors.grey),
                            )
                                : const Icon(Icons.shopping_bag_outlined, size: 40, color: Colors.grey),
                          ),
                        ),

                        // --- CORPO: Textos e Preços (AGORA MAIORES E LEGÍVEIS) ---
                        Expanded(
                          flex: 7,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                nomeProduto,
                                style: const TextStyle(
                                    fontSize: 14, // 👈 Aumentado
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF333333),
                                    height: 1.1
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 2),

                              const Spacer(),

                              // 💰 Bloco de Preços
                              if (ehOferta) ...[
                                Text(
                                  'R\$ ${precoNormal.toStringAsFixed(2).replaceAll('.', ',')} $unidadeDisplay',
                                  style: const TextStyle(
                                      fontSize: 12, // 👈 Aumentado
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFD32F2F),
                                      decoration: TextDecoration.lineThrough
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Stack(
                                  clipBehavior: Clip.none,
                                  alignment: Alignment.topCenter,
                                  children: [
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.fromLTRB(2, 10, 2, 4), // 👈 Mais padding
                                      decoration: BoxDecoration(color: const Color(0xFFFBC02D), borderRadius: BorderRadius.circular(4)),
                                      child: Column(
                                        children: [
                                          const Text('Cliente APP', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF424242))),
                                          FittedBox( // 👈 Protege texto grande de overflow
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              'R\$ ${precoClube.toStringAsFixed(2).replaceAll('.', ',')}',
                                              style: const TextStyle(
                                                  fontSize: 18, // 👈 Aumentado
                                                  fontWeight: FontWeight.w900,
                                                  color: Color(0xFF333333)
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Positioned(
                                      top: -7,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: const Color(0xFF0D47A1), borderRadius: BorderRadius.circular(4)),
                                        child: const Text('BOX PRIME', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic)),
                                      ),
                                    ),
                                  ],
                                ),
                              ] else ...[
                                FittedBox( // 👈 Protege texto grande de overflow
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'R\$ ${precoNormal.toStringAsFixed(2).replaceAll('.', ',')} $unidadeDisplay',
                                    style: const TextStyle(
                                        fontSize: 17, // 👈 Aumentado
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1E3A8A)
                                    ),
                                  ),
                                ),
                              ],

                              const SizedBox(height: 6),

                              // 🛒 BOTÃO
                              semEstoque
                                  ? Container(
                                width: double.infinity,
                                height: 34, // 👈 Altura Aumentada
                                alignment: Alignment.center,
                                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4)),
                                child: const Text('Indisponível', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54)),
                              )
                                  : _quantidadeNoCarrinho == 0
                                  ? SizedBox(
                                width: double.infinity,
                                height: 34, // 👈 Altura Aumentada
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF00A859),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                    padding: EdgeInsets.zero,
                                  ),
                                  onPressed: () {
                                    if (pesavel) _abrirModalPeso(); else _alterarQuantidade(1);
                                  },
                                  icon: const Icon(Icons.shopping_cart_outlined, size: 16, color: Colors.white),
                                  label: const Text('Adicionar', style: TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.bold)),
                                ),
                              )
                                  : Container(
                                height: 34, // 👈 Altura Aumentada
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFF00A859), width: 1.5),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    IconButton(
                                      padding: EdgeInsets.zero,
                                      icon: const Icon(Icons.remove, size: 18, color: Color(0xFF00A859)),
                                      onPressed: () {
                                        if (pesavel) {
                                          _alterarQuantidade(_quantidadeNoCarrinho > 250 ? _quantidadeNoCarrinho - 250 : 0);
                                        } else {
                                          _alterarQuantidade(_quantidadeNoCarrinho - 1);
                                        }
                                      },
                                    ),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: pesavel ? _abrirModalPeso : null,
                                        child: Center(
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              pesavel ? '${(_quantidadeNoCarrinho / 1000.0).toStringAsFixed(3).replaceAll('.', ',')}kg' : '$_quantidadeNoCarrinho',
                                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      padding: EdgeInsets.zero,
                                      icon: const Icon(Icons.add, size: 18, color: Color(0xFF00A859)),
                                      onPressed: () {
                                        _alterarQuantidade(pesavel ? _quantidadeNoCarrinho + 250 : _quantidadeNoCarrinho + 1);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // SELOS FLUTUANTES
                  if ((eMaisVendido || eDestaque) && !semEstoque)
                    Positioned(
                      top: 0,
                      left: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF57C00),
                          borderRadius: BorderRadius.only(bottomRight: Radius.circular(6)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.local_fire_department_rounded, size: 8, color: Colors.white),
                            const SizedBox(width: 2),
                            Text(eDestaque ? 'DESTAQUE' : 'MAIS VENDIDO', style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.w900)),
                          ],
                        ),
                      ),
                    ),

                  if (pesavel)
                    Positioned(
                      top: 25,
                      right: 4,
                      child: Row(
                        children: [
                          const Icon(Icons.scale_outlined, size: 8, color: Colors.grey),
                          const SizedBox(width: 2),
                          Text('Pode variar', style: TextStyle(fontSize: 7, color: Colors.grey.shade500, fontStyle: FontStyle.italic)),
                        ],
                      ),
                    ),
                ],
              );
            }
        ),
      ),
    );
  }
}