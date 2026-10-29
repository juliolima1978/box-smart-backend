import 'package:box_smart_frontend/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:box_smart_frontend/screens/painel/admin_portal_screen.dart';
import 'package:box_smart_frontend/screens/historico_pedidos_screen.dart';
import 'package:box_smart_frontend/screens/painel/login_admin_screen.dart';
import 'admin_screen.dart';
import 'auth_screen.dart';
import 'services/session_service.dart';

// Top-level handler para processar notificações com o app em background ou fechado
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() async {
  // Garante a inicialização dos bindings do Flutter e do Firebase
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Verifica se já tem uma sessão salva antes de ligar o app
  final sessao = await SessionService.carregarSessao();
  final String? tokenSalvo = sessao['token'];
  final int clienteIdSalvo = sessao['clienteId'] ?? 0;
  final String clienteNomeSalvo = sessao['clienteNome'] ?? 'Cliente';

  final bool temSessaoValida = tokenSalvo != null && tokenSalvo.trim().isNotEmpty;

  // 🌟 INICIALIZA O PUSH NOTIFICATION IMEDIATAMENTE SE O USUÁRIO JÁ ESTIVER LOGADO
  if (temSessaoValida) {
    const String baseUrl = "https://box-smart-backend.onrender.com";
    PushNotificationService.inicializar(tokenSalvo, baseUrl);
  }

  // Passa as informações de login para dentro do App
  runApp(BoxSmartApp(
    logado: temSessaoValida,
    clienteId: clienteIdSalvo,
    clienteNome: clienteNomeSalvo,
    token: tokenSalvo ?? '',
  ));
}

// ==========================================
// SERVIÇO DE NOTIFICAÇÕES PUSH (FCM)
// ==========================================
class PushNotificationService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
  FlutterLocalNotificationsPlugin();

  static Future<void> inicializar(String userTokenAuth, String baseUrl) async {
    // 1. Solicita permissão de notificação no dispositivo
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // 2. Configura o plugin de notificações locais para exibir banners quando o app está aberto
      const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');
      const InitializationSettings initSettings =
      InitializationSettings(android: androidSettings);

      await _localNotifications.initialize(initSettings);

      // 🌟 REGISTRA O CANAL NO ANDROID PARA EXIBIR OS BANNERS COM ALTA IMPORTÂNCIA
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'channel_pedidos',
        'Status dos Pedidos',
        description: 'Notificações de atualização de pedidos do Box Smart',
        importance: Importance.max,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Listener para mensagens recebidas com o app em primeiro plano (Foreground)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        RemoteNotification? notification = message.notification;
        AndroidNotification? android = message.notification?.android;

        if (notification != null && android != null) {
          _localNotifications.show(
            notification.hashCode,
            notification.title,
            notification.body,
            NotificationDetails(
              android: AndroidNotificationDetails(
                channel.id,
                channel.name,
                channelDescription: channel.description,
                importance: Importance.max,
                priority: Priority.high,
                icon: '@mipmap/ic_launcher',
              ),
            ),
          );
        }
      });

      // 3. Obtém o token FCM e envia ao servidor
      try {
        String? fcmToken = await _fcm.getToken();
        if (fcmToken != null) {
          await registrarTokenNoBackend(fcmToken, userTokenAuth, baseUrl);
        }
      } catch (e) {
        debugPrint(
            "Aviso: Não foi possível obter o token FCM (Dispositivo offline ou sem Play Services): $e");
      }

      // Atualiza o registro caso o token seja renovado
      _fcm.onTokenRefresh.listen((novoToken) {
        registrarTokenNoBackend(novoToken, userTokenAuth, baseUrl);
      });
    }
  }

  static Future<void> registrarTokenNoBackend(
      String fcmToken, String userTokenAuth, String baseUrl) async {
    try {
      await http.patch(
        Uri.parse('$baseUrl/clientes/fcm-token/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $userTokenAuth',
        },
        body: jsonEncode({'fcm_token': fcmToken}),
      );
    } catch (e) {
      debugPrint("Erro ao enviar FCM token para o backend: $e");
    }
  }
}

// ==========================================
// CONFIGURAÇÃO DE CORES E TEMA
// ==========================================
class AppColors {
  static const Color primaria = Color(0xFF2E7D32); // Verde Esmeralda Forte
  static const Color primariaClara = Color(0xFF81C784);
  static const Color primariaMuitoClara = Color(0xFFE8F5E9);
  static const Color destaque = Color(0xFFda251c);
  static const Color fundo = Color(0xFFFFFFFF);
  static const Color textoPrincipal = Color(0xFF212121);
  static const Color textoSecundario = Color(0xFF757575);
}

class BoxSmartApp extends StatelessWidget {
  final bool logado;
  final int clienteId;
  final String clienteNome;
  final String token;

  const BoxSmartApp({
    super.key,
    required this.logado,
    required this.clienteId,
    required this.clienteNome,
    required this.token,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Box Smart - Supermercado',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E3A8A),
          background: const Color(0xFFF8FAFC),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200, width: 1),
          ),
        ),
      ),
      home: logado
          ? HomeScreen(
        clienteId: clienteId,
        clienteNome: clienteNome,
        token: token,
      )
          : const AuthScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// ==========================================
