import 'package:box_smart_frontend/screens/painel/separacao_checklist_screen.dart';
import 'package:flutter/material.dart';
import 'admin_dashboard_screen.dart';
import 'admin_metrics_tab.dart';
import 'admin_pedidos_screen.dart';
import 'fila_pedidos_separador_screen.dart';
import 'gerenciar_pedidos_tab.dart';
import 'gerenciar_produtos_tab.dart';
import 'gerenciar_categorias_tab.dart';
import 'gerenciar_subcategorias_tab.dart';
import 'gerenciar_banners_tab.dart';
import 'gerenciar_secoes_tab.dart';
import 'box_prime_admin_screen.dart';
import 'gerenciar_notificacoes_tab.dart';
import 'entregador_screen.dart';
import 'gerenciar_usuarios_tab.dart';

class AdminPortalScreen extends StatefulWidget {
  final String token;
  final String baseUrl;

  const AdminPortalScreen({
    super.key,
    required this.token,
    required this.baseUrl,
  });

  @override
  State<AdminPortalScreen> createState() => _AdminPortalScreenState();
}

class _AdminPortalScreenState extends State<AdminPortalScreen> {
  int _indiceSelecionado = 0;
  late final List<Widget> _telas;

  @override
  void initState() {
    super.initState();
    // ✅ Lista completa de telas integradas no portal web
    _telas = [
      AdminDashboardScreen(
        baseUrl: 'http://192.168.15.175:8000',
        token: widget.token,
      ),
      AdminPedidosScreen(
        baseUrl: 'http://192.168.15.175:8000',
        token: widget.token,
      ),
      // 📦 Módulo Operacional: Separação
      FilaPedidosSeparadorScreen(
        baseUrl: 'http://192.168.15.175:8000',
        token: widget.token,
      ),
      // 🚚 Módulo Logístico: Entregas
      EntregadorScreen(
        baseUrl: 'http://192.168.15.175:8000',
        token: widget.token,
      ),
      GerenciarProdutosTab(
        baseUrl: 'http://192.168.15.175:8000',
        token: widget.token,
      ),
      GerenciarCategoriasTab(
        baseUrl: 'http://192.168.15.175:8000',
        token: widget.token,
      ),
      GerenciarSubcategoriasTab(
        baseUrl: 'http://192.168.15.175:8000',
        token: widget.token,
      ),
      GerenciarBannersTab(
        baseUrl: 'http://192.168.15.175:8000',
        token: widget.token,
      ),
      GerenciarSecoesTab(
        baseUrl: 'http://192.168.15.175:8000',
        token: widget.token,
      ),
      BoxPrimeAdminScreen(
        baseUrl: 'http://192.168.15.175:8000',
        token: widget.token,
      ),
      // 📢 Campanhas e Notificações (Rota POST que criamos)
      GerenciarNotificacoesTab(
        baseUrl: 'http://192.168.15.175:8000',
        token: widget.token,
      ),
      GerenciarUsuariosTab(
        baseUrl: 'http://192.168.15.175:8000',
        token: widget.token,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize
              .min, // 🌟 Faz a Row ocupar apenas o espaço necessário
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A8A).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.storefront,
                color: Color(0xFF1E3A8A),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Flexible(
              // 🌟 Usamos Flexible em vez de Expanded para evitar o erro de Layout
              child: Text(
                'Box Smart | Painel Administrativo e Operacional',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF1E293B),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.shade200, height: 1),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 16,
                  backgroundColor: Color(0xFF1E3A8A),
                  child: Text(
                    'BS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Gestor Principal',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      'Administrador',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          Container(
            decoration: const BoxDecoration(color: Color(0xFF0F172A)),
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height,
                ),
                child: IntrinsicHeight(
                  child: NavigationRail(
                    backgroundColor: Colors.transparent,
                    minWidth: 100,
                    indicatorColor: Colors.transparent,
                    selectedIndex: _indiceSelecionado,
                    onDestinationSelected: (int index) {
                      setState(() {
                        _indiceSelecionado = index;
                      });
                    },
                    labelType: NavigationRailLabelType.all,
                    selectedIconTheme: const IconThemeData(
                      color: Colors.white,
                      size: 24,
                    ),
                    unselectedIconTheme: const IconThemeData(
                      color: Color(0xFF94A3B8),
                      size: 22,
                    ),
                    selectedLabelTextStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                    unselectedLabelTextStyle: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                    destinations: const [
                      NavigationRailDestination(
                        icon: Icon(Icons.insert_chart_outlined),
                        selectedIcon: Icon(Icons.insert_chart),
                        label: Text('Métricas'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.receipt_long_outlined),
                        selectedIcon: Icon(Icons.receipt_long),
                        label: Text('Pedidos'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.inventory_outlined),
                        selectedIcon: Icon(Icons.inventory),
                        label: Text('Separação'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.delivery_dining_outlined),
                        selectedIcon: Icon(Icons.delivery_dining),
                        label: Text('Entregas'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.inventory_2_outlined),
                        selectedIcon: Icon(Icons.inventory_2),
                        label: Text('Produtos'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.category_outlined),
                        selectedIcon: Icon(Icons.category),
                        label: Text('Categorias'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.subdirectory_arrow_right_outlined),
                        selectedIcon: Icon(Icons.subdirectory_arrow_right),
                        label: Text('Subcategorias'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.view_carousel_outlined),
                        selectedIcon: Icon(Icons.view_carousel),
                        label: Text('Banners'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.dashboard_outlined),
                        selectedIcon: Icon(Icons.dashboard),
                        label: Text('Seções'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.star_outline_rounded),
                        selectedIcon: Icon(Icons.star_rounded),
                        label: Text('Box Prime'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.campaign_outlined),
                        selectedIcon: Icon(Icons.campaign),
                        label: Text('Campanhas'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.person_3_outlined),
                        selectedIcon: Icon(Icons.person_3),
                        label: Text('Perfis'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.01),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _telas[_indiceSelecionado],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
