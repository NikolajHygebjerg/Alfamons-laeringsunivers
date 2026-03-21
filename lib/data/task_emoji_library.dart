/// Kategoriseret emoji-bibliotek til opgavetildeling (voksen vælger ét tegn).
class TaskEmojiCategory {
  const TaskEmojiCategory({
    required this.title,
    required this.emojis,
  });

  final String title;
  final List<String> emojis;
}

/// Omfattende bibliotek – grupperet så forældre hurtigt finder relevant type opgave.
const List<TaskEmojiCategory> kTaskEmojiCategories = [
  TaskEmojiCategory(
    title: 'Hygiejne & krop',
    emojis: [
      '🦷', '🪥', '🧼', '🧴', '🚿', '🛁', '🧽', '🧹', '💅', '🤲', '👐', '🙌', '👏', '🤝',
      '🚽', '🧻', '💧', '🧊', '☀️', '🌡️', '💊', '🩹', '🤧', '😷', '🥽',
    ],
  ),
  TaskEmojiCategory(
    title: 'Mad & køkken',
    emojis: [
      '🍽️', '🥄', '🍴', '🥤', '🧃', '🍼', '🍎', '🍌', '🍇', '🍓', '🥕', '🥦', '🍞', '🥐',
      '🧀', '🥚', '🍳', '🥗', '🍝', '🍕', '🥪', '🌮', '🍪', '🎂', '☕', '🫖', '🧂', '🔪',
    ],
  ),
  TaskEmojiCategory(
    title: 'Skole & læring',
    emojis: [
      '📚', '📖', '📝', '✏️', '🖊️', '📐', '📏', '🧮', '🔢', '🔤', '🔡', '🎒', '🏫', '👩‍🏫',
      '👨‍🏫', '🧑‍🎓', '👩‍🎓', '👨‍🎓', '🌍', '🗺️', '🔬', '🧪', '📊', '💡', '🧠', '❓', '❗',
    ],
  ),
  TaskEmojiCategory(
    title: 'Oprydning & hjem',
    emojis: [
      '🛏️', '🛋️', '🪑', '🚪', '🪟', '🧺', '🗑️', '♻️', '📦', '🧸', '🎮', '🕹️', '📺', '💡',
      '🪴', '🖼️', '🧱', '🔑', '🛠️', '🔨', '⚙️', '🧰', '🪣', '🧹', '🧽', '🧴',
    ],
  ),
  TaskEmojiCategory(
    title: 'Motion & udendørs',
    emojis: [
      '🚶', '🏃', '🤸', '🧘', '🚴', '🛴', '🛹', '⚽', '🏀', '🎾', '🏐', '🥏', '🏓', '⛹️',
      '🌳', '🌲', '🌴', '🌷', '🌼', '🌻', '🦋', '🐛', '🪲', '🐞', '🌈', '☁️', '⛅', '🌤️',
    ],
  ),
  TaskEmojiCategory(
    title: 'Musik & sang',
    emojis: [
      '🎵', '🎶', '🎤', '🎧', '🎸', '🎹', '🥁', '🎺', '🎷', '🎻', '🪕', '📻', '🔊', '🔉',
      '💿', '📀', '🎼', '🎭', '🎪', '🎬',
    ],
  ),
  TaskEmojiCategory(
    title: 'Kreativitet & hobby',
    emojis: [
      '🎨', '🖌️', '🖍️', '✂️', '📐', '🧵', '🪡', '🧶', '🎭', '🖼️', '📷', '📸', '🎬', '📽️',
      '🪆', '🧩', '🎯', '🎲', '♟️', '🃏', '🀄', '🎰',
    ],
  ),
  TaskEmojiCategory(
    title: 'Dyr & kæledyr',
    emojis: [
      '🐶', '🐕', '🦮', '🐩', '🐱', '🐈', '🐰', '🐹', '🐭', '🐁', '🐦', '🐤', '🐣', '🐥',
      '🦆', '🐸', '🐢', '🐍', '🐠', '🐟', '🐬', '🐳', '🐴', '🦄', '🐝', '🦋', '🐞', '🪿', '🐓',
    ],
  ),
  TaskEmojiCategory(
    title: 'Familie & følelser',
    emojis: [
      '❤️', '🧡', '💛', '💚', '💙', '💜', '🤍', '🖤', '💕', '💞', '💓', '💗', '💖', '💘',
      '👨‍👩‍👧', '👨‍👩‍👧‍👦', '👨‍👩‍👦', '👩‍👧', '👨‍👦', '👶', '🧒', '👦', '👧', '🧑', '👩', '👨',
      '🤗', '🥰', '😊', '🙂', '🙏', '💪', '✨', '🌟', '⭐',
    ],
  ),
  TaskEmojiCategory(
    title: 'Spil & leg',
    emojis: [
      '🎮', '🕹️', '👾', '🤖', '🎲', '🎯', '🎳', '🎪', '🎠', '🎡', '🎢', '⚽', '🏀', '🏈',
      '⚾', '🥎', '🎾', '🏐', '🏉', '🥏', '🎱', '🪀', '🪁', '🧸', '🃏',
    ],
  ),
  TaskEmojiCategory(
    title: 'Teknologi & skærm',
    emojis: [
      '📱', '☎️', '📞', '💻', '🖥️', '⌨️', '🖱️', '🖨️', '📷', '📹', '📺', '📻', '🔌', '🔋',
      '💾', '💿', '📀', '📡', '🔭', '📲', '🎧',
    ],
  ),
  TaskEmojiCategory(
    title: 'Sport & fitness',
    emojis: [
      '🏋️', '🤼', '🤺', '🏌️', '🏇', '⛷️', '🏂', '🏄', '🚣', '🏊', '🤽', '🧗', '🚵', '🏆',
      '🥇', '🥈', '🥉', '🏅', '🎖️', '⚽', '🏀', '🏐', '🎾', '🏸', '🥊', '🥋', '⛳', '🎿',
    ],
  ),
  TaskEmojiCategory(
    title: 'Søvn & ro',
    emojis: [
      '😴', '🛌', '🛏️', '💤', '🌙', '⭐', '🌟', '✨', '🌠', '🕯️', '🧘', '🪷', '🎐', '🔔',
    ],
  ),
  TaskEmojiCategory(
    title: 'Transport',
    emojis: [
      '🚗', '🚕', '🚌', '🚎', '🏎️', '🚓', '🚑', '🚒', '🚐', '🛻', '🚚', '🚛', '🚜', '🏍️',
      '🛵', '🚲', '🛴', '🚂', '🚆', '🚇', '🚉', '✈️', '🛫', '🛬', '🚀', '⛵', '🚤', '🛶', '🧭',
    ],
  ),
  TaskEmojiCategory(
    title: 'Have & natur',
    emojis: [
      '🌱', '🌿', '☘️', '🍀', '🎍', '🎋', '🍃', '🍂', '🍁', '🌾', '🌵', '🌴', '🌳', '🌲',
      '🪴', '🌷', '🌹', '🥀', '🌺', '🌸', '🌼', '🌻', '💐', '🪻', '🍄', '🪨', '⛰️', '🏔️', '🌊',
    ],
  ),
  TaskEmojiCategory(
    title: 'Tøj & vasketøj',
    emojis: [
      '👕', '👔', '👗', '👘', '🥻', '👚', '👖', '🧥', '🥼', '🧦', '👟', '👞', '👠', '👡',
      '🧢', '👒', '🎩', '🧳', '👜', '👛', '🎒', '🧺', '🪮',
    ],
  ),
  TaskEmojiCategory(
    title: 'Pligter & mål',
    emojis: [
      '✅', '☑️', '✔️', '📋', '📌', '📍', '🎯', '⏰', '⏱️', '⌛', '⏳', '🗓️', '📅', '📆',
      '🎁', '🏆', '🥇', '💯', '🔔', '📣', '📢', '✨', '🌟', '💪', '🙌', '👍', '👏',
    ],
  ),
  TaskEmojiCategory(
    title: 'Sæson & fest',
    emojis: [
      '🎄', '🎅', '🤶', '🧑‍🎄', '🎁', '🎆', '🎇', '🧨', '✨', '🎊', '🎉', '🎈', '🎃', '🦃',
      '🐣', '🐰', '🥚', '🍫', '🎂', '🍰', '🥳', '🎭', '🎪',
    ],
  ),
  TaskEmojiCategory(
    title: 'Flere symboler',
    emojis: [
      '🔥', '💧', '⚡', '❄️', '☃️', '⛄', '🌪️', '🌈', '☂️', '☔', '🎵', '🔔', '🔕', '🔒',
      '🔓', '🔑', '🛎️', '🧿', '🔮', '📿', '⚜️', '🔱', '⚓', '⛵', '🧸', '🎀', '🏷️',
    ],
  ),
];

/// Alle emojis (til søgning) – bevarer rækkefølge, fjerner dubletter.
List<String> get allTaskEmojisDistinct {
  final seen = <String>{};
  final out = <String>[];
  for (final cat in kTaskEmojiCategories) {
    for (final e in cat.emojis) {
      if (seen.add(e)) out.add(e);
    }
  }
  return out;
}
