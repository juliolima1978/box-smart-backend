import 'package:box_smart_portal/relatorio_curva_abc_tab.dart';
import 'package:box_smart_portal/relatorio_recorrencia_tab.dart';
import 'package:box_smart_portal/separacao_checklist_screen.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'admin_dashboard_screen.dart';
import 'admin_pedidos_screen.dart';
import 'admin_frete_screen.dart'; // 🌟 Import da tela de Gestão de Frete
import 'fila_pedidos_separador_screen.dart';
import 'gerenciar_produtos_tab.dart';
import 'gerenciar_categorias_tab.dart';
import 'gerenciar_subcategorias_tab.dart';
import 'gerenciar_banners_tab.dart';
import 'gerenciar_secoes_tab.dart';
import 'box_prime_admin_screen.dart';
import 'gerenciar_notificacoes_tab.dart';
import 'entregador_screen.dart';
import 'gerenciar_usuarios_tab.dart';
import 'login_admin_screen.dart';
import 'relatorio_vendas_bairro_tab.dart';

class MenuItemPortal {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget tela;
  final List<String> perfisPermitidos;

  MenuItemPortal({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.tela,
    required this.perfisPermitidos,
  });
}

class AdminPortalScreen extends StatefulWidget {
  final String token;
  final String baseUrl;
  final String nomeUsuario;

  const AdminPortalScreen({
    super.key,
    required this.token,
    required this.baseUrl,
    this.nomeUsuario = 'Gestor',
  });

  @override
  State<AdminPortalScreen> createState() => _AdminPortalScreenState();
}

class _AdminPortalScreenState extends State<AdminPortalScreen> {
  int _indiceSelecionado = 0;
  List<MenuItemPortal> _menuFiltrado = [];

  String _nomeGestor = 'Usuário';
  String _cargoGestor = 'separador';
  String _iniciais = 'BS';

  @override
  void initState() {
    super.initState();
    _carregarDadosERegistrarMenus();
  }

