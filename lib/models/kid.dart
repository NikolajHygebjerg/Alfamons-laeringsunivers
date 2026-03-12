class Kid {
  final String id;
  final String name;
  final String? avatarUrl;
  final String? pinCode;

  Kid({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.pinCode,
  });

  factory Kid.fromJson(Map<String, dynamic> json) {
    return Kid(
      id: json['id'] as String,
      name: json['name'] as String,
      avatarUrl: json['avatar_url'] as String?,
      pinCode: json['pin_code'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'avatar_url': avatarUrl,
        'pin_code': pinCode,
      };
}
