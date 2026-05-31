/// Central helper to turn any error into a user-friendly UI message.
///
/// Rules:
/// - Recognize common codes (UNAUTHORIZED, FORBIDDEN, NOT_FOUND, ...).
/// - Map to clear English copy; prefer API `message` when present.
/// - For `Exception`, strip the "Exception:" prefix.
///
/// Usage:
/// ```dart
/// final msg = formatApiError(state.error);
/// AppToast.showError(context, msg);
/// ```
String formatApiError(Object? error, {String fallback = 'Something went wrong'}) {
  if (error == null) return fallback;

  String? code;
  String? message;

  try {
    final dynamic dynErr = error;
    final dynCode = dynErr.code;
    final dynMessage = dynErr.message;
    if (dynCode is String) code = dynCode;
    if (dynMessage is String) message = dynMessage;
  } catch (_) {
    // not ApiError
  }

  if (code != null) {
    final friendly = _friendlyByCode[code];
    if (friendly != null) {
      if (message != null && message.trim().isNotEmpty && message != friendly) {
        return friendly;
      }
      return friendly;
    }
  }

  if (message != null && message.trim().isNotEmpty) {
    return _stripExceptionPrefix(message);
  }

  final raw = error.toString();
  return _stripExceptionPrefix(raw).trim().isEmpty
      ? fallback
      : _stripExceptionPrefix(raw);
}

/// Extract `code` from an ApiError-like object (if any).
String? extractErrorCode(Object? error) {
  if (error == null) return null;
  try {
    final dynamic dynErr = error;
    final dynCode = dynErr.code;
    if (dynCode is String && dynCode.isNotEmpty) return dynCode;
  } catch (_) {}
  return null;
}

/// Extract `traceId` from an ApiError-like object (if any).
String? extractTraceId(Object? error) {
  if (error == null) return null;
  try {
    final dynamic dynErr = error;
    final dynTrace = dynErr.traceId;
    if (dynTrace is String && dynTrace.isNotEmpty) return dynTrace;
  } catch (_) {}
  return null;
}

String _stripExceptionPrefix(String raw) {
  return raw
      .replaceFirst(RegExp(r'^Exception:\s*'), '')
      .replaceFirst(RegExp(r'^DioException\s*\[[^\]]*\]:\s*'), '');
}

const Map<String, String> _friendlyByCode = {
  'UNAUTHORIZED': 'Your session has expired. Please sign in again.',
  'FORBIDDEN': 'You do not have permission to perform this action.',
  'NOT_FOUND': 'The requested data could not be found.',
  'CONFLICT': 'Data has changed. Please refresh and try again.',
  'VALIDATION_ERROR': 'Invalid data. Please check your input.',
  'BAD_REQUEST': 'Invalid request.',
  'RATE_LIMIT': 'Too many requests. Please try again in a few minutes.',
  'TIMEOUT': 'The server is responding slowly. Please try again.',
  'NETWORK_ERROR':
      'Could not reach the server. Check your connection and try again.',
  'CONFIGURATION_ERROR':
      'App configuration is incomplete. Please contact an administrator.',
  'INTERNAL_ERROR': 'The server encountered an error. Please try again later.',
  'SERVICE_UNAVAILABLE':
      'Service is temporarily unavailable. Please try again later.',
  'HTTP_ERROR': 'Request failed. Please try again.',
  'UNKNOWN_ERROR': 'An unknown error occurred. Please try again.',
  'INVALID_INPUT': 'Invalid data. Please check your input.',
  'INVALID_STATE': 'This action is not allowed in the current state.',
  'INVALID_TIME_RANGE': 'Invalid time range. Please check and try again.',
  'ROUTE_NOT_FOUND': 'No route found between these locations. Try a different destination.',
  'SLOT_UNAVAILABLE':
      'This time slot is taken or on hold. Please choose another slot.',
  'CHARGER_UNIT_NOT_FOUND': 'Charger unit not found.',
  'CHARGER_UNIT_INACTIVE': 'Charger unit is not active.',
  'EVS-0001': 'The server encountered an error. Please try again later.',
  'EVS-0002': 'Invalid data. Please check your input.',
  'EVS-0003': 'The requested data could not be found.',
  'EVS-0004': 'Your session has expired. Please sign in again.',
  'EVS-0005': 'You do not have permission to perform this action.',
  'EVS-0006': 'Invalid data. Please check your input.',
  'EVS-0007': 'This action is not allowed in the current state.',
  'EVS-0008':
      'This time slot is taken or on hold. Please choose another slot.',
  'EVS-0009': 'Charger unit not found.',
  'EVS-0010': 'Charger unit is not active.',
  'EVS-0011': 'Invalid time range. Please check and try again.',
  'EVS-0012': 'Routing service is temporarily unavailable. Please try again later.',
  'EVS-0013': 'No route found between these locations. Try a different destination.',
};
