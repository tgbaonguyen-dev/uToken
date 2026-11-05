import 'package:intl/intl.dart';

enum TokenFormat { compact, full }

/// FR-SETT-001: Compact 6.83M, Full 6,830,736.
String formatTokens(int value, TokenFormat format) {
  if (format == TokenFormat.full) return NumberFormat('#,##0', 'en_US').format(value);
  if (value >= 1000000000) return '${(value / 1e9).toStringAsFixed(2)}B';
  if (value >= 1000000) return '${(value / 1e6).toStringAsFixed(2)}M';
  if (value >= 1000) return '${(value / 1e3).toStringAsFixed(1)}K';
  return value.toString();
}

/// Mẫu số bằng 0 hoặc nguồn không cung cấp → "Không có dữ liệu" (SRS §3.4), không hiển thị 0.
String formatRateOrNoData(double? rate) => rate == null ? 'Không có dữ liệu' : '${(rate * 100).toStringAsFixed(1)}%';
