class Section {
  const Section({required this.id, required this.boardId, required this.name, this.position = 0});

  final String id;
  final String boardId;
  final String name;
  final double position;

  factory Section.fromJson(Map<String, dynamic> json) => Section(
        id: json['id'] as String,
        boardId: json['board_id'] as String,
        name: json['name'] as String? ?? '',
        position: (json['position'] as num?)?.toDouble() ?? 0,
      );

  Section copyWith({String? name, double? position}) =>
      Section(id: id, boardId: boardId, name: name ?? this.name, position: position ?? this.position);
}
