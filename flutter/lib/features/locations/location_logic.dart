import '../../domain/models/store_model.dart';

const governorates = ['شمال غزة', 'غزة', 'الوسطى', 'خانيونس', 'رفح'];

/// Known legacy neighborhoods only. Unmapped stores remain browseable via all.
const _legacyAreas = <String, String>{
  'جباليا': 'شمال غزة',
  'بيت لاهيا': 'شمال غزة',
  'بيت حانون': 'شمال غزة',
  'الرمال': 'غزة',
  'الزيتون': 'غزة',
  'النصر': 'غزة',
  'الشجاعية': 'غزة',
  'الشاطئ': 'غزة',
  'الساحة': 'غزة',
  'الثلاثيني': 'غزة',
  'دير البلح': 'الوسطى',
  'النصيرات': 'الوسطى',
  'البريج': 'الوسطى',
  'المغازي': 'الوسطى',
  'الزوايدة': 'الوسطى',
  'خانيونس': 'خانيونس',
  'القرارة': 'خانيونس',
  'معن': 'خانيونس',
  'حي السلام': 'رفح',
  'الشابورة': 'رفح',
  'تل السلطان': 'رفح',
};

String? governorateOf(StoreModel store) {
  final explicit = store.governorate?.trim();
  if (explicit != null && explicit.isNotEmpty) {
    return governorates.contains(explicit) ? explicit : null;
  }
  return _legacyAreas[store.area.trim()];
}

List<StoreModel> storesInGovernorate(
  List<StoreModel> stores,
  String governorate,
) => stores.where((s) => governorateOf(s) == governorate).toList();

typedef LocationSelected = void Function(String governorate, String area);
