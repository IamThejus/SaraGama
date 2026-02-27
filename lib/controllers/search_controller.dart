// controllers/search_controller.dart
// Debounces user input (400 ms), calls SearchService, stores results reactively.

import 'dart:async';
import 'package:get/get.dart';
import '../services/search_service.dart';

class SongSearchController extends GetxController {
  final results = <SearchResult>[].obs;
  final isLoading = false.obs;
  final query = ''.obs;

  Timer? _debounce;
  static const _delay = Duration(milliseconds: 400);

  void onQueryChanged(String value) {
    query.value = value;
    _debounce?.cancel();

    if (value.trim().isEmpty) {
      results.clear();
      isLoading.value = false;
      return;
    }

    isLoading.value = true;
    _debounce = Timer(_delay, () => _fetch(value.trim()));
  }

  Future<void> _fetch(String q) async {
    final data = await SearchService.autocomplete(q);
    // Guard: user may have cleared the field while we were waiting
    if (query.value.trim().isEmpty) {
      results.clear();
      isLoading.value = false;
      return;
    }
    results.assignAll(data);
    isLoading.value = false;
  }

  void clear() {
    _debounce?.cancel();
    query.value = '';
    results.clear();
    isLoading.value = false;
  }

  @override
  void onClose() {
    _debounce?.cancel();
    super.onClose();
  }
}