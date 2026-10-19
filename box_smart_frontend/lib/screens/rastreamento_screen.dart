import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class RastreamentoEntregaScreen extends StatefulWidget {
  final int pedidoId;
  final String baseUrl;
  final double destLatitude;  // Latitude do endereço do cliente
  final double destLongitude; // Longitude do endereço do cliente

  const RastreamentoEntregaScreen({
    super.key,
    required this.pedidoId,
    required this.baseUrl,
    required this.destLatitude,
    required this.destLongitude,
  });

  @override
  State<RastreamentoEntregaScreen> createState() => _RastreamentoEntregaScreenState();
}

class _RastreamentoEntregaScreenState extends State<RastreamentoEntregaScreen> {
  GoogleMapController? _mapController;
  Timer? _timerPolling;

  LatLng? _posicaoEntregador;
  String _nomeEntregador = 'Entregador Box Smart';
  String _statusPedido = 'SAIU_PARA_ENTREGA';
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _buscarLocalizacaoEntregador();
    // Consulta a posição do entregador a cada 8 segundos
    _timerPolling = Timer.periodic(const Duration(seconds: 8), (_) {
      _buscarLocalizacaoEntregador();
    });
  }

  @override
  void dispose() {
    _timerPolling?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _buscarLocalizacaoEntregador() async {
    try {
      final response = await http.get(
        Uri.parse('${widget.baseUrl}/pedidos/${widget.pedidoId}/localizacao'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _statusPedido = (data['status'] ?? '').toString().toUpperCase();

        if (data['latitude'] != null && data['longitude'] != null) {
          final novaPosicao = LatLng(
            double.parse(data['latitude'].toString()),
            double.parse(data['longitude'].toString()),
          );

          setState(() {
            _posicaoEntregador = novaPosicao;
            _nomeEntregador = data['entregador_nome'] ?? 'Entregador';
            _carregando = false;
          });

          // Move suavemente a câmera para acompanhar o entregador
          _mapController?.animateCamera(
            CameraUpdate.newLatLng(novaPosicao),
          );
        }
      }
    } catch (e) {
      debugPrint('Erro ao obter localização: $e');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final LatLng destino = LatLng(widget.destLatitude, widget.destLongitude);

    final Set<Marker> markers = {
      // Marcador da Casa/Endereço do Cliente
      Marker(
        markerId: const MarkerId('destino'),
        position: destino,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: const InfoWindow(title: 'Seu Endereço de Entrega'),
      ),
    };

    // Marcador do Entregador
    if (_posicaoEntregador != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('entregador'),
          position: _posicaoEntregador!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: InfoWindow(title: _nomeEntregador, snippet: 'A caminho!'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Acompanhar Pedido #${widget.pedidoId}'),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _posicaoEntregador ?? destino,
              zoom: 15,
            ),
            markers: markers,
            onMapCreated: (controller) => _mapController = controller,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),

          if (_carregando)
            const Center(child: CircularProgressIndicator()),

          // Card de Informações no Rodapé
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: const Color(0xFFEFF6FF),
                    radius: 24,
                    child: const Icon(Icons.two_wheeler, color: Color(0xFF2563EB), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _nomeEntregador,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _posicaoEntregador != null
                              ? 'Entregador em deslocamento...'
                              : 'Aguardando sinal GPS do entregador...',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        ),
                      ],
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
}