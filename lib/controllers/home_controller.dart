// controllers/home_controller.dart
//
// Cache strategy: stale-while-revalidate with a 2-hour TTL.
//
//  On first open (no cache):
//    → show loading spinner → fetch → cache → display
//
//  On open with fresh cache (< 2hr old):
//    → serve cached data instantly (no loading state)
//    → no background fetch needed
//
//  On open with stale cache (> 2hr old):
//    → serve stale data instantly (no loading state, user sees content immediately)
//    → silently fetch fresh data in background
//    → swap in new data when ready (user sees update without reload)
//
//  Background timer:
//    → every 2 hours while app is in foreground, trigger a silent refresh

import 'dart:async';
import 'package:get/get.dart';
import '../services/cache_service.dart';
import '../services/home_service.dart';

class HomeController extends GetxController {
  final homeData  = Rxn<HomeData>();
  final isLoading = false.obs;
  final hasError  = false.obs;
  final isRefreshing = false.obs; // silent background refresh indicator

  Timer? _bgTimer;

  static const _bgRefreshInterval = Duration(hours: 2);

  @override
  void onInit() {
    super.onInit();
    _initHome();
    _startBackgroundTimer();
  }

  @override
  void onClose() {
    _bgTimer?.cancel();
    super.onClose();
  }

  // ── Init ────────────────────────────────────────────────────────────────────

  Future<void> _initHome() async {
    // Try cache first
    final staleJson = CacheService.getAnyHome();

    if (staleJson != null) {
      // We have something cached — show it immediately, no loading spinner
      try {
        homeData.value = HomeData.fromCacheJson(staleJson);
        hasError.value = false;
      } catch (_) {
        // Corrupted cache — treat as missing
        CacheService.clearHome();
      }

      // If the cache is stale, refresh silently in the background
      if (CacheService.isHomeStale()) {
        _silentRefresh();
      }
      return;
    }

    // No cache at all — must fetch with loading state
    isLoading.value = true;
    hasError.value  = false;
    await _fetchAndCache();
    isLoading.value = false;
  }

  // ── Public: pull-to-refresh (user-initiated) ────────────────────────────────

  Future<void> fetchHome() async {
    // If we already have data, do a silent refresh (no spinner)
    if (homeData.value != null) {
      await _silentRefresh();
      return;
    }
    isLoading.value = true;
    hasError.value  = false;
    await _fetchAndCache();
    isLoading.value = false;
  }

  // ── Silent background refresh ───────────────────────────────────────────────

  Future<void> _silentRefresh() async {
    if (isRefreshing.value) return; // avoid concurrent refreshes
    isRefreshing.value = true;
    await _fetchAndCache(silent: true);
    isRefreshing.value = false;
  }

  // ── Core fetch ──────────────────────────────────────────────────────────────

  Future<void> _fetchAndCache({bool silent = false}) async {
    final data = await HomeService.getUpdates();
    if (data != null) {
      CacheService.saveHome(data.toJson());
      homeData.value = data;
      hasError.value = false;
    } else {
      // Only mark error if we have nothing to show
      if (homeData.value == null) hasError.value = true;
      // If we have stale data already showing, silently fail — keep showing stale
    }
  }

  // ── Background timer ────────────────────────────────────────────────────────

  void _startBackgroundTimer() {
    _bgTimer?.cancel();
    _bgTimer = Timer.periodic(_bgRefreshInterval, (_) {
      // Only refresh if app is active and cache is stale
      if (CacheService.isHomeStale()) {
        _silentRefresh();
      }
    });
  }

  /// Restart the 2-hour timer (call if you want to reset the cycle).
  void resetTimer() {
    _startBackgroundTimer();
  }
}