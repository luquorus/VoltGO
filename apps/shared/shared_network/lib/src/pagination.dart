/// Pagination response model matching OpenAPI schema
/// 
/// Schema from openapi.yaml:
/// PaginationResponse:
///   properties:
///     content: array
///     page: integer (0-indexed)
///     size: integer
///     totalElements: integer
///     totalPages: integer
///     first: boolean
///     last: boolean
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
    return PaginationResponse<T>(
      content: (json['content'] as List<dynamic>)
          .map((item) => fromJsonT(item as Map<String, dynamic>))
          .toList(),
      page: json['page'] as int,
      size: json['size'] as int,
      totalElements: json['totalElements'] as int,
      totalPages: json['totalPages'] as int,
      first: json['first'] as bool,
      last: json['last'] as bool,
    );
  }

  Map<String, dynamic> toJson(Map<String, dynamic> Function(T) toJsonT) {
    return {
      'content': content.map((item) => toJsonT(item)).toList(),
      'page': page,
      'size': size,
      'totalElements': totalElements,
      'totalPages': totalPages,
      'first': first,
      'last': last,
    };
  }

  bool get hasNext => !last;
  bool get hasPrevious => !first;
}

