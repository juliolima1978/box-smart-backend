// lib/widgets/footer_widget.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart'; // Para acessar AppColors

class FooterWidget extends StatelessWidget {
  const FooterWidget({super.key});

  Future<void> _abrirUrl(String urlStr) async {
    final uri = Uri.parse(urlStr);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primaria,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // --- LOGO E SLOGAN ---
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.store_mall_directory_rounded, color: Colors.white, size: 32),
              SizedBox(width: 8),
              Text(
                'Supermercado Tescarollo',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Descubra o frescor de cada dia',
            style: TextStyle(color: Colors.white70, fontSize: 13, fontStyle: FontStyle.italic),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // --- REDES SOCIAIS ---
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildSocialIcon(Icons.camera_alt, () => _abrirUrl('https://instagram.com')),
              const SizedBox(width: 12),
              _buildSocialIcon(Icons.play_arrow_rounded, () => _abrirUrl('https://youtube.com')),
              const SizedBox(width: 12),
              _buildSocialIcon(Icons.facebook, () => _abrirUrl('https://facebook.com')),
              const SizedBox(width: 12),
              _buildSocialIcon(Icons.chat, () => _abrirUrl('https://wa.me/5511932020223')),
            ],
          ),
          const SizedBox(height: 32),

          // --- SEÇÃO: BAIXE NOSSO APLICATIVO ---
          const Text(
            'Baixe nosso aplicativo',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Escolha a loja de aplicativos do seu dispositivo abaixo',
            style: TextStyle(color: Colors.white60, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              bool isDesktop = constraints.maxWidth > 600;
              Widget botoesLojas = Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildStoreButton('DISPONÍVEL NA', 'Google Play', Icons.play_arrow_rounded, () {}),
                  const SizedBox(width: 12),
                  _buildStoreButton('DISPONÍVEL NA', 'App Store', Icons.apple, () {}),
                ],
              );
              return isDesktop ? SizedBox(width: 450, child: botoesLojas) : botoesLojas;
            },
          ),
          const SizedBox(height: 32),
          const Divider(color: Colors.white24, thickness: 1),
          const SizedBox(height: 20),

          // --- LINKS DE ATENDIMENTO E SUPORTE ---
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 20,
            runSpacing: 10,
            children: [
              _buildLinkAtendimento('Contato', () => _abrirUrl('https://wa.me/5511932020223')),
              _buildLinkAtendimento('Atendimento ao titular LGPD', () {}),
              _buildLinkAtendimento('Perguntas Frequentes', () {}),
              _buildLinkAtendimento('Política de Privacidade', () {}),
            ],
          ),
          const SizedBox(height: 24),

          // --- COPYRIGHT E PAGAMENTOS ---
          const Text(
            '© 2026 MGBE Tecnologia e sistemas. Todos os direitos reservados.',
            style: TextStyle(color: Colors.white60, fontSize: 11),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Formas de pagamento: Visa, MasterCard, Elo, Pix',
            style: TextStyle(color: Colors.white54, fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSocialIcon(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildStoreButton(String subtitle, String title, IconData icon, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white30),
            color: Colors.white.withOpacity(0.05),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 26, color: Colors.white),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(subtitle, style: const TextStyle(fontSize: 8, color: Colors.white60, fontWeight: FontWeight.bold)),
                  Text(title, style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLinkAtendimento(String texto, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Text(
        texto,
        style: const TextStyle(color: Colors.white70, fontSize: 12, decoration: TextDecoration.underline),
      ),
    );
  }
}