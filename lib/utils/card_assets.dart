/// Resolver for lokale kort-SVG'er i assets. Format: {Navn}kort{1-4}.svg
/// Eksempel: Ifflekort1, Ifflekort2, Atiachkort1, osv.
/// Bruger både avatar-navn og bogstav (a-å) til lookup.
class CardAssets {
  /// Bogstav (a-å) -> asset base. Dansk alfabet: a,b,c,...,z,æ,ø,å
  static const Map<String, String> _letterToAssetBase = {
    'a': 'Atiachkort',
    'b': 'Bezzlekort',
    'c': 'Cekimoskort',
    'd': 'Dedookort',
    'e': 'Ellabookort',
    'f': 'Flizardkort',
    'g': 'Gemibullkort',
    'h': 'haaghaikort',
    'i': 'Ifflekort',
    'j': 'Jaadrikkort',
    'k': 'Kåvaxkort',
    'l': 'lmikort',
    'm': 'Maxtorkort',
    'n': 'Nimbrookort',
    'o': 'oodlobkort',
    'p': 'Peppapopkort',
    'q': 'Quibblykort',
    'r': 'Rminaxkort',
    's': 'snakekort',
    't': 'Tegormkort',
    'u': 'Ummirookort',
    'v': 'Vindlookort',
    'w': 'wiglookort',
    'x': 'X-bugkort',
    'y': 'Yglifaxkort',
    'z': 'Zetbrakort',
    'æ': 'Aelgorkort',
    'ø': 'Oegleonkort',
    'å': 'Aarmokkort',
  };

  /// Avatar-navn (lowercase) -> asset base (uden stage). Stage 1-4 tilføjes.
  static const Map<String, String> _nameToAssetBase = {
    'iffle': 'Ifflekort',
    'atiach': 'Atiachkort',
    'aelgor': 'Aelgorkort',
    'bezzle': 'Bezzlekort',
    'cekimon': 'Cekimoskort',
    'cekimos': 'Cekimoskort',
    'deedoo': 'Dedookort',
    'dedoo': 'Dedookort',
    'elisboo': 'Ellabookort',
    'ellaboo': 'Ellabookort',
    'flizard': 'Flizardkort',
    'f-lizard': 'Flizardkort',
    'gemitsui': 'Gemibullkort',
    'gemitsull': 'Gemibullkort',
    'hakkul': 'haaghaikort',
    'haaghai': 'haaghaikort',
    'irile': 'Ifflekort',
    'jadrik': 'Jaadrikkort',
    'jaadrik': 'Jaadrikkort',
    'kåvax': 'Kåvaxkort',
    'kavax': 'Kåvaxkort',
    'l-mii': 'lmikort',
    'lmi': 'lmikort',
    'l-titi': 'lmikort',
    'master': 'Maxtorkort',
    'm-astar': 'Maxtorkort',
    'maxtor': 'Maxtorkort',
    'nimbroo': 'Nimbrookort',
    'oglah': 'oodlobkort',
    'oqlen': 'oodlobkort',
    'oodlob': 'oodlobkort',
    'odiab': 'oodlobkort',
    'peppapop': 'Peppapopkort',
    'quibbly': 'Quibblykort',
    'quibbty': 'Quibblykort',
    'r-minax': 'Rminaxkort',
    'rminax': 'Rminaxkort',
    's-nake': 'snakekort',
    's-nalo': 'snakekort',
    's-males': 'snakekort',
    'snake': 'snakekort',
    'tegorm': 'Tegormkort',
    'tagorm': 'Tegormkort',
    'ummiroo': 'Ummirookort',
    'vindleak': 'Vindlookort',
    'windioo': 'Vindlookort',
    'vindloo': 'Vindlookort',
    'wigloo': 'wiglookort',
    'wiglook': 'wiglookort',
    'x-bug': 'X-bugkort',
    'yalfax': 'Yglifaxkort',
    'yglifax': 'Yglifaxkort',
    'zebra': 'Zetbrakort',
    'zetbra': 'Zetbrakort',
    'armok': 'Aarmokkort',
    'aarmok': 'Aarmokkort',
    'oegleon': 'Oegleonkort',
    'bazzle': 'Bezzlekort',
    'bazzie': 'Bezzlekort',
    'apego': 'Bezzlekort',
    'adonis': 'Bezzlekort',
    'aerios': 'Dedookort',
    'abbas': 'Atiachkort',
  };

  /// Overrides for filer med afvigende navne (case, typo)
  static const Map<String, String> _pathOverrides = {
    'assets/Nimbrookort2.svg': 'assets/Nimbrookort2¨.svg',
    'assets/Aelgorkort3.svg': 'assets/aelgorkort3.svg',
    'assets/Aelgorkort4.svg': 'assets/aelgorkort4.svg',
  };

  /// Returnerer asset-path for kort (f.eks. 'assets/Ifflekort1.svg') eller null.
  /// stageIndex: 1-4 (bruges direkte). Hvis 0, bruges 1.
  /// letter: valgfri fallback når navn ikke matcher (a-å).
  static String? getCardAssetPath(String avatarName, int stageIndex, {String? letter}) {
    final stage = stageIndex.clamp(1, 4);
    String? base;

    final nameKey = avatarName.toLowerCase().trim();
    base = _nameToAssetBase[nameKey];

    if (base == null && letter != null && letter.isNotEmpty) {
      base = _letterToAssetBase[letter.toLowerCase().trim()];
    }

    if (base == null) return null;
    final path = 'assets/${base}$stage.svg';
    return _pathOverrides[path] ?? path;
  }
}
