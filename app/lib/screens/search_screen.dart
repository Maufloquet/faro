import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/bairros_directory.dart';

/// Tela de busca por bairro de Salvador.
///
/// Catálogo vem de assets/bairros_salvador.json (152 bairros via OSM).
/// Tap em um item retorna lat/lng via Navigator.pop.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final directory = ref.watch(bairrosDirectoryProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buscar bairro', style: TextStyle(fontFamily: 'Georgia')),
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Ex: Pirajá, Itapuã, Barra…',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _controller.clear();
                          setState(() => _query = '');
                        },
                      ),
                filled: true,
                fillColor: const Color(0xFFF7F4ED),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Bairro>>(
              future: directory.search(_query),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final results = snap.data!;
                if (results.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _query.isEmpty
                          ? 'Carregando lista de bairros…'
                          : 'Nenhum bairro encontrado com "$_query".',
                      style: const TextStyle(color: Color(0xFF7A7A7A)),
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: results.length,
                  separatorBuilder: (_, _) => const Divider(height: 1, indent: 56),
                  itemBuilder: (_, i) {
                    final b = results[i];
                    return ListTile(
                      leading: const Icon(Icons.place_outlined,
                          size: 20, color: Color(0xFF2A4A7A)),
                      title: Text(
                        b.displayName,
                        style: const TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 15,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right,
                          size: 18, color: Color(0xFFB8B8B0)),
                      onTap: () => Navigator.of(context).pop(b),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
