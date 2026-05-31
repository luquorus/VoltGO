import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Trạng thái lỗi dùng chung với gợi ý retry.
///
/// Hỗ trợ tiêu đề / mô tả ngắn / mã lỗi / retry để hiển thị nhất quán
/// trên tất cả các app (EV User, Collaborator, Admin).
class ErrorState extends StatelessWidget {
  /// Mô tả lỗi (thường là `apiError.message`).
  final String? message;

  /// Tiêu đề ngắn, mặc định "Đã có lỗi xảy ra".
  final String? title;

  /// Mã lỗi từ backend (hiển thị nhỏ phía dưới để hỗ trợ debug).
  final String? code;

  /// Trace id để hỗ trợ tra log khi cần.
  final String? traceId;

  /// Icon tuỳ biến.
  final IconData? icon;

  /// Callback retry. Nếu null thì không hiển thị nút.
  final VoidCallback? onRetry;

  /// Nhãn của nút retry.
  final String retryLabel;

  /// Bố cục dạng compact dùng trong card / dialog.
  final bool compact;

  const ErrorState({
    super.key,
    this.message,
    this.title,
    this.code,
    this.traceId,
    this.icon,
    this.onRetry,
    this.retryLabel = 'Try again',
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.error;

    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: EdgeInsets.all(compact ? 16 : 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              FaIcon(
                icon ?? FontAwesomeIcons.circleExclamation,
                size: compact ? 40 : 56,
                color: color,
              ),
              SizedBox(height: compact ? 12 : 16),
              Text(
                title ?? 'Something went wrong',
                style: (compact
                        ? theme.textTheme.titleSmall
                        : theme.textTheme.titleMedium)
                    ?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              if (message != null && message!.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  message!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.75),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (code != null && code!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Error code: $code',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              ],
              if (traceId != null && traceId!.isNotEmpty) ...[
                const SizedBox(height: 4),
                SelectableText(
                  'Trace: $traceId',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.4),
                  ),
                ),
              ],
              if (onRetry != null) ...[
                SizedBox(height: compact ? 16 : 24),
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const FaIcon(FontAwesomeIcons.rotate, size: 14),
                  label: Text(retryLabel),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
