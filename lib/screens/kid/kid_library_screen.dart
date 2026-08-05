import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/audio_cache_service.dart';
import '../../services/kid_storybook_service.dart';
import '../../widgets/kid_parent_admin_corner.dart';
import 'kid_layout_constants.dart';
import 'widgets/kid_library_cabinet_shelf.dart';
import 'widgets/kid_session_nav_button.dart';
import 'widgets/library_cabinet_background.dart';

/// Indtalt velkomst når barnet åbner biblioteket — læg filen i `assets/`.
const String kidLibraryIntroAsset = 'assets/dette_er_biblioteket.mp3';

/// Bibliotek – tegnet bogskab (hylder i kode), bøger på hylder.
class KidLibraryScreen extends StatefulWidget {
  final String kidId;

  /// Når barnet kommer fra hjemskærmen, afspilles intro allerede ved tryk — undgå dobbelt lyd.
  final bool skipIntroOnOpen;

  const KidLibraryScreen({
    super.key,
    required this.kidId,
    this.skipIntroOnOpen = false,
  });

  @override
  State<KidLibraryScreen> createState() => _KidLibraryScreenState();
}

class _KidLibraryScreenState extends State<KidLibraryScreen> {
  /// Rækkefølge på hylderne: købte shop-bøger, barnets egne bøger, og gruppe-tile
  /// `{'_kind':'group'|'kid_story'}`.
  List<Map<String, dynamic>> _shelfItems = [];
  bool _loading = true;
  final AudioPlayer _libraryIntroPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _loadBooks();
    unawaited(AudioCacheService.syncAll());
    if (!widget.skipIntroOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_playLibraryIntro());
      });
    }
  }

  @override
  void dispose() {
    unawaited(_libraryIntroPlayer.dispose());
    super.dispose();
  }

  Future<void> _playLibraryIntro() async {
    if (!mounted) return;
    try {
      await _libraryIntroPlayer.stop();
      await _libraryIntroPlayer.setAudioSource(
        AudioSource.asset(kidLibraryIntroAsset),
        preload: true,
      );
      await _libraryIntroPlayer.play();
    } catch (e, st) {
      debugPrint('KidLibraryScreen: kunne ikke afspille $kidLibraryIntroAsset: $e\n$st');
    }
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
        if (mounted) {
          setState(() {
            _shelfItems = [];
            _loading = false;
          });
        }
        return;
      }

      var bookIds = <String>[];
      try {
        final purchasesRes = await Supabase.instance.client
            .from('shop_book_purchases')
            .select('book_id')
            .eq('profile_id', profileId);
        for (final p in purchasesRes as List) {
          bookIds.add(p['book_id'] as String);
        }
      } catch (_) {
        bookIds = [];
      }

      var books = <Map<String, dynamic>>[];
      if (bookIds.isNotEmpty) {
        final booksRes = await Supabase.instance.client
            .from('shop_books')
            .select('id, title')
            .inFilter('id', bookIds);
        books = (booksRes as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();

        for (final b in books) {
          final pagesRes = await Supabase.instance.client
              .from('shop_book_pages')
              .select('right_image_url')
              .eq('book_id', b['id'])
              .eq('spread_index', 0)
              .maybeSingle();
          b['cover_url'] = pagesRes?['right_image_url'];
        }

        final purchaseOrder = <String, int>{
          for (var i = 0; i < bookIds.length; i++) bookIds[i]: i,
        };
        books.sort(
          (a, b) => (purchaseOrder[a['id']] ?? 0)
              .compareTo(purchaseOrder[b['id']] ?? 0),
        );
      }

      var shelfItems = List<Map<String, dynamic>>.from(books);

      if (books.length > 6) {
        try {
          final groupsRes = await Supabase.instance.client
              .from('shop_book_groups')
              .select('id, name, sort_order')
              .eq('profile_id', profileId)
              .order('sort_order');
          final groups = (groupsRes as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          final groupIds = groups.map((g) => g['id'] as String).toList();

          final itemsRes = groupIds.isEmpty
              ? <dynamic>[]
              : await Supabase.instance.client
                  .from('shop_book_group_items')
                  .select('group_id, book_id, sort_order')
                  .inFilter('group_id', groupIds)
                  .order('sort_order');

          final booksInAnyGroup = <String>{};
          final itemsByGroup = <String, List<Map<String, dynamic>>>{};
          for (final g in groups) {
            itemsByGroup[g['id'] as String] = [];
          }
          for (final row in itemsRes) {
            final m = Map<String, dynamic>.from(row as Map);
            final gid = m['group_id'] as String;
            if (!itemsByGroup.containsKey(gid)) continue;
            final bid = m['book_id'] as String;
            booksInAnyGroup.add(bid);
            itemsByGroup[gid]!.add(m);
          }

          shelfItems = [];
          for (final g in groups) {
            final gid = g['id'] as String;
            final itemRows = itemsByGroup[gid] ?? [];
            if (itemRows.isEmpty) continue;
            shelfItems.add({
              '_kind': 'group',
              'id': gid,
              'name': g['name'] as String? ?? 'Gruppe',
            });
          }
          for (final b in books) {
            final id = b['id'] as String;
            if (!booksInAnyGroup.contains(id)) {
              shelfItems.add(b);
            }
          }
        } catch (_) {
          shelfItems = List.from(books);
        }
      }

      final kidShelf = <Map<String, dynamic>>[];
      try {
        List<Map<String, dynamic>> idOrder;
        try {
          final kidRes = await Supabase.instance.client
              .from('kid_story_books')
              .select('id')
              .eq('kid_id', widget.kidId)
              .eq('published_to_library', true)
              .order('updated_at', ascending: false);
          idOrder = (kidRes as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        } catch (_) {
          final kidRes = await Supabase.instance.client
              .from('kid_story_books')
              .select('id')
              .eq('kid_id', widget.kidId)
              .order('updated_at', ascending: false);
          idOrder = (kidRes as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        }
        if (idOrder.isNotEmpty) {
          final cabinet =
              await KidStorybookService.listKidBooksForCabinet(widget.kidId);
          final byId = {for (final b in cabinet) b['id'] as String: b};
          for (final row in idOrder) {
            final id = row['id'] as String;
            final b = byId[id];
            if (b != null) {
              kidShelf.add(b);
            }
          }
        }
      } catch (_) {
        // Tabeller / migration ikke klar endnu.
      }
      shelfItems = [...kidShelf, ...shelfItems];

      if (mounted) {
        setState(() {
          _shelfItems = shelfItems;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _shelfItems = [];
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final shortestSide = MediaQuery.sizeOf(context).shortestSide;
    final isTablet = shortestSide >= 600;
    final topPad = MediaQuery.paddingOf(context).top;
    final screenSize = MediaQuery.sizeOf(context);
    final hasBooks = _shelfItems.isNotEmpty;
    final showBookOverlay = !_loading && hasBooks;

    return Scaffold(
      backgroundColor: const Color(0xFF3E2723),
      body: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: SvgPicture.asset(
              'assets/alfamonbaggrund.svg',
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
          ),
          Center(
            child: SizedBox(
              width: screenSize.width,
              height: screenSize.height,
              child: Transform.scale(
                scale: 0.8,
                alignment: Alignment.center,
                filterQuality: FilterQuality.medium,
                child: Stack(
                  fit: StackFit.expand,
                  clipBehavior: Clip.none,
                  children: [
                    const LibraryCabinetBackground(showWallBackdrop: false),
                    if (showBookOverlay)
                      BogskabShelfOverlay(
                        maxWidth: screenSize.width,
                        maxHeight: screenSize.height,
                        kidId: widget.kidId,
                        booksPerShelf: distributeBooksOnCabinetShelves(
                          _shelfItems,
                        ),
                        isTablet: isTablet,
                      ),
                  ],
                ),
              ),
            ),
          ),
          // Let mørkning øverst så titel og knap læses bedre
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: topPad + 72,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.45),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    kidZoneHorizontalPadding + 52,
                    8,
                    kidZoneHorizontalPadding,
                    4,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Bibliotek',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: isTablet ? 26 : 22,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          shadows: const [
                            Shadow(
                              color: Colors.black87,
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      FilledButton.icon(
                        onPressed: _loading
                            ? null
                            : () => context.push('/kid/storybook/${widget.kidId}'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF6A1B9A),
                        ),
                        icon: const Icon(Icons.auto_stories, size: 22),
                        label: const Text('Lav min egen bog'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: IgnorePointer(
                    ignoring: showBookOverlay,
                    child: _loading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFFF9C433),
                            ),
                          )
                        : !hasBooks
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: 0.35,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Padding(
                                      padding: EdgeInsets.all(20),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.menu_book,
                                            size: 56,
                                            color: Colors.white70,
                                          ),
                                          SizedBox(height: 12),
                                          Text(
                                            'Ingen bøger endnu.\nForældre kan købe bøger i Bogbutik.',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            : const ColoredBox(
                                color: Colors.transparent,
                                child: SizedBox.expand(),
                              ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            left: kidZoneHorizontalPadding,
            child: KidSessionNavButton(kidId: widget.kidId),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            right: kidZoneHorizontalPadding,
            child: const KidParentAdminCornerButton(),
          ),
        ],
      ),
    );
  }
}