// OUTRAS TELAS (CatalogScreen, ProfileScreen, etc.)
// ==========================================
class CatalogScreen extends StatefulWidget {
  final String token;
  final int clienteId;
  const CatalogScreen({
    super.key,
    required this.token,
    required this.clienteId,
  });

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final List<Map<String, dynamic>> _produtos = [
    {
      'nome': 'Arroz Premium 5kg',
      'preco': '28,90',
      'clube': '24,90',
      'categoria': 'Mercearia',
      'icone': Icons.rice_bowl_rounded,
    },
    {
      'nome': 'Feijão Carioca 1kg',
      'preco': '8,50',
      'clube': '6,99',
      'categoria': 'Mercearia',
      'icone': Icons.set_meal_rounded,
    },
    {
      'nome': 'Leite Integral 1L',
      'preco': '5,20',
      'clube': '4,50',
      'categoria': 'Laticínios',
      'icone': Icons.local_drink_rounded,
    },
    {
      'nome': 'Café Extra Forte 500g',
      'preco': '18,90',
      'clube': '15,90',
      'categoria': 'Bebidas',
      'icone': Icons.coffee_rounded,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fundo,
      appBar: AppBar(
        title: const Text(
          'Catálogo de Produtos',
          style: TextStyle(
            color: AppColors.textoPrincipal,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _produtos.length,
        itemBuilder: (context, index) {
          final prod = _produtos[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: Icon(prod['icone'], color: AppColors.primaria, size: 36),
              title: Text(
                prod['nome'],
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                'R\$ ${prod['clube']} (Clube Box Smart)',
                style: TextStyle(
                  color: AppColors.primaria,
                  fontWeight: FontWeight.w600,
                ),
              ),
              trailing: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaria,
                ),
                onPressed: () {},
                child: const Text(
                  'Comprar',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  final int clienteId;
  final String token;

  const ProfileScreen({
    super.key,
    required this.clienteId,
    required this.token,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _carregando = true;
  Map<String, dynamic> _dadosCliente = {};
  final String baseUrl = "https://box-smart-backend.onrender.com";

  @override
  void initState() {
    super.initState();
    _buscarDadosPerfil();
    PushNotificationService.inicializar(widget.token, baseUrl);
  }

  Future<void> _buscarDadosPerfil() async {
    setState(() => _carregando = true);
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/clientes/${widget.clienteId}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
      );

      if (response.statusCode == 200) {
        final decodedData = jsonDecode(response.body);
        setState(() {
          _dadosCliente = Map<String, dynamic>.from(decodedData);
        });
      } else {
        final listaResponse = await http.get(Uri.parse('$baseUrl/clientes/'));
        if (listaResponse.statusCode == 200) {
          List clientes = jsonDecode(listaResponse.body);
          var cliente = clientes.firstWhere(
                (c) => c['id'] == widget.clienteId,
            orElse: () => {},
          );
          setState(() {
            _dadosCliente = Map<String, dynamic>.from(cliente);
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Erro ao carregar perfil: $e'),
            backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) {
        setState(() => _carregando = false);
      }
    }
  }

  void _sairDaConta() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const AuthScreen()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Meu Perfil',
            style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border:
                      Border.all(color: AppColors.primaria, width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 45,
                      backgroundColor: Colors.green.shade50,
                      child: Text(
                        (_dadosCliente['nome'] != null &&
                            _dadosCliente['nome']
                                .toString()
                                .isNotEmpty)
                            ? _dadosCliente['nome']
                            .toString()
                            .substring(0, 1)
                            .toUpperCase()
                            : 'C',
                        style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaria),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _dadosCliente['nome'] ?? 'Cliente Box Smart',
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.black87),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _dadosCliente['email'] ?? 'email@exemplo.com',
                    style: TextStyle(
                        fontSize: 14, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildProfileItem(
                    icon: Icons.person_outline_rounded,
                    title: 'Nome Completo',
                    subtitle: _dadosCliente['nome'] ?? 'Não informado',
                  ),
                  const Divider(height: 1, indent: 54),
                  _buildProfileItem(
                    icon: Icons.email_outlined,
                    title: 'E-mail',
                    subtitle: _dadosCliente['email'] ?? 'Não informado',
                  ),
                  const Divider(height: 1, indent: 54),
                  _buildProfileItem(
                    icon: Icons.phone_outlined,
                    title: 'Telefone / WhatsApp',
                    subtitle: _dadosCliente['telefone'] ?? 'Não informado',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.receipt_long_rounded,
                          color: AppColors.primaria, size: 20),
                    ),
                    title: const Text('Histórico de Pedidos',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87)),
                    subtitle: Text('Acompanhe suas compras anteriores',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade500)),
                    trailing: const Icon(Icons.chevron_right_rounded,
                        color: Colors.grey),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MeusPedidosScreen(
                            clienteId: widget.clienteId,
                            token: widget.token,
                            baseUrl: baseUrl,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.card_membership_rounded,
                          color: Colors.amber, size: 20),
                    ),
                    title: const Text('Clube Box Prime',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87)),
                    subtitle: const Text('Ativo - Economia garantida',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey)),
                    trailing: const Icon(Icons.chevron_right_rounded,
                        color: Colors.grey),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'Você já aproveita os benefícios do Box Prime!'),
                            behavior: SnackBarBehavior.floating),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(
                      color: Colors.redAccent, width: 1.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _sairDaConta,
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text(
                  'Sair da Conta',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileItem(
      {required IconData icon,
        required String title,
        required String subtitle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primaria, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class NotificationsScreen extends StatelessWidget {
  final int clienteId;
  const NotificationsScreen({super.key, required this.clienteId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fundo,
      appBar: AppBar(title: const Text('Notificações')),
      body: const Center(child: Text('Nenhuma notificação no momento.')),
    );
  }
}