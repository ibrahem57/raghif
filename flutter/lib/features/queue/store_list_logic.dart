import '../../domain/models/store_list_entry.dart';
import '../locations/location_logic.dart';

/// Pure store-list logic, kept out of the widget so it's unit-testable
/// (mirrors the `queue_logic.dart` pattern).
///
/// Ordering rule the buyer sees: pinned stores first, then the stores they
/// have an order at today, then stores they've bought from before, then
/// everything else alphabetically. Within a group, the most recent purchase
/// wins — so "the stores he buys from" naturally rise to the top without
/// pinning anything.
List<StoreListEntry> sortStoreEntries(List<StoreListEntry> entries) {
  final sorted = [...entries];
  sorted.sort((a, b) {
    if (a.pinned != b.pinned) return a.pinned ? -1 : 1;

    if (a.hasOrderToday != b.hasOrderToday) return a.hasOrderToday ? -1 : 1;

    final aLast = a.lastPurchaseDate;
    final bLast = b.lastPurchaseDate;
    if ((aLast != null) != (bLast != null)) return aLast != null ? -1 : 1;
    if (aLast != null && bLast != null && aLast != bLast) {
      // "YYYY-MM-DD" sorts lexicographically = chronologically; newest first.
      return bLast.compareTo(aLast);
    }

    return a.store.name.compareTo(b.store.name);
  });
  return sorted;
}

/// Filters by free-text [query] (store name) and an [area] chip selection
/// (null = all areas). Case/diacritic-insensitive enough for Arabic store
/// names: trims and compares on the raw strings.
List<StoreListEntry> filterStoreEntries(
  List<StoreListEntry> entries, {
  String query = '',
  String? area,
  String? governorate,
}) {
  final q = query.trim();
  return entries.where((entry) {
    if (governorate != null && governorateOf(entry.store) != governorate) {
      return false;
    }
    if (area != null &&
        area.isNotEmpty &&
        entry.store.area.trim() != area.trim()) {
      return false;
    }
    if (q.isEmpty) return true;
    return entry.store.name.contains(q) || entry.store.area.contains(q);
  }).toList();
}

/// Distinct areas present in [entries], in first-seen order — the filter chips
/// only ever show areas that actually have stores.
List<String> areasOf(List<StoreListEntry> entries) {
  final seen = <String>[];
  for (final entry in entries) {
    final area = entry.store.area.trim();
    if (area.isEmpty || seen.contains(area)) continue;
    seen.add(area);
  }
  return seen;
}

/// How to label a purchase date next to "آخر شراء": today/yesterday read
/// better than a raw date.
String purchaseDateLabel(String date, String today) {
  if (date == today) return _today;
  final yesterday = _previousDay(today);
  if (date == yesterday) return _yesterday;
  return date;
}

const _today = 'اليوم';
const _yesterday = 'أمس';

String _previousDay(String today) {
  final parts = today.split('-');
  if (parts.length != 3) return '';
  final parsed = DateTime.tryParse(today);
  if (parsed == null) return '';
  final prev = parsed.subtract(const Duration(days: 1));
  final y = prev.year.toString().padLeft(4, '0');
  final m = prev.month.toString().padLeft(2, '0');
  final d = prev.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
