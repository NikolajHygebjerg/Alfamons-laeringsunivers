import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/audio_cache_service.dart';
import 'widgets/kid_session_nav_button.dart';

/// Bibliotek – bøger forældre har købt.
class KidLibraryScreen extends StatefulWidget {
  final String kidId;

  const KidLibraryScreen({super.key, required this.kidId});

  @override
  State<KidLibraryScreen> createState() => _KidLibraryScreenState();
}

class _KidLibraryScreenState extends State<KidLibraryScreen> {
  List<Map<String, dynamic>> _purchasedBooks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBooks();
    unawaited(AudioCacheService.syncAll());
  }

  Future<void> _loadBooks() async {
    setState(() => _loading = true);
    try {
      final kidRes = await Supabase.instance.client
          .from('kids')
          .select('parent_id')
          .eq('id', widget.kidId)
          .maybeSingle();
      final profileId = kidRes?['parent_id'] as String?;
      if (profileId == null) {
        if (mounted) setState(() { _purchasedBooks = []; _loading = false; });
        return;
      }

      List<String> bookIds = [];
      try {
        final purchasesRes = await Supabase.instance.client
            .from('shop_book_purchases')
            .select('book_id')
            .eq('profile_id', profileId);
        for (final p in purchasesRes as List) {
          bookIds.add(p['book_id'] as String);
        }
      } catch (_) {
        if (mounted) setState(() { _purchasedBooks = []; _loading = false; });
        return;
      }

      if (bookIds.isEmpty) {
        if (mounted) setState(() { _purchasedBooks = []; _loading = false; });
        return;
      }

      final booksRes = await Supabase.instance.client
          .from('shop_books')
          .select('id, title')
          .inFilter('id', bookIds);
      final books = (booksRes as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

      for (final b in books) {
        final pagesRes = await Supabase.instance.client
            .from('shop_book_pages')
            .select('right_image_url')
            .eq('book_id', b['id'])
            .eq('spread_index', 0)
            .maybeSingle();
        b['cover_url'] = pagesRes?['right_image_url'];
      }

      if (mounted) setState(() { _purchasedBooks = books; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _purchasedBooks = []; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final shortestSide = MediaQuery.of(context).size.shortestSide;
    final isTablet = shortestSide >= 600;
    final bgAsset = isTablet ? 'assets/baggrund_roedipad.svg' : 'assets/baggrund_roediphone.svg';

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(child: SvgPicture.asset(bgAsset, fit: BoxFit.cover)),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Bibliotek', style: TextStyle(fontSize: isTablet ? 28 : 24, fontWeight: FontWeight.w900, color: Colors.white)),
                ),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator(color: Colors.white))
                      : _purchasedBooks.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.menu_book, size: 64, color: Colors.white70),
                                    const SizedBox(height: 16),
                                    const Text('Ingen bøger endnu.\nForældre kan købe bøger i Bogbutik.', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.white)),
                                  ],
                                ),
                              ),
                            )
                          : GridView.builder(
                              padding: const EdgeInsets.all(16),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: isTablet ? 5 : 4,
                                childAspectRatio: 0.7,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                              itemCount: _purchasedBooks.length,
                              itemBuilder: (context, i) {
                                final b = _purchasedBooks[i];
                                final id = b['id'] as String;
                                final title = b['title'] as String? ?? 'Uden titel';
                                final coverUrl = b['cover_url'] as String?;
                                return GestureDetector(
                                  onTap: () => context.push('/kid/library/${widget.kidId}/book/$id'),
                                  behavior: HitTestBehavior.opaque,
                                  child: Card(
                                    color: const Color(0xFFF9C433).withOpacity(0.9),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Expanded(
                                          child: coverUrl != null && coverUrl.isNotEmpty
                                              ? Image.network(coverUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.menu_book, size: 32)))
                                              : const Center(child: Icon(Icons.menu_book, size: 32)),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.all(6),
                                          child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            left: 8,
            child: KidSessionNavButton(kidId: widget.kidId),
          ),
        ],
      ),
    );
  }
}
