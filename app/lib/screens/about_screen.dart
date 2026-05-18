import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../services/analytics_service.dart';
import '../services/background_location_service.dart';
import '../services/local_notification_service.dart';

/// Tela /sobre/ — transparência editorial pública.
///
/// Lista fontes de dados, princípios e contato. Acessível pela tela de
/// ajuda. Mantém o tom editorial: honesta sobre limitações.
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logScreen('about');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sobre o Faro', style: TextStyle(fontFamily: 'Georgia')),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          const _BackgroundAlertsToggle(),
          const SizedBox(height: 18),
          const _Section(
            title: 'O que somos',
            body:
                'Um assistente de decisão urbana em tempo real. Mostramos o que está acontecendo perto de você combinando fontes públicas e (futuramente) relatos de usuários. Não somos um mapa de crimes. Não substituímos sua atenção.',
          ),
          const _Section(
            title: 'O que não somos',
            body:
                'Não somos um produto de garantia. Nunca dizemos "está seguro". A única mensagem possível em uma região sem relatos é "sem relatos recentes" — silêncio nos dados não é silêncio nas ruas. Mantenha atenção sempre.',
          ),
          const _Section(
            title: 'Fontes de dados',
            body:
                'Hoje: Fogo Cruzado (banco público de violência armada — RJ, PE, BA, PA). Próximas: relatos de usuários com validação coletiva, scraping de portais locais de notícia, monitoramento de canais públicos do Telegram. Cada fonte com peso diferente no cálculo de risco.',
          ),
          const _Section(
            title: 'Como classificamos o risco',
            body:
                'Combinamos peso da fonte, idade do relato e densidade de confirmações. Reportes antigos perdem peso automaticamente. Múltiplas fontes independentes corroborando elevam o nível. Uma única fonte isolada nunca sustenta classificação alta.',
          ),
          const _Section(
            title: 'Sobre viés algorítmico',
            body:
                'Periferias têm mais policiamento e mais cobertura de mídia — não necessariamente mais crime real. Mais boletins em uma região indicam mais visibilidade, não mais risco. Quando não temos dados suficientes em uma área, dizemos isso explicitamente, em vez de assumir que é seguro.',
          ),
          const _Section(
            title: 'Densidade populacional (em construção)',
            body:
                'Quando exibimos "relatos por 10 mil habitantes" em um bairro, usamos população do Censo IBGE 2010 (via PMS/SEMOP), porque o Censo 2022 ainda não publicou agregação por bairro para Salvador. Bairros sem dado de população não mostram normalização — preferimos silêncio honesto a número inventado.',
          ),
          const _Section(
            title: 'Privacidade',
            body:
                'Sua localização é usada apenas para mostrar relatos próximos. Não armazenamos seu histórico individual de trajetos. Dados agregados por região, nunca por pessoa. A política de privacidade completa está disponível em desenvolvimento.',
          ),
          const _Section(
            title: 'Para quem anda de ônibus',
            body:
                'Você é passageiro frequente de ônibus? O Faro hoje ajuda você a avaliar a região onde vai descer antes de chegar. Use o filtro de 24h e a busca por bairro pra olhar antecipadamente. Funções específicas pra ponto de ônibus e trecho a pé estão na V2 do roadmap.',
          ),
          const _Section(
            title: 'Contato',
            body:
                'Email: faro@example.com (placeholder — em produção será real). Toda contestação de relato é respondida em até 2h durante o beta.',
          ),
          const SizedBox(height: 24),
          const _Version(),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String body;
  const _Section({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Georgia',
              fontSize: 17,
              height: 1.25,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            body,
            style: const TextStyle(
              fontSize: 14,
              height: 1.55,
              color: Color(0xFF3A3A3A),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackgroundAlertsToggle extends StatefulWidget {
  const _BackgroundAlertsToggle();

  @override
  State<_BackgroundAlertsToggle> createState() => _BackgroundAlertsToggleState();
}

class _BackgroundAlertsToggleState extends State<_BackgroundAlertsToggle> {
  bool _enabled = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final v = await BackgroundLocationService.isOptedIn();
    if (!mounted) return;
    setState(() => _enabled = v);
  }

  Future<void> _toggle(bool target) async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      if (!target) {
        await BackgroundLocationService.setOptIn(false);
        await BackgroundLocationService.instance.stop();
        if (mounted) setState(() => _enabled = false);
        return;
      }

      final locOk = await _ensureAlwaysLocation();
      if (!locOk) {
        if (mounted) _showInfo('Permissão de localização "Sempre" necessária.');
        return;
      }

      await LocalNotificationService.instance.initialize();
      final notifOk = await LocalNotificationService.instance.requestPermission();
      if (!notifOk) {
        if (mounted) _showInfo('Permissão de notificação necessária.');
        return;
      }

      await BackgroundLocationService.setOptIn(true);
      final started = await BackgroundLocationService.instance.start();
      if (!mounted) return;
      setState(() => _enabled = started);
      if (!started) _showInfo('Não foi possível iniciar o monitoramento agora.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _ensureAlwaysLocation() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever ||
        perm == LocationPermission.denied) {
      return false;
    }
    if (perm == LocationPermission.whileInUse) {
      // iOS: pedir Always explicitamente (segundo prompt do sistema)
      perm = await Geolocator.requestPermission();
    }
    return perm == LocationPermission.always;
  }

  void _showInfo(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFE7D5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD8CCAE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.notifications_active_outlined,
                size: 22, color: Color(0xFF7A5C2C)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Alertar com o app fechado',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 15,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _enabled
                      ? 'Faro está atento à sua região. Avisa se houver relatos recentes próximos.'
                      : 'Receba uma notificação ao entrar em regiões com relatos recentes. Usa GPS em segundo plano.',
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.45,
                    color: Color(0xFF3A3A3A),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _enabled,
            onChanged: _busy ? null : _toggle,
            activeThumbColor: const Color(0xFF2A4A7A),
          ),
        ],
      ),
    );
  }
}

class _Version extends StatelessWidget {
  const _Version();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Faro · v0.1.0 (alpha)',
        style: TextStyle(
          fontSize: 12,
          color: Color(0xFF8A8A8A),
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}
