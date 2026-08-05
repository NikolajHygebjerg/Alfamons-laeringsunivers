import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../services/kid_storybook_service.dart';
import '../../../utils/alfamon_display_name.dart';
import '../../../utils/card_assets.dart';
import '../../../widgets/asset_or_network_image.dart';

/// Samme rækkefølge som [KidAlfamonsScreen] (dansk a–å).
const kDanishAlphabetLetters = 'abcdefghijklmnopqrstuvwxyzæøå';

String? _firstDisplaySrcForAvatar(
  Map<String, dynamic> avatar,
  Map<String, String> idToUrl,
) {
  final id = avatar['id'] as String? ?? '';
  final u = (idToUrl[id] ?? '').trim();
  if (u.isNotEmpty) return u;
  final name = alfamonDisplayName(avatar['name'] as String? ?? 'Alfamon');
  final letter = avatar['letter'] as String?;
  for (final p in CardAssets.getCardImagePathsToTry(name, 0, letter: letter)) {
    return p;
  }
  return null;
}

String _avatarSemanticsLabel(String? nameFromRow, String letter) {
  final t = alfamonDisplayName(nameFromRow);
  return t.isNotEmpty ? t : 'Alfamon for $letter';
}

/// Bogstav-gitter med billeder (som skattekistens «Alfamons»-side), til bogbyggeren.
class AlfamonStorybookLetterPicker extends StatefulWidget {
  const AlfamonStorybookLetterPicker({
    super.key,
    required this.avatars,
    required this.onAvatarSelected,
  });

  final List<Map<String, dynamic>> avatars;
  final ValueChanged<String> onAvatarSelected;

  @override
  State<AlfamonStorybookLetterPicker> createState() =>
      _AlfamonStorybookLetterPickerState();
}

