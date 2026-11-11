import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import '../i18n/tr.dart';

class DesktopSyncRequestException implements Exception {
  const DesktopSyncRequestException();
}

/// Returns a user-facing message for a failed Firestore stream.
String friendlyStreamError(Object error) {
  debugPrint('Firestore stream error: $error');
  if (error is DesktopSyncRequestException) {
    return 'Read Firebase data, but could not ask desktop to sync. Try Refresh again.';
  }
  if (error is FormatException) {
    return 'Invalid Firebase data. Check document field types, then refresh.';
  }
  if (error is FirebaseException) {
    if (error.code == 'permission-denied') {
      return 'Firebase denied access. Check the signed-in account, project and Firestore Rules.';
    }
    if (error.code == 'unauthenticated') {
      return 'Session expired. Sign in with Google again.';
    }
  }
  return 'Couldn’t load data. Check your internet connection.';
}

/// Maps an AI provider error code to a user-facing message.
String friendlyAiError(String? code) => switch (code) {
      'review_checkpoint_missing' => tr(
          'Run a 30-day review first to establish the last-review baseline on this phone.'),
      'review_data_changed' => tr(
          'Usage history changed. Run a 30-day review to establish a fresh baseline.'),
      'invalid_review_data' => tr(
          'Some daily summaries are invalid. Correct them and refresh before reviewing.'),
      'review_checkpoint_save_error' => tr(
          'The review was uploaded, but its baseline could not be saved on this phone. Run a 30-day review again before reviewing new usage.'),
      'review_data_unavailable' => tr(
          'Could not read current Firebase usage. Check your connection and try again.'),
      'invalid_api_key' => tr(
          'The AI provider rejected the API key. Check it in Settings on your computer.'),
      'rate_limited' =>
        tr('The AI provider is rate limiting requests. Try again later.'),
      'provider_error' =>
        tr('The AI provider is having problems. Try again later.'),
      'refused' => tr('The AI provider declined the request.'),
      'invalid_model' => tr(
          'The AI provider doesn’t know this model name. Check it in Settings → AI review.'),
      'missing_key' => tr(
          'No AI provider key on your computer. Add one in Settings → AI review on desktop.'),
      'disabled' => tr('AI review is turned off on your computer.'),
      'insufficient_data' =>
        tr('Not enough usage yet: the AI review needs at least 5 chats.'),
      'not_paired' || 'revoked' => tr(
          'Your computer is signed out. Sign in with Google in μToken desktop.'),
      'network' =>
        tr('Your computer couldn’t reach Firebase. Check its connection.'),
      'truncated' => tr('The AI review was cut off. Sync again to retry.'),
      _ => tr('Couldn’t create the AI review. Sync again to retry.'),
    };
