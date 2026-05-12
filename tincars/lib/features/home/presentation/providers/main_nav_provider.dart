import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Notifier to manage the global navigation index
class MainNavIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setIndex(int index) {
    state = index;
  }
}

/// Provider to manage the global navigation index of the MainScreen
final mainNavIndexProvider = NotifierProvider<MainNavIndexNotifier, int>(() {
  return MainNavIndexNotifier();
});
