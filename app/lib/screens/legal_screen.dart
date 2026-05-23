import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../core/design/tokens.dart';
import '../services/analytics_service.dart';

/// Termos de uso + Política de privacidade em tabs.
///
/// Textos vivem em `assets/legal/*.md`. Renderizamos um subconjunto de
/// markdown (heading, bold, lista, parágrafo) sem dep externa — manter
/// `flutter_markdown` fora do bundle.
class LegalScreen extends StatefulWidget {
  /// Aba inicial: 0 = Termos, 1 = Privacidade.
  final int initialTab;
  const LegalScreen({super.key, this.initialTab = 0});

  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen> {
  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logScreen('legal');
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Termos e privacidade',
              style: TextStyle(fontFamily: 'Fraunces')),
          elevation: 0,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Termos de uso'),
              Tab(text: 'Privacidade'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _MarkdownAsset(path: 'assets/legal/termos.md'),
            _MarkdownAsset(path: 'assets/legal/privacidade.md'),
          ],
        ),
      ),
    );
  }
}

class _MarkdownAsset extends StatelessWidget {
  final String path;
  const _MarkdownAsset({required this.path});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: rootBundle.loadString(path),
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: _MarkdownRenderer(text: snap.data!),
        );
      },
    );
  }
}

/// Renderer minimalista. Suporta:
///   - # h1, ## h2, ### h3
///   - **bold** dentro de parágrafos
///   - listas com - no início
///   - parágrafos separados por linha em branco
class _MarkdownRenderer extends StatelessWidget {
  final String text;
  const _MarkdownRenderer({required this.text});

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n');
    final widgets = <Widget>[];
    final bullets = <String>[];

    void flushBullets() {
      if (bullets.isEmpty) return;
      for (final b in bullets) {
        widgets.add(_bulletLine(context, b));
      }
      bullets.clear();
    }

    for (var i = 0; i < lines.length; i++) {
      final raw = lines[i];
      final line = raw.trimRight();
      if (line.isEmpty) {
        flushBullets();
        widgets.add(const SizedBox(height: 8));
        continue;
      }
      if (line.startsWith('### ')) {
        flushBullets();
        widgets.add(_heading(context, line.substring(4), level: 3));
        continue;
      }
      if (line.startsWith('## ')) {
        flushBullets();
        widgets.add(_heading(context, line.substring(3), level: 2));
        continue;
      }
      if (line.startsWith('# ')) {
        flushBullets();
        widgets.add(_heading(context, line.substring(2), level: 1));
        continue;
      }
      if (line.startsWith('- ')) {
        bullets.add(line.substring(2));
        continue;
      }
      flushBullets();
      widgets.add(_paragraph(context, line));
    }
    flushBullets();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _heading(BuildContext context, String text, {required int level}) {
    final size = switch (level) {
      1 => 26.0,
      2 => 19.0,
      _ => 16.0,
    };
    return Padding(
      padding: EdgeInsets.only(top: level == 1 ? 0 : 16, bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Fraunces',
          fontWeight: FontWeight.w600,
          fontSize: size,
          color: FaroColors.textPrimary,
          height: 1.25,
        ),
      ),
    );
  }

  Widget _bulletLine(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6, right: 10),
            child: Icon(Icons.circle, size: 5, color: FaroColors.textSoft),
          ),
          Expanded(child: _richInline(text)),
        ],
      ),
    );
  }

  Widget _paragraph(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: _richInline(text),
    );
  }

  /// Renderiza inline com suporte a **bold**. Regex captura pares de
  /// `**...**` (modo não guloso). Resto vira texto normal.
  Widget _richInline(String text) {
    final spans = <TextSpan>[];
    final pattern = RegExp(r'\*\*(.+?)\*\*');
    int cursor = 0;
    for (final match in pattern.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }
      spans.add(TextSpan(
        text: match.group(1),
        style: const TextStyle(fontWeight: FontWeight.w600),
      ));
      cursor = match.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 14,
          height: 1.55,
          color: FaroColors.textSecondary,
        ),
        children: spans,
      ),
    );
  }
}
