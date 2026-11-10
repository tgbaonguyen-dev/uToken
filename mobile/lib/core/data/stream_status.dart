import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';

/// Returns a user-facing message for a failed Firestore stream.
String friendlyStreamError(Object error) {
  debugPrint('Firestore stream error: $error');
  if (error is FirebaseException) {
    if (error.code == 'permission-denied') {
      return 'Firebase denied access. Check the signed-in account, project and Firestore Rules.';
    }
    if (error.code == 'unauthenticated') {
      return 'Session expired. Sign in with Google again.';
    }
  }
  return 'Không đọc được dữ liệu. Kiểm tra kết nối mạng.';
}

/// Maps an AI provider error code to a user-facing message.
String friendlyAiError(String? code) => switch (code) {
      'invalid_api_key' =>
        'API key của nhà cung cấp AI không hợp lệ — kiểm tra trong Settings trên máy tính.',
      'rate_limited' =>
        'Nhà cung cấp AI đang giới hạn yêu cầu. Vui lòng thử lại sau.',
      'provider_error' => 'Nhà cung cấp AI đang gặp lỗi. Vui lòng thử lại sau.',
      'refused' => 'Nhà cung cấp AI đã từ chối yêu cầu.',
      'truncated' =>
        'Phản hồi từ nhà cung cấp AI chưa đầy đủ. Vui lòng đồng bộ lại.',
      _ => 'Không thể tạo đánh giá AI. Vui lòng thử đồng bộ lại.',
    };