  Future<void> _carregarDadosERegistrarMenus() async {
    final prefs = await SharedPreferences.getInstance();
    final nome = prefs.getString('user_nome') ?? prefs.getString('nome') ?? 'Usuário Operacional';
    final cargo = (prefs.getString('user_perfil') ?? prefs.getString('perfil') ?? 'separador').toLowerCase();

    final todosOsMenus = [
      MenuItemPortal(
        label: 'Métricas',
        icon: Icons.insert_chart_outlined,
        selectedIcon: Icons.insert_chart,
        tela: AdminDashboardScreen(baseUrl: widget.baseUrl, token: widget.token),
        perfisPermitidos: ['admin', 'gestor'],
      ),
      MenuItemPortal(
        label: 'Pedidos',
        icon: Icons.receipt_long_outlined,
        selectedIcon: Icons.receipt_long,
        tela: AdminPedidosScreen(baseUrl: widget.baseUrl, token: widget.token),
        perfisPermitidos: ['admin', 'gestor'],
      ),
      // 🌟 NOVO MENU: Gestão de Taxa de Entrega e Promoções de Frete
      MenuItemPortal(
        label: 'Taxa & Frete',
        icon: Icons.local_shipping_outlined,
        selectedIcon: Icons.local_shipping,
        tela: AdminFreteScreen(baseUrl: widget.baseUrl, token: widget.token),
        perfisPermitidos: ['admin', 'gestor'],
      ),
      MenuItemPortal(
        label: 'Separação',
        icon: Icons.inventory_outlined,
        selectedIcon: Icons.inventory,
        tela: FilaPedidosSeparadorScreen(
          baseUrl: widget.baseUrl,
          token: widget.token,
          nomeSeparador: nome,
        ),
        perfisPermitidos: ['admin', 'gestor', 'separador'],
      ),
      MenuItemPortal(
        label: 'Entregas',
        icon: Icons.delivery_dining_outlined,
        selectedIcon: Icons.delivery_dining,
        tela: EntregadorScreen(baseUrl: widget.baseUrl, token: widget.token),
        perfisPermitidos: ['admin', 'gestor', 'entregador'],
      ),
      MenuItemPortal(
        label: 'Produtos',
        icon: Icons.inventory_2_outlined,
        selectedIcon: Icons.inventory_2,
        tela: GerenciarProdutosTab(baseUrl: widget.baseUrl, token: widget.token),
        perfisPermitidos: ['admin', 'gestor'],
      ),
      MenuItemPortal(
        label: 'Categorias',
        icon: Icons.category_outlined,
        selectedIcon: Icons.category,
        tela: GerenciarCategoriasTab(baseUrl: widget.baseUrl, token: widget.token),
        perfisPermitidos: ['admin', 'gestor'],
      ),
      MenuItemPortal(
        label: 'Subcategorias',
        icon: Icons.subdirectory_arrow_right_outlined,
        selectedIcon: Icons.subdirectory_arrow_right,
        tela: GerenciarSubcategoriasTab(baseUrl: widget.baseUrl, token: widget.token),
        perfisPermitidos: ['admin', 'gestor'],
      ),
      MenuItemPortal(
        label: 'Banners',
        icon: Icons.view_carousel_outlined,
        selectedIcon: Icons.view_carousel,
        tela: GerenciarBannersTab(baseUrl: widget.baseUrl, token: widget.token),
        perfisPermitidos: ['admin', 'gestor'],
      ),
      MenuItemPortal(
        label: 'Seções',
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard,
        tela: GerenciarSecoesTab(baseUrl: widget.baseUrl, token: widget.token),
        perfisPermitidos: ['admin', 'gestor'],
      ),
      MenuItemPortal(
        label: 'Vendas p/ Bairro',
        icon: Icons.map_outlined,
        selectedIcon: Icons.map,
        tela: RelatorioVendasBairroTab(baseUrl: widget.baseUrl, token: widget.token),
        perfisPermitidos: ['admin', 'gestor'],
      ),
      MenuItemPortal(
        label: 'Retenção',
        icon: Icons.repeat_outlined,
        selectedIcon: Icons.repeat_rounded,
        tela: RelatorioRecorrenciaTab(baseUrl: widget.baseUrl, token: widget.token),
        perfisPermitidos: ['admin', 'gestor'],
      ),
      MenuItemPortal(
        label: 'Curva ABC',
        icon: Icons.pie_chart_outline_rounded,
        selectedIcon: Icons.pie_chart_rounded,
        tela: RelatorioCurvaAbcTab(baseUrl: widget.baseUrl, token: widget.token),
        perfisPermitidos: ['admin', 'gestor'],
      ),
      MenuItemPortal(
        label: 'Box Prime',
        icon: Icons.star_outline_rounded,
        selectedIcon: Icons.star_rounded,
        tela: BoxPrimeAdminScreen(baseUrl: widget.baseUrl, token: widget.token),
        perfisPermitidos: ['admin', 'gestor'],
      ),
      MenuItemPortal(
        label: 'Campanhas',
        icon: Icons.campaign_outlined,
        selectedIcon: Icons.campaign,
        tela: GerenciarNotificacoesTab(baseUrl: widget.baseUrl, token: widget.token),
        perfisPermitidos: ['admin', 'gestor'],
      ),
      MenuItemPortal(
        label: 'Perfis',
        icon: Icons.person_3_outlined,
        selectedIcon: Icons.person_3,
        tela: GerenciarUsuariosTab(baseUrl: widget.baseUrl, token: widget.token),
        perfisPermitidos: ['admin', 'gestor'],
      ),
    ];

    final menuFiltrado = todosOsMenus.where((item) {
      if (cargo == 'admin' || cargo == 'gestor') return true;
      return item.perfisPermitidos.contains(cargo);
    }).toList();

    String iniciais = 'BS';
    if (nome.isNotEmpty && nome != 'Usuário') {
      List<String> partes = nome.trim().split(' ');
      if (partes.length > 1) {
        iniciais = '${partes[0][0]}${partes[1][0]}'.toUpperCase();
      } else if (partes.isNotEmpty) {
        iniciais = partes[0].substring(0, partes[0].length >= 2 ? 2 : 1).toUpperCase();
      }
    }

    if (!mounted) return;
    setState(() {
      _nomeGestor = nome;
      _cargoGestor = cargo;
      _iniciais = iniciais;
      _menuFiltrado = menuFiltrado;
      _indiceSelecionado = 0;
    });
  }

