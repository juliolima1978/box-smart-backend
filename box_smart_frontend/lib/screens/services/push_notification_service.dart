import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// Handler para notificações em background
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("Notificação recebida em background: ${message.messageId}");
}

class PushNotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  Future<void> inicializar(String userTokenAuth, String baseUrl) async {
    // 1. Solicita permissão no iOS/Android 13+
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // 2. Configura notificações locais para exibição em Foreground (App aberto)
      const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const InitializationSettings initSettings = InitializationSettings(android: androidSettings);
      await _localNotifications.initialize(initSettings);

      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Listener para foreground
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        RemoteNotification? notification = message.notification;
        AndroidNotification? android = message.notification?.android;

        if (notification != null && android != null) {
          _localNotifications.show(
            notification.hashCode,
            notification.title,
            notification.body,
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'channel_pedidos',
                'Status dos Pedidos',
                channelDescription: 'Notificações de atualização de pedidos',
                importance: Importance.max,
                priority: Priority.high,
                icon: '@mipmap/ic_launcher',
              ),
            ),
          );
        }
      });

      // 3. Captura e envia o Token do dispositivo ao Backend
      String? fcmToken = await _fcm.getToken();
      if (fcmToken != null) {
        await _enviarTokenParaBackend(fcmToken, userTokenAuth, baseUrl);
      }

      // Atualiza caso o token seja renovado
      _fcm.onTokenRefresh.listen((novoToken) {
        _enviarTokenParaBackend(novoToken, userTokenAuth, baseUrl);
      });
    }
  }

  Future<void> _enviarTokenParaBackend(String fcmToken, String userTokenAuth, String baseUrl) async {
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
      print("Erro ao registrar FCM token no backend: $e");
    }
  }
}