class _AlfamonStorybookLetterPickerState
    extends State<AlfamonStorybookLetterPicker> {
  Future<Map<String, String>>? _thumbFuture;

  @override
  void initState() {
    super.initState();
    final ids = widget.avatars
        .map((a) => a['id'] as String? ?? '')
        .where((e) => e.isNotEmpty)
        .toList();
    _thumbFuture = KidStorybookService.avatarIdToFirstStageImageUrl(ids);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, String>>(
      future: _thumbFuture,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(48),
              child: CircularProgressIndicator(color: Colors.white),
            ),
          );
        }
        final idToUrl = snap.data ?? {};
        final byLetter = <String, Map<String, dynamic>>{};
        for (final a in widget.avatars) {
          final L = (a['letter'] as String? ?? '').toLowerCase().trim();
          if (L.isEmpty) continue;
          byLetter.putIfAbsent(L, () => a);
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: SvgPicture.asset(
                'assets/alfamonbaggrund.svg',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const ColoredBox(color: Color(0xFF3E4A5C)),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text(
                      'Vælg Alfamon',
                      style: TextStyle(
                        fontSize: MediaQuery.of(context).size.shortestSide >= 600
                            ? 24
                            : 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        shadows: const [
                          Shadow(
                            blurRadius: 6,
                            color: Colors.black54,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                    child: Text(
                      'Bogstaverne står i alfabetisk rækkefølge – tryk på en Alfamon.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        shadows: [
                          Shadow(
                            blurRadius: 4,
                            color: Colors.black54,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: _LetterGrid(
                      byLetter: byLetter,
                      idToUrl: idToUrl,
                      onPick: widget.onAvatarSelected,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LetterGrid extends StatelessWidget {
  const _LetterGrid({
    required this.byLetter,
    required this.idToUrl,
    required this.onPick,
  });

  final Map<String, Map<String, dynamic>> byLetter;
  final Map<String, String> idToUrl;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    const letterCount = 29;
    const gap = 5.0;
    const gridPad = 8.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth - 2 * gridPad;
        final maxH = constraints.maxHeight - 2 * gridPad;
        if (maxW <= 0 || maxH <= 0) {
          return const SizedBox.shrink();
        }

        var bestCols = 6;
        var bestCell = 0.0;
        for (var c = 5; c <= 12; c++) {
          final r = (letterCount + c - 1) ~/ c;
          final sW = (maxW - (c - 1) * gap) / c;
          final sH = (maxH - (r - 1) * gap) / r;
          final s = math.min(sW, sH);
          if (s > bestCell) {
            bestCell = s;
            bestCols = c;
          }
        }
        final rows = (letterCount + bestCols - 1) ~/ bestCols;
        bestCell = bestCell.clamp(36.0, 120.0);
        if (rows * bestCell + (rows - 1) * gap > maxH) {
          bestCell = (maxH - (rows - 1) * gap) / rows;
        }
        if (bestCols * bestCell + (bestCols - 1) * gap > maxW) {
          bestCell = (maxW - (bestCols - 1) * gap) / bestCols;
        }
        bestCell = math.max(32.0, bestCell);
        final cols = bestCols;
        final letters = kDanishAlphabetLetters.split('');

        return Padding(
          padding: const EdgeInsets.all(gridPad),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: List.generate(rows, (r) {
                final start = r * cols;
                final end = math.min(start + cols, letters.length);
                return Padding(
                  padding: EdgeInsets.only(bottom: r < rows - 1 ? gap : 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = start; i < end; i++)
                        Padding(
                          padding: EdgeInsets.only(
                            right: i < end - 1 ? gap : 0,
                          ),
                          child: _AlfamonBookLetterCell(
                            letter: letters[i],
                            avatar: byLetter[letters[i]],
                            idToUrl: idToUrl,
                            cell: bestCell,
                            onPick: onPick,
                          ),
                        ),
                    ],
                  ),
                );
              }),
            ),
          ),
        );
      },
    );
  }
}

class _AlfamonBookLetterCell extends StatelessWidget {
  const _AlfamonBookLetterCell({
    required this.letter,
    required this.avatar,
    required this.idToUrl,
    required this.cell,
    required this.onPick,
  });

  final String letter;
  final Map<String, dynamic>? avatar;
  final Map<String, String> idToUrl;
  final double cell;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final a = avatar;
    final hasAvatar = a != null;
    final id = a?['id'] as String?;
    final displaySrc = hasAvatar && id != null
        ? _firstDisplaySrcForAvatar(a, idToUrl)
        : null;
    final rad = math.max(6.0, cell * 0.12);
    final badg = math.max(7.0, cell * 0.22);

    return Semantics(
      label: hasAvatar
          ? _avatarSemanticsLabel(avatar!['name'] as String?, letter)
          : 'Ingen Alfamon for ${letter.toUpperCase()}',
      button: hasAvatar,
      child: SizedBox(
        width: cell,
        height: cell,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: hasAvatar && id != null
                ? () => onPick(id)
                : null,
            borderRadius: BorderRadius.circular(rad),
            child: Container(
              decoration: BoxDecoration(
                color: hasAvatar
                    ? Colors.green.shade400
                    : const Color(0xFFF9C433),
                borderRadius: BorderRadius.circular(rad),
                border: Border.all(
                  color: hasAvatar
                      ? Colors.green.shade600
                      : Colors.grey.shade300,
                  width: 2,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (hasAvatar &&
                      displaySrc != null &&
                      displaySrc.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(rad - 2),
                      child: AssetOrNetworkImage(
                        src: displaySrc,
                        fit: BoxFit.cover,
                      ),
                    )
                  else if (!hasAvatar)
                    Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          letter.toUpperCase(),
                          style: TextStyle(
                            fontSize: math.min(cell * 0.55, 36),
                            fontWeight: FontWeight.w900,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    )
                  else
                    Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          letter.toUpperCase(),
                          style: TextStyle(
                            fontSize: cell * 0.32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  if (hasAvatar)
                    Positioned(
                      top: math.max(2.0, cell * 0.04),
                      left: math.max(2.0, cell * 0.04),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: math.max(3.0, cell * 0.06),
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          letter.toUpperCase(),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: badg,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
