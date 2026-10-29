import 'package:flutter_test/flutter_test.dart';
import 'package:raghif/domain/models/store_model.dart';
import 'package:raghif/domain/models/store_list_entry.dart';
import 'package:raghif/features/locations/location_logic.dart';
import 'package:raghif/features/queue/store_list_logic.dart';

StoreModel bakery(String id, String area, {String? governorate}) => StoreModel(
  id: id, name: 'مخبز $id', isOpen: true, dailyBagLimit: 20,
  bagsRemaining: 12, area: area, governorate: governorate,
);

void main() {
  test('explicit governorate wins, known old areas map, unknown stays unknown', () {
    expect(governorateOf(bakery('a', 'الرمال')), 'غزة');
    expect(governorateOf(bakery('b', 'النصيرات')), 'الوسطى');
    expect(governorateOf(bakery('c', 'جباليا')), 'شمال غزة');
    expect(governorateOf(bakery('d', 'الرمال', governorate: 'رفح')), 'رفح');
    expect(governorateOf(bakery('e', 'منطقة غير معروفة')), isNull);
    expect(governorateOf(bakery('f', '')), isNull);
  });

  test('geographic filter intersects area and search without changing defaults', () {
    final entries = [
      StoreListEntry(store: bakery('غزة', 'الرمال')),
      StoreListEntry(store: bakery('غزة الثاني', 'الزيتون')),
      StoreListEntry(store: bakery('وسطى', 'النصيرات')),
      StoreListEntry(store: bakery('مجهول', 'حي مجهول')),
    ];
    expect(filterStoreEntries(entries), hasLength(4));
    expect(filterStoreEntries(entries, governorate: 'غزة'), hasLength(2));
    expect(filterStoreEntries(entries, governorate: 'غزة', area: 'الرمال')
        .single.store.id, 'غزة');
    expect(filterStoreEntries(entries, governorate: 'رفح'), isEmpty);
    expect(filterStoreEntries(entries, governorate: 'غزة', query: 'وسطى'), isEmpty);
    expect(filterStoreEntries([StoreListEntry(store: bakery('padded',' الرمال '))],
      governorate: 'غزة', area: 'الرمال'), hasLength(1));
  });
}
