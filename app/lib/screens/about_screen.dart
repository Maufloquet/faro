import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../core/design/tokens.dart';
import '../services/analytics_service.dart';
import '../services/background_location_service.dart';
import '../services/local_notification_service.dart';
import '../services/reference_location_service.dart';

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
        children: const [
          _BackgroundAlertsToggle(),
          SizedBox(height: 12),
          _ReferenceLocationCard(),
          SizedBox(height: 18),
          _Section(
            title: 'O que somos',
            body:
                'Um assistente de decisão urbana em tempo real. Mostramos o que está acontecendo perto de você combinando fontes públicas e (futuramente) relatos de usuários. Não somos um mapa de crimes. Não substituímos sua atenção.',
          ),
          _Section(
            title: 'O que não somos',
            body:
                'Não somos um produto de garantia. Nunca dizemos "está seguro". A única mensagem possível em uma região sem relatos é "sem relatos recentes" — silêncio nos dados não é silêncio nas ruas. Mantenha atenção sempre.',
          ),
          _Section(
            title: 'Sem cadastro',
            body:
                'Você não precisa criar conta. Não pedimos seu nome, email ou telefone. Seu uso é anônimo. Não rastreamos seu trajeto. Você abre o app e já está usando — é assim por princípio, não por descuido.',
          ),
          _Section(
            title: 'Fontes de dados',
            body:
                'Hoje: Fogo Cruzado (banco público de violência armada — RJ, PE, BA, PA) + matérias de jornais locais (G1, A Tarde, Correio 24h, iBahia, Bahia Notícias, Tribuna da Bahia, releases da SSP-BA) processadas por IA pra extrair bairro, tipo de relato e linha de ônibus. Próximas: relatos de usuários com validação coletiva e canais públicos do Telegram. Cada fonte com peso diferente.',
          ),
          _Section(
            title: 'Privacidade',
            body:
                'Sua localização é usada apenas para mostrar relatos próximos. Não armazenamos seu histórico individual de trajetos. Dados agregados por região, nunca por pessoa. A política de privacidade completa está disponível em desenvolvimento.',
          ),
          _TechDetailsExpansion(),
          SizedBox(height: 18),
          _Section(
            title: 'Como usar o Faro',
            body:
                'A tela "Como o Faro funciona" tem caminhos práticos por perfil: passageiro de ônibus, motorista de aplicativo, entregador, visitante. Toque no ícone de informação no canto superior do mapa.',
          ),
          _Section(
            title: 'Contato',
            body:
                'Email: faro@example.com (placeholder — em produção será real). Toda contestação de relato é respondida em até 2h durante o beta.',
          ),
          SizedBox(height: 24),
          _Version(),
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
              color: FaroColors.textPrimary,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            body,
            style: const TextStyle(
              fontSize: 14,
              height: 1.55,
              color: FaroColors.textSecondary,
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
                size: 22, color: FaroColors.editorialBrown),
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
                    color: FaroColors.textPrimary,
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
                    color: FaroColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _enabled,
            onChanged: _busy ? null : _toggle,
            activeThumbColor: FaroColors.primary,
          ),
        ],
      ),
    );
  }
}

/// Card que permite o usuário definir 1 endereço fixo de referência
/// (hotel, casa, trabalho) e receber alerta quando há relato perto **mesmo
/// se estiver longe do local agora**. Útil pra turista hospedado em
/// algum lugar e quer saber do entorno do hotel ao longo do dia.
class _ReferenceLocationCard extends StatefulWidget {
  const _ReferenceLocationCard();

  @override
  State<_ReferenceLocationCard> createState() => _ReferenceLocationCardState();
}

