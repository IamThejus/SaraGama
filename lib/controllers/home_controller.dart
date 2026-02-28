// controllers/home_controller.dart
import 'package:get/get.dart';
import '../services/home_service.dart';

class HomeController extends GetxController {
  final homeData = Rxn<HomeData>();
  final isLoading = true.obs;
  final hasError = false.obs;

  @override
  void onInit() {
    fetchHome();
    super.onInit();
  }

  Future<void> fetchHome() async {
    isLoading.value = true;
    hasError.value = false;
    final data = await HomeService.getUpdates();
    if (data != null) {
      homeData.value = data;
    } else {
      hasError.value = true;
    }
    isLoading.value = false;
  }
}