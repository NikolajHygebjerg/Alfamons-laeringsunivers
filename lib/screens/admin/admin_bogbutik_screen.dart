import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Bogbutik – forældre kan købe Læs-let bøger.
/// Forberedt til in-app køb, priser sættes til 0 kr indtil videre.
class AdminBogbutikScreen extends StatefulWidget {
  const AdminBogbutikScreen({super.key});

  @override
  State<AdminBogbutikScreen> createState() => _AdminBogbutikScreenState();
}

class _AdminBogbutikScreenState extends State<AdminBogbutikScreen> {
  List<Map<String, dynamic>> _books = [];
  Set<String> _ownedBookIds = {};
  String? _profileId;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        if (mounted) setState(() { _error = 'Log ind for at se bogbutikken'; _loading = false; });
        return;
      }

      final profile = await Supabase.instance.client
          .from('profiles')
          .select('id')
          .eq('auth_user_id', user.id)
          .maybeSingle();
      _profileId = profile?['id'] as String?;

      List<Map<String, dynamic>> books;
      try {
        final booksRes = await Supabase.instance.client
            .from('shop_books')
            .select('id, title, price_kr')
            .order('updated_at', ascending: false);
        books = (booksRes as List<dynamic>)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      } catch (_) {
        final booksRes = await Supabase.instance.client
            .from('shop_books')
            .select('id, title')
            .order('updated_at', ascending: false);
        books = (booksRes as List<dynamic>)
            .map((e) {
              final m = Map<String, dynamic>.from(e as Map);
              m['price_kr'] = 0;
              return m;
            })
            .toList();
      }

      final booksList = books;

      for (final b in booksList) {
        final pagesRes = await Supabase.instance.client
            .from('shop_book_pages')
            .select('right_image_url')
            .eq('book_id', b['id'])
            .eq('spread_index', 0)
            .maybeSingle();
        b['cover_url'] = pagesRes?['right_image_url'];
      }

      Set<String> owned = {};
      if (_profileId != null) {
        try {
          final purchasesRes = await Supabase.instance.client
              .from('shop_book_purchases')
              .select('book_id')
              .eq('profile_id', _profileId!);
          for (final p in purchasesRes as List) {
            owned.add(p['book_id'] as String);
          }
        } on PostgrestException catch (e) {
          if (e.code == 'PGRST205') {
            debugPrint('shop_book_purchases findes ikke – kør migration 20250319000000_shop_books_price_purchases.sql');
          } else {
            rethrow;
          }
        }
      }

      if (mounted) {
        setState(() {
          _books = booksList;
          _ownedBookIds = owned;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _purchaseBook(String bookId) async {
    if (_profileId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kunne ikke finde din profil')),
      );
      return;
    }
    if (_ownedBookIds.contains(bookId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Du ejer allerede denne bog')),
      );
      return;
    }

    try {
      await Supabase.instance.client.from('shop_book_purchases').insert({
        'profile_id': _profileId!,
        'book_id': bookId,
      });
      if (mounted) {
        setState(() => _ownedBookIds = {..._ownedBookIds, bookId});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bog købt – den er nu i dit bibliotek')),
        );
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        final msg = e.code == 'PGRST205'
            ? 'Køb ikke tilgængeligt endnu. Kør migration 20250319000000_shop_books_price_purchases.sql i Supabase SQL Editor.'
            : 'Køb fejlede: $e';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), duration: const Duration(seconds: 5)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Køb fejlede: $e')),
        );
      }
    }
  }

  String _formatPrice(dynamic price) {
    if (price == null) return 'Gratis';
    final p = price is num ? price.toDouble() : double.tryParse(price.toString()) ?? 0.0;
    if (p <= 0) return 'Gratis';
    return '${p.toStringAsFixed(0)} kr';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bogbutik'),
        backgroundColor: const Color(0xFF5A1A0D),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _load,
                child: const Text('Prøv igen'),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF5A1A0D), Color(0xFFE85A4A)],
        ),
      ),
      child: _books.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.menu_book, size: 64, color: Colors.white70),
                    const SizedBox(height: 16),
                    const Text(
                      'Ingen bøger i butikken endnu.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ],
                ),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.7,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: _books.length,
              itemBuilder: (context, i) {
                final b = _books[i];
                final id = b['id'] as String;
                final title = b['title'] as String? ?? 'Uden titel';
                final coverUrl = b['cover_url'] as String?;
                final price = b['price_kr'];
                final owned = _ownedBookIds.contains(id);

                return Card(
                  color: const Color(0xFFF9C433).withOpacity(0.9),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: coverUrl != null && coverUrl.isNotEmpty
                            ? Image.network(
                                coverUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Center(
                                  child: Icon(Icons.menu_book, size: 48),
                                ),
                              )
                            : const Center(
                                child: Icon(Icons.menu_book, size: 48),
                              ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _formatPrice(price),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF5A1A0D),
                                  ),
                                ),
                                if (owned)
                                  const Text(
                                    'Ejet',
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                else
                                  FilledButton(
                                    onPressed: () => _purchaseBook(id),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFF5A1A0D),
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                    ),
                                    child: const Text('Køb'),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
