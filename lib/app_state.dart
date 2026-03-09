import 'package:flutter/material.dart';
import '/backend/backend.dart';
import '/backend/schema/structs/index.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'flutter_flow/flutter_flow_util.dart';

class FFAppState extends ChangeNotifier {
  static FFAppState _instance = FFAppState._internal();

  factory FFAppState() {
    return _instance;
  }

  FFAppState._internal();

  static void reset() {
    _instance = FFAppState._internal();
  }

  Future initializePersistedState() async {}

  void update(VoidCallback callback) {
    callback();
    notifyListeners();
  }

  int _galleryHeight = 350;
  int get galleryHeight => _galleryHeight;
  set galleryHeight(int value) {
    _galleryHeight = value;
  }

  int _activeTab = 0;
  int get activeTab => _activeTab;
  set activeTab(int value) {
    _activeTab = value;
  }

  LatLng? _location = LatLng(43.552847, 7.017369);
  LatLng? get location => _location;
  set location(LatLng? value) {
    _location = value;
  }

  List<bool> _favorites = [true, false, false, true];
  List<bool> get favorites => _favorites;
  set favorites(List<bool> value) {
    _favorites = value;
  }

  void addToFavorites(bool value) {
    favorites.add(value);
  }

  void removeFromFavorites(bool value) {
    favorites.remove(value);
  }

  void removeAtIndexFromFavorites(int index) {
    favorites.removeAt(index);
  }

  void updateFavoritesAtIndex(
    int index,
    bool Function(bool) updateFn,
  ) {
    favorites[index] = updateFn(_favorites[index]);
  }

  void insertAtIndexInFavorites(int index, bool value) {
    favorites.insert(index, value);
  }

  bool _showDetails1 = false;
  bool get showDetails1 => _showDetails1;
  set showDetails1(bool value) {
    _showDetails1 = value;
  }

  bool _showDetails2 = false;
  bool get showDetails2 => _showDetails2;
  set showDetails2(bool value) {
    _showDetails2 = value;
  }

  bool _showDetails3 = false;
  bool get showDetails3 => _showDetails3;
  set showDetails3(bool value) {
    _showDetails3 = value;
  }

  bool _showDetails4 = false;
  bool get showDetails4 => _showDetails4;
  set showDetails4(bool value) {
    _showDetails4 = value;
  }

  List<String> _cooks = ['Michael', '', ''];
  List<String> get cooks => _cooks;
  set cooks(List<String> value) {
    _cooks = value;
  }

  void addToCooks(String value) {
    cooks.add(value);
  }

  void removeFromCooks(String value) {
    cooks.remove(value);
  }

  void removeAtIndexFromCooks(int index) {
    cooks.removeAt(index);
  }

  void updateCooksAtIndex(
    int index,
    String Function(String) updateFn,
  ) {
    cooks[index] = updateFn(_cooks[index]);
  }

  void insertAtIndexInCooks(int index, String value) {
    cooks.insert(index, value);
  }

  List<bool> _cookSelected = [true, false, false];
  List<bool> get cookSelected => _cookSelected;
  set cookSelected(List<bool> value) {
    _cookSelected = value;
  }

  void addToCookSelected(bool value) {
    cookSelected.add(value);
  }

  void removeFromCookSelected(bool value) {
    cookSelected.remove(value);
  }

  void removeAtIndexFromCookSelected(int index) {
    cookSelected.removeAt(index);
  }

  void updateCookSelectedAtIndex(
    int index,
    bool Function(bool) updateFn,
  ) {
    cookSelected[index] = updateFn(_cookSelected[index]);
  }

  void insertAtIndexInCookSelected(int index, bool value) {
    cookSelected.insert(index, value);
  }

  /// User's local swimming club
  String _userLSC = 'Pacific';
  String get userLSC => _userLSC;
  set userLSC(String value) {
    _userLSC = value;
  }
}
