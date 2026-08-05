import 'dart:convert' show jsonDecode;
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/kid_storybook_page_decoration.dart';
import '../models/kid_storybook_page_format.dart';
import '../models/kid_storybook_page_item.dart';
import '../models/kid_storybook_page_layout.dart';
import 'book_builder_gallery_service.dart';
import '../utils/alfamon_display_name.dart';
import '../utils/kid_storybook_bundle_images.dart';
import '../utils/read_file_bytes_stub.dart'
    if (dart.library.io) '../utils/read_file_bytes_io.dart' as file_reader;

const _bookImagesBucket = 'book-images';

void _sortAvatarsByDisplayName(List<Map<String, dynamic>> list) {
  list.sort((a, b) {
    final na = (a['name'] as String? ?? '').trim().toLowerCase();
    final nb = (b['name'] as String? ?? '').trim().toLowerCase();
    final c = na.compareTo(nb);
    if (c != 0) return c;
    final ida = (a['id'] as String? ?? '');
    final idb = (b['id'] as String? ?? '');
    return ida.compareTo(idb);
  });
}

pw.Widget? _pdfDecorationPositioned(
  KidStorybookPageDecoration? dec,
  double contentW,
  double contentH,
) {
  if (dec == null) return null;
  final base = contentW * 0.14;
  final side = (base * dec.scale).clamp(10.0, contentW);
  var left = contentW * dec.cx - side / 2;
  var top = contentH * dec.cy - side / 2;
  left = left.clamp(0.0, contentW - side);
  top = top.clamp(0.0, contentH - side);
  if (dec.isIcon) {
    return pw.Positioned(
      left: left,
      top: top,
      child: pw.Container(
        width: side,
        height: side,
        alignment: pw.Alignment.center,
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.blue800, width: 0.5),
        ),
        child: pw.Text(
          '✦',
          style: pw.TextStyle(fontSize: side * 0.55),
        ),
      ),
    );
  }
  final c = dec.colorValue ?? 0xFF1976D2;
  final r = ((c >> 16) & 0xFF) / 255.0;
  final g = ((c >> 8) & 0xFF) / 255.0;
  final b = (c & 0xFF) / 255.0;
  final isCircle = dec.id == 's_circle' || dec.id == 's_heart';
  final isRrect = dec.id == 's_rrect';
  return pw.Positioned(
    left: left,
    top: top,
    child: pw.Container(
      width: side,
      height: side,
      decoration: pw.BoxDecoration(
        color: PdfColor(r, g, b),
        shape: isCircle ? pw.BoxShape.circle : pw.BoxShape.rectangle,
        borderRadius: isRrect
            ? pw.BorderRadius.all(
                pw.Radius.circular(
                  (side * 0.15).clamp(1.0, 40.0),
                ),
              )
            : null,
      ),
    ),
  );
}

String _extFromFileName(String name) {
  final i = name.lastIndexOf('.');
  if (i < 0) return '.jpg';
  return name.substring(i).toLowerCase();
}

class KidStorybookService {
  KidStorybookService._();

  static final _client = Supabase.instance.client;

