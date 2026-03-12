class Avatar {
  final String id;
  final String name;
  final String? letter;
  final Map<String, dynamic>? pointsPerStage;

  Avatar({
    required this.id,
    required this.name,
    this.letter,
    this.pointsPerStage,
  });

  factory Avatar.fromJson(Map<String, dynamic> json) {
    return Avatar(
      id: json['id'] as String,
      name: json['name'] as String,
      letter: json['letter'] as String?,
      pointsPerStage: json['points_per_stage'] as Map<String, dynamic>?,
    );
  }
}

class AvatarStage {
  final int stageIndex;
  final String imageUrl;

  AvatarStage({required this.stageIndex, required this.imageUrl});

  factory AvatarStage.fromJson(Map<String, dynamic> json) {
    return AvatarStage(
      stageIndex: json['stage_index'] as int,
      imageUrl: json['image_url'] as String,
    );
  }
}

class AvatarStrength {
  final String name;
  final int value;

  AvatarStrength({required this.name, required this.value});

  factory AvatarStrength.fromJson(Map<String, dynamic> json) {
    return AvatarStrength(
      name: json['name'] as String,
      value: json['value'] as int,
    );
  }
}

class KidActiveAvatar {
  final String? avatarId;
  final int pointsCurrent;

  KidActiveAvatar({this.avatarId, required this.pointsCurrent});

  factory KidActiveAvatar.fromJson(Map<String, dynamic> json) {
    return KidActiveAvatar(
      avatarId: json['avatar_id'] as String?,
      pointsCurrent: json['points_current'] as int? ?? 0,
    );
  }
}
