import 'package:flutter/material.dart';

/// Provides a way for any widget in the tree to request a tab switch
/// in the top-level [HomePage] navigation shell.
class NavigationIndexProvider extends ChangeNotifier {
  int _index = 0;
  int get index => _index;

  void setIndex(int i) {
    if (_index == i) return;
    _index = i;
    notifyListeners();
  }
}
