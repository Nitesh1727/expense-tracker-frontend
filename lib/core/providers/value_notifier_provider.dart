import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Riverpod 3 moved the old `StateProvider` behind `legacy.dart`. For the
/// handful of places in this app that just need "one mutable value, read
/// and overwritten from the UI" (selected tab index, selected analytics
/// period, active category filter), this is the modern replacement instead
/// of reaching for the legacy API.
///
/// Named SimpleValueNotifier, not ValueNotifier — `flutter/foundation.dart`
/// (pulled in by every screen via `material.dart`) already exports a
/// `ValueNotifier`, and reusing that name here would make it ambiguous the
/// moment a file imports both.
class SimpleValueNotifier<T> extends Notifier<T> {
  final T _initial;

  SimpleValueNotifier(this._initial);

  @override
  T build() => _initial;

  void set(T value) => state = value;
}

NotifierProvider<SimpleValueNotifier<T>, T> simpleValueProvider<T>(T initial) {
  return NotifierProvider<SimpleValueNotifier<T>, T>(() => SimpleValueNotifier<T>(initial));
}
