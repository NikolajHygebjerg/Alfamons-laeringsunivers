/// Resolver for tale-lydfiler (m4a).
/// Bruger KUN filer der findes i assets – ingen opfundne navne.
class TaleAssets {
  /// Bogstav (a-å) -> faktisk filnavn i assets (kun filer der findes)
  static const Map<String, String> _letterToFile = {
    'a': 'Atiachtale2.m4a',
    'b': 'Bezzletale2.m4a',
    'c': 'Cekimostale2.m4a',
    'g': 'Gemibulltale2.m4a',
    'h': 'Haaghaitale2.m4a',
    'i': 'Iffletale2.m4a',
    'j': 'Jaadriktale2.m4a',
    'k': 'Kaavaxtale2.m4a',
    'l': 'Lmitale2.m4a',
    'm': 'maxtortale2.m4a',
    'n': 'Nimbrootale2.m4a',
    'o': 'Oodlobtale2.m4a',
    'p': 'Peppapoptale1.m4a',
    'q': 'Quiblytale2.m4a',
    'r': 'Rminaxtale2.m4a',
    's': 'Snaketale2.m4a',
    't': 'Tegormtale2.m4a',
    'u': 'Ummirootale2.m4a',
    'v': 'Vindleektale2.m4a',
    'w': 'Wiglootale2.m4a',
    'x': 'Xbugtale2.m4a',
    'y': 'Yglifaxtale2.m4a',
    'z': 'Zetbratale2.m4a',
    'æ': 'Aelgortale2.m4a',
    'ø': 'Oegleontale2.m4a',
    'å': 'Aarmoktale2.m4a',
  };

  /// Avatar-navn (lowercase) -> faktisk filnavn (kun filer der findes)
  static const Map<String, String> _nameToFile = {
    'atiach': 'Atiachtale2.m4a',
    'abbas': 'Atiachtale2.m4a',
    'aelgor': 'Aelgortale2.m4a',
    'aarmok': 'Aarmoktale2.m4a',
    'armok': 'Aarmoktale2.m4a',
    'bezzle': 'Bezzletale2.m4a',
    'cekimon': 'Cekimostale2.m4a',
    'cekimos': 'Cekimostale2.m4a',
    'gemibull': 'Gemibulltale2.m4a',
    'gemitsui': 'Gemibulltale2.m4a',
    'haaghai': 'Haaghaitale2.m4a',
    'hakkul': 'Haaghaitale2.m4a',
    'iffle': 'Iffletale2.m4a',
    'jaadrik': 'Jaadriktale2.m4a',
    'jadrik': 'Jaadriktale2.m4a',
    'kavax': 'Kaavaxtale2.m4a',
    'kåvax': 'Kaavaxtale2.m4a',
    'lmi': 'Lmitale2.m4a',
    'l-mii': 'Lmitale2.m4a',
    'maxtor': 'maxtortale2.m4a',
    'nimbroo': 'Nimbrootale2.m4a',
    'oodlob': 'Oodlobtale2.m4a',
    'oglah': 'Oodlobtale2.m4a',
    'oegleon': 'Oegleontale2.m4a',
    'peppapop': 'Peppapoptale1.m4a',
    'quibbly': 'Quiblytale2.m4a',
    'rminax': 'Rminaxtale2.m4a',
    'snake': 'Snaketale2.m4a',
    's-nake': 'Snaketale2.m4a',
    'tegorm': 'Tegormtale2.m4a',
    'ummiroo': 'Ummirootale2.m4a',
    'vindloo': 'Vindleektale2.m4a',
    'vindleek': 'Vindleektale2.m4a',
    'wigloo': 'Wiglootale2.m4a',
    'wiglook': 'Wiglootale2.m4a',
    'x-bug': 'Xbugtale2.m4a',
    'xbug': 'Xbugtale2.m4a',
    'yglifax': 'Yglifaxtale2.m4a',
    'zetbra': 'Zetbratale2.m4a',
    'zebra': 'Zetbratale2.m4a',
  };

  /// Returnerer asset-path for tale-lyd (f.eks. 'assets/Atiachtale2.m4a').
  /// Bruger kun filer der findes i assets. stageIndex ignoreres – vi bruger den fil vi har.
  static String? getTaleAssetPath(String avatarName, int stageIndex, {String? letter}) {
    String? file;

    if (letter != null && letter.isNotEmpty) {
      file = _letterToFile[letter.toLowerCase().trim()];
    }
    if (file == null) {
      final nameKey = avatarName.toLowerCase().trim();
      file = _nameToFile[nameKey];
    }
    if (file == null && avatarName.isNotEmpty) {
      final first = avatarName.toLowerCase().trim()[0];
      file = _letterToFile[first];
    }

    if (file == null) return null;
    return 'assets/$file';
  }
}