  Future<void> _fazerLogout() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Colors.redAccent),
            SizedBox(width: 10),
            Text('Sair do Sistema'),
          ],
        ),
        content: const Text('Deseja realmente encerrar sua sessão no painel?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sair', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => LoginAdminScreen(baseUrl: widget.baseUrl),
        ),
            (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_menuFiltrado.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Define que telas com menos de 800px de largura são mobile
        final isMobile = constraints.maxWidth < 800;

        // Cabeçalho unificado para as duas versões (com AppBar nativo para Mobile)
        final appBar = AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
          shadowColor: Colors.black12,
          iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  isMobile ? 'Painel Gestor' : 'Painel Operacional',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Color(0xFF1E293B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!isMobile) const SizedBox(width: 12),
              if (!isMobile)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Box Smart Management',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                  ),
                ),
            ],
          ),
          actions: [
            if (!isMobile)
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFF1E3A8A),
                    child: Text(_iniciais, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_nomeGestor, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B))),
                      Text(_cargoGestor.toUpperCase(), style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(width: 16),
                  const SizedBox(height: 24, child: VerticalDivider(color: Color(0xFFCBD5E1), width: 1)),
                ],
              ),
            IconButton(
              icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 22),
              tooltip: 'Sair do Sistema',
              onPressed: _fazerLogout,
            ),
            const SizedBox(width: 8),
          ],
        );

        // O Menu Lateral (NavigationRail) extraído como widget
        Widget buildMenuLateral() {
          return Container(
            width: 110,
            decoration: const BoxDecoration(color: Color(0xFF0F172A)),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E3A8A),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.storefront, color: Colors.white, size: 24),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'BOX SMART',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1.2),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Color(0xFF334155), height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    child: IntrinsicHeight(
                      child: NavigationRail(
                        backgroundColor: Colors.transparent,
                        minWidth: 110,
                        indicatorColor: const Color(0xFF1E3A8A).withOpacity(0.5),
                        selectedIndex: _indiceSelecionado,
                        onDestinationSelected: (int index) {
                          setState(() => _indiceSelecionado = index);
                          if (isMobile) Navigator.pop(context); // Fecha o drawer no celular ao clicar
                        },
                        labelType: NavigationRailLabelType.all,
                        selectedIconTheme: const IconThemeData(color: Colors.white, size: 24),
                        unselectedIconTheme: const IconThemeData(color: Color(0xFF94A3B8), size: 22),
                        selectedLabelTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11),
                        unselectedLabelTextStyle: const TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w500, fontSize: 11),
                        destinations: _menuFiltrado.map((item) {
                          return NavigationRailDestination(
                            icon: Icon(item.icon),
                            selectedIcon: Icon(item.selectedIcon),
                            label: Text(item.label),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // Conteúdo central da tela (A Aba que foi clicada)
        Widget buildConteudoAtivo() {
          return Container(
            margin: EdgeInsets.all(isMobile ? 10 : 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: _menuFiltrado[_indiceSelecionado].tela,
            ),
          );
        }

        // Retorna a estrutura com base no dispositivo
        if (isMobile) {
          return Scaffold(
            backgroundColor: const Color(0xFFF8FAFC),
            appBar: appBar,
            drawer: Drawer(
              child: buildMenuLateral(), // Menu no Drawer deslizante!
            ),
            body: buildConteudoAtivo(),
          );
        }

        // Layout original para Computador/Tablet
        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: Row(
            children: [
              buildMenuLateral(),
              Expanded(
                child: Column(
                  children: [
                    SizedBox(height: 65, child: appBar),
                    Expanded(child: buildConteudoAtivo()),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}