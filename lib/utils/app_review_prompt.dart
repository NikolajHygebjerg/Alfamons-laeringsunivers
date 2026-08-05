import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_store_listing_config.dart';

const _kPrefsVisits = 'app_review_kid_select_visits';
const _kPrefsLastPromptMs = 'app_review_last_prompt_ms';
const _kPrefsNever = 'app_review_never_ask_again';

/// Hvor mange gange forælderen har nået barn-valg (med mindst ét barn) før vi må spørge.
const int kAppReviewAfterVisits = 3;

/// Mindst så mange dage mellem to opfordringer, hvis brugeren valgte «Senere».
const int kAppReviewMinDaysBetweenPrompts = 90;

/// Kaldes én gang efter [KidSelectScreen] har hentet børn (fx i postFrameCallback).
Future<void> showAppReviewPromptIfEligible(BuildContext context) async {
  if (kIsWeb) return;
  if (!context.mounted) return;
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(_kPrefsNever) == true) return;

  var visits = prefs.getInt(_kPrefsVisits) ?? 0;
  visits += 1;
  await prefs.setInt(_kPrefsVisits, visits);
  if (visits < kAppReviewAfterVisits) return;

  final lastMs = prefs.getInt(_kPrefsLastPromptMs);
  if (lastMs != null) {
    final last = DateTime.fromMillisecondsSinceEpoch(lastMs);
    if (DateTime.now().difference(last).inDays < kAppReviewMinDaysBetweenPrompts) {
      return;
    }
  }

  if (!context.mounted) return;
  final theme = Theme.of(context);
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return AlertDialog(
        title: const Text('Hvad synes du om appen?'),
        content: const Text(
          'Din stjerne i butikken (App Store / Google Play) hjælper andre forældre med at finde Alfamons lektiehelte.',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await prefs.setBool(_kPrefsNever, true);
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('Spørg ikke igen'),
          ),
          TextButton(
            onPressed: () async {
              final now = DateTime.now().millisecondsSinceEpoch;
              await prefs.setInt(_kPrefsLastPromptMs, now);
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('Senere'),
          ),
          FilledButton(
            onPressed: () async {
              final now = DateTime.now().millisecondsSinceEpoch;
              await prefs.setInt(_kPrefsLastPromptMs, now);
              if (ctx.mounted) Navigator.of(ctx).pop();
              if (!context.mounted) return;
              await _openStoreReview();
            },
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
            ),
            child: const Text('Bedøm appen'),
          ),
        ],
      );
    },
  );
}

Future<void> _openStoreReview() async {
  final inApp = InAppReview.instance;
  final id = kIosAppStoreAppleId.trim();
  if (defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS) {
    if (id.isNotEmpty) {
      await inApp.openStoreListing(appStoreId: id);
    } else {
      if (await inApp.isAvailable()) {
        await inApp.requestReview();
      }
    }
    return;
  }
  if (defaultTargetPlatform == TargetPlatform.android) {
    await inApp.openStoreListing();
  }
}
