import 'package:flutter_test/flutter_test.dart';
import 'package:utoken_mobile/core/format/token_format.dart';

void main() {
  test('FR-SETT-001: Full và Compact', () {
    expect(formatTokens(6830736, TokenFormat.full), '6,830,736');
    expect(formatTokens(6830736, TokenFormat.compact), '6.83M');
  });

  test('Không hiển thị 0 khi không có dữ liệu', () {
    expect(formatRateOrNoData(null), 'No data');
  });
}