class _ReferenceLocationCardState extends State<_ReferenceLocationCard> {
  ReferenceLocation? _current;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await ReferenceLocationService.instance.current();
    if (!mounted) return;
    setState(() => _current = r);
  }

  Future<void> _saveFromCurrentLocation() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      // Permissão whileInUse já é suficiente pra captura pontual.
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        _showInfo('Permissão de localização necessária pra salvar este local.');
        return;
      }

      final pos = await Geolocator.getCurrentPosition();
      if (!mounted) return;

      final label = await _askLabel();
      if (label == null) return; // usuário cancelou

      await ReferenceLocationService.instance.save(
        ReferenceLocation(lat: pos.latitude, lng: pos.longitude, label: label),
      );
      await _load();
      if (mounted) _showInfo('Local salvo. Faro vai te avisar de relatos por aqui.');
    } catch (e) {
      _showInfo('Não foi possível salvar agora. Tente novamente.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _askLabel() async {
    final controller = TextEditingController(text: _current?.label ?? 'Hotel');
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Como chamar este local?',
          style: TextStyle(fontFamily: FaroFonts.serifEditorial, fontSize: 18),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Hotel, Casa, Trabalho...',
            border: OutlineInputBorder(),
          ),
          maxLength: 40,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: FaroColors.primary),
            onPressed: () {
              final v = controller.text.trim();
              Navigator.of(ctx).pop(v.isEmpty ? 'Local salvo' : v);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  Future<void> _remove() async {
    await ReferenceLocationService.instance.clear();
    await _load();
    if (mounted) _showInfo('Local removido.');
  }

  void _showInfo(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final r = _current;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: FaroColors.sandSoft,
        borderRadius: BorderRadius.circular(FaroRadii.card),
        border: Border.all(color: FaroColors.sandBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.place_outlined,
                    size: 22, color: FaroColors.editorialBrown),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Local de referência',
                      style: TextStyle(
                        fontFamily: FaroFonts.serifEditorial,
                        fontSize: 15,
                        color: FaroColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      r == null
                          ? 'Salve um lugar fixo (hotel, casa, trabalho) e o Faro avisa quando aparecer relato por lá — mesmo se você estiver longe agora.'
                          : '${r.label} · alertando o entorno deste ponto',
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.45,
                        color: FaroColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (r != null)
                TextButton(
                  onPressed: _busy ? null : _remove,
                  style: TextButton.styleFrom(
                    foregroundColor: FaroColors.destructive,
                  ),
                  child: const Text('Remover'),
                ),
              const SizedBox(width: 4),
              FilledButton.icon(
                onPressed: _busy ? null : _saveFromCurrentLocation,
                style: FilledButton.styleFrom(
                  backgroundColor: FaroColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                icon: const Icon(Icons.my_location, size: 16),
                label: Text(r == null ? 'Usar minha localização' : 'Trocar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Bloco colapsável com detalhes técnicos que interessam a poucos:
/// como o risco é classificado, viés algorítmico, fonte da densidade
/// populacional. Mantido aqui pra transparência editorial — só não
/// é exibido por padrão pra não inflar a tela "Sobre" pra quem quer
/// a visão geral.
class _TechDetailsExpansion extends StatelessWidget {
  const _TechDetailsExpansion();

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      ),
      child: const ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.only(top: 8),
        title: Text(
          'Detalhes técnicos',
          style: TextStyle(
            fontFamily: FaroFonts.serifEditorial,
            fontSize: 17,
            color: FaroColors.textPrimary,
          ),
        ),
        subtitle: Padding(
          padding: EdgeInsets.only(top: 4),
          child: Text(
            'Como classificamos risco · viés algorítmico · fonte da densidade',
            style: TextStyle(fontSize: 12.5, color: FaroColors.textSoft),
          ),
        ),
        iconColor: FaroColors.editorialBrown,
        collapsedIconColor: FaroColors.editorialBrown,
        children: [
          _Section(
            title: 'Como classificamos o risco',
            body:
                'Combinamos peso da fonte, idade do relato e densidade de confirmações. Reportes antigos perdem peso automaticamente. Múltiplas fontes independentes corroborando elevam o nível. Uma única fonte isolada nunca sustenta classificação alta.',
          ),
          _Section(
            title: 'Sobre viés algorítmico',
            body:
                'Periferias têm mais policiamento e mais cobertura de mídia — não necessariamente mais crime real. Mais boletins em uma região indicam mais visibilidade, não mais risco. Quando não temos dados suficientes em uma área, dizemos isso explicitamente, em vez de assumir que é seguro.',
          ),
          _Section(
            title: 'Densidade populacional (em construção)',
            body:
                'Quando exibimos "relatos por 10 mil habitantes" em um bairro, usamos população do Censo IBGE 2010 (via PMS/SEMOP), porque o Censo 2022 ainda não publicou agregação por bairro para Salvador. Bairros sem dado de população não mostram normalização — preferimos silêncio honesto a número inventado.',
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
