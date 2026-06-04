/// Pagination Response Model
/// Generic pagination response from backend
class PaginationResponse<T> {
  final List<T> content;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;
  final bool first;
  final bool last;

  PaginationResponse({
    required this.content,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
    required this.first,
    required this.last,
  });

  factory PaginationResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJsonT,
  ) {
    final contentList = json['content'] as List?;
    final content = contentList
            ?.whereType<Map>()
            .map((e) => fromJsonT(Map<String, dynamic>.from(e)))
            .toList() ??
        [];
    return PaginationResponse<T>(
      content: content,
      page: (json['page'] as num?)?.toInt() ?? (json['number'] as num?)?.toInt() ?? 0,
      size: (json['size'] as num?)?.toInt() ?? 20,
      totalElements: (json['totalElements'] as num?)?.toInt() ?? 0,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 0,
      first: json['first'] as bool? ?? false,
      last: json['last'] as bool? ?? false,
    );
  }
}

