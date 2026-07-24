import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:opentranscribe/core/app/app_language.dart';
import 'package:opentranscribe/core/app/local_service.dart';

/// The app language as observable state, so picking a language re-locales the
/// running app instead of waiting for a restart. [AppLanguage] stays the
/// storage owner; this is its live view.
class AppLanguageCubit extends Cubit<String> {
  AppLanguageCubit({required LocalService storage})
    : _storage = storage,
      super(AppLanguage.of(storage));

  final LocalService _storage;

  /// Persists first and emits only on success, like the other settings.
  Future<void> setLanguage(String code) async {
    await AppLanguage.set(_storage, code);
    if (!isClosed) emit(code);
  }
}