  static Future<String?> parentProfileId() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    final r = await _client
        .from('profiles')
        .select('id')
        .eq('auth_user_id', user.id)
        .maybeSingle();
    return r?['id'] as String?;
  }

  /// Sorteret liste af {id, name, letter} (alfabetisk efter vist navn, stabil ved navnelikhed).
  static Future<List<Map<String, dynamic>>> listAvatars() async {
    final res = await _client
        .from('avatars')
        .select('id, name, letter')
        .order('name');
    final list = (res as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    for (final m in list) {
      m['name'] = alfamonDisplayName(m['name'] as String?);
    }
    _sortAvatarsByDisplayName(list);
    return list;
  }

  /// Første ikke-tomme [image_url] pr. avatar (laveste [stage_index]) — hurtig forhåndsvisning i gitter.
  static Future<Map<String, String>> avatarIdToFirstStageImageUrl(
    List<String> avatarIds,
  ) async {
    if (avatarIds.isEmpty) return {};
    final res = await _client
        .from('avatar_stages')
        .select('avatar_id, stage_index, image_url')
        .inFilter('avatar_id', avatarIds);
    final byAvatar = <String, List<Map<String, dynamic>>>{};
    for (final row in res as List) {
      final m = Map<String, dynamic>.from(row as Map);
      final id = m['avatar_id'] as String;
      byAvatar.putIfAbsent(id, () => []).add(m);
    }
    final out = <String, String>{};
    for (final e in byAvatar.entries) {
      e.value.sort(
        (a, b) => ((a['stage_index'] as num).toInt())
            .compareTo((b['stage_index'] as num).toInt()),
      );
      for (final m in e.value) {
        final u = (m['image_url'] as String? ?? '').trim();
        if (u.isNotEmpty) {
          out[e.key] = u;
          break;
        }
      }
    }
    return out;
  }

  /// Offentlige / lokale stier for Alfamon i bogbyggeren. Rækkefølge: først
  /// [book_builder_gallery] (admin), derefter [book_builder_extra_images], så
  /// [assets/alfamons_bundles/] og til sidst [avatar_stages] — så tildelte
  /// billeder er øverst i vælgeren.
  static Future<List<String>> imageUrlsForAvatar(
    String avatarId, {
    String? letter,
    String? avatarName,
  }) async {
    final seen = <String>{};
    final ordered = <String>[];

    void addAll(Iterable<String?> paths) {
      for (final u in paths) {
        final t = (u ?? '').trim();
        if (t.isEmpty) continue;
        if (seen.add(t)) ordered.add(t);
      }
    }

    var name = (avatarName ?? '').trim();
    if (name.isNotEmpty) {
      name = alfamonDisplayName(name);
    }

    try {
      addAll(
        await BookBuilderGalleryService.assetPathsForAvatar(avatarId),
      );
    } catch (e, st) {
      debugPrint('KidStorybookService.imageUrlsForAvatar: gallery: $e\n$st');
    }

    try {
      final extra = await _client
          .from('book_builder_extra_images')
          .select('image_url, sort_order')
          .eq('avatar_id', avatarId)
          .order('sort_order');
      addAll(
        (extra as List)
            .map((row) => (row as Map)['image_url'] as String?),
      );
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116' || e.message.contains('does not exist')) {
        // Migration ikke kørt endnu; fortsæt uden extra.
      } else {
        rethrow;
      }
    }

    if (name.isNotEmpty || (letter != null && letter.trim().isNotEmpty)) {
      try {
        addAll(
          await KidStorybookBundleImages.pathsForAvatar(
            name: name.isNotEmpty ? name : null,
            letter: letter,
          ),
        );
      } catch (e, st) {
        debugPrint('KidStorybookService.imageUrlsForAvatar: bundt-assets: $e\n$st');
      }
    }

    final stages = await _client
        .from('avatar_stages')
        .select('stage_index, image_url')
        .eq('avatar_id', avatarId)
        .order('stage_index');
    addAll(
      (stages as List)
          .map((row) => (row as Map)['image_url'] as String?),
    );

    return ordered;
  }

  static bool _isMissingKidStoryTable(Object e) {
    final s = e.toString();
    return s.contains('kid_story_books') && s.contains('does not exist');
  }

  /// Når [columnName] mangler: klassisk 42703 / PostgREST PGRST204 (schema cache).
  static bool _isMissingColumn(Object e, String columnName) {
    final s = e.toString();
    if (!s.contains(columnName)) return false;
    if (s.contains('does not exist')) return true;
    if (s.contains('PGRST204') || s.contains('schema cache')) return true;
    if (s.contains('Could not find') && s.contains('column')) return true;
    return false;
  }

  static Future<List<Map<String, dynamic>>> loadPagesForBook(String bookId) async {
    const selects = <String>[
      'id, spread_index, left_text, right_image_url, text_font_size, text_font_key, page_layout',
      'id, spread_index, left_text, right_image_url, text_font_size, text_font_key',
      'id, spread_index, left_text, right_image_url',
    ];
    Object? lastError;
    for (final sel in selects) {
      try {
        final pagesRes = await _client
            .from('kid_story_book_pages')
            .select(sel)
            .eq('book_id', bookId)
            .order('spread_index', ascending: true);
        return (pagesRes as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      } catch (e) {
        lastError = e;
      }
    }
    throw lastError ?? StateError('loadPagesForBook');
  }

  static Future<Map<String, dynamic>?> _selectKidStoryBookById(
    String bookId,
  ) async {
    Object? lastError;
    const selects = <String>[
      'id, title, kid_id, page_format, published_to_library',
      'id, title, kid_id, page_format',
      'id, title, kid_id, published_to_library',
      'id, title, kid_id',
    ];
    for (final sel in selects) {
      try {
        final book = await _client
            .from('kid_story_books')
            .select(sel)
            .eq('id', bookId)
            .maybeSingle();
        if (book == null) return null;
        final m = Map<String, dynamic>.from(book);
        if (!m.containsKey('published_to_library')) {
          m['published_to_library'] = true;
        }
        return m;
      } catch (e) {
        lastError = e;
      }
    }
    throw lastError ?? StateError('_selectKidStoryBookById');
  }

  /// Til læser: samme række, med [kid_id]-filter. Virker uden ældre kolonner.
  static Future<Map<String, dynamic>?> kidStoryBookRowForReader({
    required String bookId,
    required String kidId,
  }) async {
    Object? lastError;
    const selects = <String>[
      'id, title, page_format, published_to_library',
      'id, title, page_format',
      'id, title, published_to_library',
      'id, title',
    ];
    for (final sel in selects) {
      try {
        final kb = await _client
            .from('kid_story_books')
            .select(sel)
            .eq('id', bookId)
            .eq('kid_id', kidId)
            .maybeSingle();
        if (kb == null) return null;
        final m = Map<String, dynamic>.from(kb);
        if (!m.containsKey('published_to_library')) {
          m['published_to_library'] = true;
        }
        return m;
      } catch (e) {
        lastError = e;
      }
    }
    throw lastError ?? StateError('kidStoryBookRowForReader');
  }

  static Future<List<Map<String, dynamic>>> listKidBooks(String kidId) async {
    const selects = <String>[
      'id, title, updated_at, published_to_library, page_format',
      'id, title, updated_at, page_format',
      'id, title, updated_at, published_to_library',
      'id, title, updated_at',
    ];
    Object? lastError;
    for (final sel in selects) {
      try {
        final res = await _client
            .from('kid_story_books')
            .select(sel)
            .eq('kid_id', kidId)
            .order('updated_at', ascending: false);
        return (res as List)
            .map(
              (e) {
                final m = Map<String, dynamic>.from(e as Map);
                if (!m.containsKey('page_format')) {
                  m['page_format'] = 'landscape';
                }
                if (!m.containsKey('published_to_library')) {
                  m['published_to_library'] = true;
                }
                return m;
              },
            )
            .toList();
      } catch (e) {
        lastError = e;
        if (e is PostgrestException && _isMissingKidStoryTable(e)) {
          return [];
        }
        continue;
      }
    }
    throw lastError ?? StateError('listKidBooks');
  }

  /// Som rækker i læse-biblioteket: `_kind`, `id`, `title`, `cover_url`, `front_page`.
  ///
  /// [front_page] er spread 0 (forsiden), så hylden kan vise præcis den layout barnet
  /// lavede; [cover_url] er stadig billede-URL hvis andet udelukkende for bagudkomp.).
  static Future<List<Map<String, dynamic>>> listKidBooksForCabinet(
    String kidId,
  ) async {
    final rows = <Map<String, dynamic>>[];
    try {
      final list = await listKidBooks(kidId);
      if (list.isEmpty) return rows;

      final bookIds = list.map((e) => e['id'] as String).toList();
      final byBook = await _firstPagesByBookIdForBookshelf(bookIds);

      for (final m in list) {
        final id = m['id'] as String;
        final fp = byBook[id];
        String? cover;
        if (fp != null) {
          final u = (fp['right_image_url'] as String? ?? '').trim();
          cover = u.isEmpty ? null : u;
        } else {
          cover = await coverUrlForKidBook(id);
          cover = (cover ?? '').trim().isEmpty ? null : cover;
        }
        final row = <String, dynamic>{
          ...m,
          '_kind': 'kid_story',
          'cover_url': cover,
        };
        if (fp != null) {
          row['front_page'] = fp;
        }
        rows.add(row);
      }
    } catch (e) {
      if (e is PostgrestException && _isMissingKidStoryTable(e)) {
        return [];
      }
      rethrow;
    }
    return rows;
  }

  /// Eén forespørgsel: side 0 for alle bøger (forside).
  static Future<Map<String, Map<String, dynamic>>> _firstPagesByBookIdForBookshelf(
    List<String> bookIds,
  ) async {
    if (bookIds.isEmpty) return {};
    final out = <String, Map<String, dynamic>>{};

    Future<void> runSelect(String select) async {
      out.clear();
      final res = await _client
          .from('kid_story_book_pages')
          .select(select)
          .inFilter('book_id', bookIds)
          .eq('spread_index', 0);
      for (final r in res as List) {
        final m = Map<String, dynamic>.from(r as Map);
        final id = m['book_id'] as String;
        m.remove('book_id');
        out[id] = m;
      }
    }

    try {
      await runSelect(
        'book_id, left_text, right_image_url, text_font_size, text_font_key, page_layout',
      );
      return out;
    } catch (e) {
      if (!_isMissingColumn(e, 'page_layout')) rethrow;
    }
    try {
      await runSelect(
        'book_id, left_text, right_image_url, text_font_size, text_font_key',
      );
      return out;
    } catch (e) {
      if (!_isMissingColumn(e, 'text_font_size') &&
          !_isMissingColumn(e, 'text_font_key')) {
        rethrow;
      }
    }
    await runSelect('book_id, left_text, right_image_url');
    return out;
  }

  static Future<String?> coverUrlForKidBook(String bookId) async {
    final p = await _client
        .from('kid_story_book_pages')
        .select('right_image_url')
        .eq('book_id', bookId)
        .eq('spread_index', 0)
        .maybeSingle();
    return p?['right_image_url'] as String?;
  }

  static Future<Map<String, dynamic>?> loadKidBookWithPages(
    String bookId,
  ) async {
    final book = await _selectKidStoryBookById(bookId);
    if (book == null) return null;
    final pages = await loadPagesForBook(bookId);
    return {
      'book': book,
      'pages': pages,
    };
  }

  static Future<String> createEmptyBook({
    required String kidId,
    required String parentId,
    required String title,
    required int spreadCount,
    KidStorybookPageFormat pageFormat = KidStorybookPageFormat.landscape,
  }) async {
    if (spreadCount < 1) {
      throw ArgumentError('spreadCount skal være mindst 1');
    }
    String bookId;
    try {
      final ins = await _client
          .from('kid_story_books')
          .insert({
            'kid_id': kidId,
            'parent_id': parentId,
            'title': title,
            'page_format': pageFormat.dbValue,
          })
          .select('id')
          .single();
      bookId = ins['id'] as String;
    } catch (e) {
      if (_isMissingColumn(e, 'page_format')) {
        final ins = await _client
            .from('kid_story_books')
            .insert({
              'kid_id': kidId,
              'parent_id': parentId,
              'title': title,
            })
            .select('id')
            .single();
        bookId = ins['id'] as String;
      } else {
        rethrow;
      }
    }
    final rows = <Map<String, dynamic>>[];
    for (var i = 0; i < spreadCount; i++) {
      rows.add({
        'book_id': bookId,
        'spread_index': i,
        'left_text': '',
        'right_image_url': null,
      });
    }
    await _client.from('kid_story_book_pages').insert(rows);
    return bookId;
  }

  static Future<void> saveFullBook({
    required String bookId,
    required String title,
    required List<Map<String, dynamic>> pages,
  }) async {
    await _client.from('kid_story_books').update({
      'title': title,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', bookId);

    Future<void> deleteAllPages() async {
      final existing = await _client
          .from('kid_story_book_pages')
          .select('id')
          .eq('book_id', bookId);
      for (final row in existing as List) {
        await _client
            .from('kid_story_book_pages')
            .delete()
            .eq('id', (row as Map)['id'] as String);
      }
    }

    Future<void> insertLoop(
      bool withTextStyle,
      bool withPageLayout,
    ) async {
      for (var i = 0; i < pages.length; i++) {
        final p = pages[i];
        final row = <String, dynamic>{
          'book_id': bookId,
          'spread_index': i,
          'left_text': p['left_text'] ?? '',
          'right_image_url': p['right_image_url'],
        };
        if (withTextStyle) {
          final fs = p['text_font_size'];
          if (fs is num) {
            row['text_font_size'] = fs.toDouble();
          } else {
            row['text_font_size'] = null;
          }
          final fk = p['text_font_key'] as String?;
          if (fk != null && fk.trim().isNotEmpty) {
            row['text_font_key'] = fk.trim();
          } else {
            row['text_font_key'] = null;
          }
        }
        if (withPageLayout) {
          final pl = p['page_layout'];
          if (pl != null) {
            if (pl is Map) {
              row['page_layout'] = Map<String, dynamic>.from(pl);
            } else if (pl is String && pl.trim().isNotEmpty) {
              final dec = jsonDecode(pl);
              if (dec is Map) {
                row['page_layout'] = Map<String, dynamic>.from(dec);
              }
            }
          }
        }
        await _client.from('kid_story_book_pages').insert(row);
      }
    }

    bool missingPageSchemaColumn(Object e) {
      return _isMissingColumn(e, 'text_font_size') ||
          _isMissingColumn(e, 'text_font_key') ||
          _isMissingColumn(e, 'page_layout');
    }

    await deleteAllPages();
    try {
      await insertLoop(true, true);
    } catch (e) {
      if (!missingPageSchemaColumn(e)) rethrow;
      debugPrint(
        'KidStorybookService.saveFullBook: uden page_layout/tekststil (migrering?): $e',
      );
      await deleteAllPages();
      try {
        await insertLoop(true, false);
      } catch (e2) {
        if (!missingPageSchemaColumn(e2)) rethrow;
        debugPrint(
          'KidStorybookService.saveFullBook: uden tekststil: $e2',
        );
        await deleteAllPages();
        await insertLoop(false, false);
      }
    }
  }

  /// Sletter en barnets bog og tilhørende sider (cascade).
  static Future<void> deleteKidBook({
    required String bookId,
    required String kidId,
  }) async {
    try {
      await _client
          .from('kid_story_books')
          .delete()
          .eq('id', bookId)
          .eq('kid_id', kidId);
    } catch (e) {
      if (e is PostgrestException && _isMissingKidStoryTable(e)) {
        throw StateError('Bog-tabellen findes ikke');
      }
      rethrow;
    }
  }

  static Future<String> uploadUserImage(
    String kidId,
    String fileName,
    List<int> bytes, {
    String? filePath,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('Ikke logget ind');
    }
    final ext = _extFromFileName(fileName);
    final key =
        'kid_uploads/${user.id}/kid_${kidId}_${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(1 << 20)}$ext';
    var data = bytes;
    if (data.isEmpty && filePath != null) {
      data = await file_reader.readFileBytes(filePath);
    }
    if (data.isEmpty) {
      throw StateError('Tom billedfil');
    }
    await _client.storage.from(_bookImagesBucket).uploadBinary(
          key,
          data is Uint8List ? data : Uint8List.fromList(data),
          fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
        );
    return _client.storage.from(_bookImagesBucket).getPublicUrl(key);
  }

  static Future<Uint8List> buildPrintablePdf({
    required String title,
    required List<Map<String, dynamic>> pages,
  }) async {
    final doc = pw.Document();

    for (var i = 0; i < pages.length; i++) {
      final p = pages[i];
      final text = (p['left_text'] as String? ?? '').trim();
      final img = (p['right_image_url'] as String? ?? '').trim();
      final label = 'Side ${i + 1}';
      final fs0 = (p['text_font_size'] as num?)?.toDouble() ?? 12.0;
      final fk0 = p['text_font_key'] as String?;

      final pageItems = KidStorybookPageItem.fromStoredPage(
        pageLayoutRaw: p['page_layout'],
        leftText: p['left_text'] as String? ?? '',
        rightImageUrl: p['right_image_url'] as String?,
        textFontSize: fs0,
        textFontKey: fk0,
      );

      final imageBytesByUrl = <String, Uint8List>{};
      if (pageItems.isNotEmpty) {
        final seen = <String>{};
        for (final it in pageItems) {
          if (!it.isImage) continue;
          final u = (it.imageUrl ?? '').trim();
          if (u.isEmpty || seen.contains(u)) continue;
          seen.add(u);
          try {
            final r = await http.get(Uri.parse(u));
            if (r.statusCode == 200 && r.bodyBytes.isNotEmpty) {
              imageBytesByUrl[u] = r.bodyBytes;
            }
          } catch (_) {}
        }
      }

      Uint8List? memBytes;
      if (pageItems.isEmpty && img.isNotEmpty) {
        try {
          final r = await http.get(Uri.parse(img));
          if (r.statusCode == 200 && r.bodyBytes.isNotEmpty) {
            memBytes = r.bodyBytes;
          }
        } catch (_) {}
      }

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(32),
          build: (ctx) {
            const contentW = 750.0;
            const contentH = 400.0;

            if (pageItems.isNotEmpty) {
              final stackChildren = <pw.Widget>[];
              for (final it in pageItems) {
                if (it.isImage) {
                  final u = (it.imageUrl ?? '').trim();
                  final b = u.isNotEmpty ? imageBytesByUrl[u] : null;
                  if (b == null) continue;
                  final iW = (contentW * 0.4 * it.scale)
                      .clamp(20.0, contentW * 1.2);
                  final iH = iW * 0.75;
                  stackChildren.add(
                    pw.Positioned(
                      left: contentW * it.cx - iW / 2,
                      top: contentH * it.cy - iH / 2,
                      child: pw.SizedBox(
                        width: iW,
                        height: iH,
                        child: pw.Image(
                          pw.MemoryImage(b),
                          fit: it.imageFullBleed
                              ? pw.BoxFit.cover
                              : pw.BoxFit.contain,
                        ),
                      ),
                    ),
                  );
                } else if (it.isText) {
                  final t0 = (it.text ?? '').trim();
                  if (t0.isEmpty) continue;
                  final s = ((it.textFontSize ?? 12) * it.scale)
                      .clamp(6.0, 120.0);
                  stackChildren.add(
                    pw.Positioned(
                      left: (contentW * it.cx - contentW * 0.4)
                          .clamp(0.0, contentW * 0.3),
                      top: (contentH * it.cy - 32).clamp(0.0, contentH * 0.88),
                      child: pw.SizedBox(
                        width: contentW * 0.8,
                        child: pw.Text(
                          t0,
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(fontSize: s),
                        ),
                      ),
                    ),
                  );
                } else if (it.isFigure) {
                  final w = _pdfDecorationPositioned(
                    it.decoration,
                    contentW,
                    contentH,
                  );
                  if (w != null) stackChildren.add(w);
                }
              }
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Text(
                    title,
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
                  pw.SizedBox(height: 8),
                  pw.SizedBox(
                    width: contentW,
                    height: contentH,
                    child: pw.Stack(children: stackChildren),
                  ),
                ],
              );
            }

            final fs = (p['text_font_size'] as num?)?.toDouble() ?? 12.0;
            final textBox = pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Text(
                text.isEmpty ? ' ' : text,
                style: pw.TextStyle(
                  fontSize: fs.clamp(8, 120),
                ),
              ),
            );
            final rawLayout = p['page_layout'];
            final pageLayout = rawLayout != null
                ? KidStorybookPageLayout.fromDb(rawLayout)
                : null;
            if (pageLayout != null &&
                (text.isNotEmpty ||
                    memBytes != null ||
                    pageLayout.decoration != null)) {
              final tfs = (p['text_font_size'] as num?)?.toDouble() ?? 12.0;
              final sText = (tfs.clamp(8, 300) * pageLayout.textScale)
                  .clamp(6.0, 160.0);
              final iW = (contentW * 0.4 * pageLayout.imageScale)
                  .clamp(20.0, contentW * 1.2);
              final iH = iW * 0.75;
              final decPdf = _pdfDecorationPositioned(
                pageLayout.decoration,
                contentW,
                contentH,
              );
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Text(
                    title,
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
                  pw.SizedBox(height: 8),
                  pw.SizedBox(
                    width: contentW,
                    height: contentH,
                    child: pw.Stack(
                      children: [
                        if (memBytes != null)
                          pw.Positioned(
                            left: contentW * pageLayout.imageCx - iW / 2,
                            top: contentH * pageLayout.imageCy - iH / 2,
                            child: pw.SizedBox(
                              width: iW,
                              height: iH,
                              child: pw.Image(
                                pw.MemoryImage(memBytes),
                                fit: pw.BoxFit.contain,
                              ),
                            ),
                          ),
                        if (text.isNotEmpty)
                          pw.Positioned(
                            left: contentW * pageLayout.textCx - contentW * 0.4,
                            top: contentH * 0.05,
                            child: pw.SizedBox(
                              width: contentW * 0.8,
                              child: pw.Text(
                                text,
                                textAlign: pw.TextAlign.center,
                                style: pw.TextStyle(fontSize: sText),
                              ),
                            ),
                          ),
                        ?decPdf,
                      ],
                    ),
                  ),
                ],
              );
            }
            final imageWidget = memBytes == null
                ? null
                : pw.Expanded(
                    child: pw.Image(
                      pw.MemoryImage(memBytes),
                      fit: pw.BoxFit.contain,
                    ),
                  );
            final rowImg = imageWidget;
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Text(
                  title,
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
                pw.SizedBox(height: 8),
                pw.Expanded(
                  child: rowImg == null
                      ? textBox
                      : pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                          children: [
                            pw.Expanded(flex: 1, child: textBox),
                            pw.SizedBox(width: 12),
                            pw.Expanded(flex: 1, child: rowImg),
                          ],
                        ),
                ),
              ],
            );
          },
        ),
      );
    }

    return doc.save();
  }

  static Future<void> showPrintDialogForPdf(Uint8List bytes) {
    return Printing.layoutPdf(
      onLayout: (_) async => bytes,
    );
  }
}

