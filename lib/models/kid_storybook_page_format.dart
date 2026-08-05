/// Format for barnets bog (ét valg per bog ved oprettelse).
enum KidStorybookPageFormat {
  /// Lodret — billedområde højere end bredt.
  portrait,

  /// Vandret — billedområde bredere end højt.
  landscape,

  /// Kvadratisk.
  square,
}

extension KidStorybookPageFormatX on KidStorybookPageFormat {
  /// Billedes [AspectRatio] (width / height) i byggerens «Billede»-felt.
  double get imageAspectWidthOverHeight {
    return switch (this) {
      KidStorybookPageFormat.portrait => 3 / 4,
      KidStorybookPageFormat.landscape => 4 / 3,
      KidStorybookPageFormat.square => 1,
    };
  }

  String get dbValue => switch (this) {
        KidStorybookPageFormat.portrait => 'portrait',
        KidStorybookPageFormat.landscape => 'landscape',
        KidStorybookPageFormat.square => 'square',
      };

  String get displayLabelDanish {
    return switch (this) {
      KidStorybookPageFormat.portrait => 'Lodret',
      KidStorybookPageFormat.landscape => 'Vandret',
      KidStorybookPageFormat.square => 'Kvadratisk',
    };
  }

  static KidStorybookPageFormat fromDb(String? raw) {
    final s = (raw ?? 'landscape').toLowerCase().trim();
    return switch (s) {
      'portrait' => KidStorybookPageFormat.portrait,
      'square' => KidStorybookPageFormat.square,
      _ => KidStorybookPageFormat.landscape,
    };
  }
}
