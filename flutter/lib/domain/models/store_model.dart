import 'package:equatable/equatable.dart';

class StoreModel extends Equatable {
  const StoreModel({
    required this.id,
    required this.name,
    required this.isOpen,
    required this.dailyBagLimit,
    required this.bagsRemaining,
    this.ownerId,
    this.batchSize = 20,
    this.openTime,
    this.closeTime,
    this.area = '',
    this.governorate,
  });

  /// Supabase `stores.id`. Same value on device, on the server and in a
  /// QR payload.
  final String id;
  final String name;
  final bool isOpen;
  final int dailyBagLimit;
  final int bagsRemaining;

  /// Supabase profiles UUID of the owner; null for the browse-only demo
  /// bakeries that nobody manages.
  final String? ownerId;
  final int batchSize;

  /// Today's purchase window, "HH:mm" 24h, set by the owner. Null when not
  /// set yet — informational only, doesn't itself gate [isOpen].
  final String? openTime;
  final String? closeTime;

  /// Neighborhood the bakery sits in (e.g. الرمال). Empty when unknown —
  /// shown as a filter chip on the buyer store list, not an address.
  final String area;
  final String? governorate;

  bool get isSoldOut => bagsRemaining <= 0;
  bool get canPurchase => isOpen && !isSoldOut;
  bool get isAvailable => canPurchase;
  bool get hasPurchaseWindow => openTime != null && closeTime != null;

  StoreModel copyWith({
    String? id,
    String? name,
    bool? isOpen,
    int? dailyBagLimit,
    int? bagsRemaining,
    String? ownerId,
    int? batchSize,
    String? openTime,
    String? closeTime,
    String? area,
    String? governorate,
  }) {
    return StoreModel(
      id: id ?? this.id,
      name: name ?? this.name,
      isOpen: isOpen ?? this.isOpen,
      dailyBagLimit: dailyBagLimit ?? this.dailyBagLimit,
      bagsRemaining: bagsRemaining ?? this.bagsRemaining,
      ownerId: ownerId ?? this.ownerId,
      batchSize: batchSize ?? this.batchSize,
      openTime: openTime ?? this.openTime,
      closeTime: closeTime ?? this.closeTime,
      area: area ?? this.area,
      governorate: governorate ?? this.governorate,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    isOpen,
    dailyBagLimit,
    bagsRemaining,
    ownerId,
    batchSize,
    openTime,
    closeTime,
    area,
    governorate,
  ];
}