/// Gør barnets bog synlig i hovedbiblioteket (top-level — bruges fra UI; undgår at
/// nogle analyser ikke ser en statisk metode på [KidStorybookService]).
Future<void> publishKidBookToLibrary({
  required String bookId,
  required String kidId,
}) async {
  final client = Supabase.instance.client;
  try {
    await client.from('kid_story_books').update({
      'published_to_library': true,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', bookId).eq('kid_id', kidId);
  } catch (e) {
    if (KidStorybookService._isMissingColumn(e, 'published_to_library')) {
      throw StateError(
        'Kør database-migrering: kid_story_books.published_to_library',
      );
    }
    rethrow;
  }
}

/// Ekstra upload til admin (peger på [book_builder_extra] mappe + række).
class BookBuilderAlfamonImageService {
  BookBuilderAlfamonImageService._();

  static final _client = Supabase.instance.client;
  static const _bucket = _bookImagesBucket;

  static Future<void> addExtraForAvatar(
    String avatarId,
    String fileName,
    List<int> bytes, {
    String? filePath,
  }) async {
    var data = bytes;
    if (data.isEmpty && filePath != null) {
      data = await file_reader.readFileBytes(filePath);
    }
    if (data.isEmpty) throw StateError('Tom fil');
    final ext = _extFromFileName(fileName);
    final key =
        'book_builder_extra/$avatarId/${DateTime.now().millisecondsSinceEpoch}$ext';
    await _client.storage.from(_bucket).uploadBinary(
          key,
          data is Uint8List ? data : Uint8List.fromList(data),
          fileOptions: FileOptions(upsert: true),
        );
    final url = _client.storage.from(_bucket).getPublicUrl(key);
    await _client.from('book_builder_extra_images').insert({
      'avatar_id': avatarId,
      'image_url': url,
      'sort_order': 100,
    });
  }

  static Future<List<Map<String, dynamic>>> listExtras(String avatarId) async {
    final res = await _client
        .from('book_builder_extra_images')
        .select('id, image_url, sort_order')
        .eq('avatar_id', avatarId)
        .order('sort_order');
    return (res as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  static Future<void> deleteExtra(String id) async {
    await _client.from('book_builder_extra_images').delete().eq('id', id);
  }
}
