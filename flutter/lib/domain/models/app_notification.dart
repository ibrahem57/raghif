class AppNotification {
  const AppNotification({
    required this.id,
    required this.purchaseId,
    required this.kind,
    required this.title,
    required this.body,
    required this.createdAt,
    this.readAt,
  });

  final String id;
  final String purchaseId;
  final String kind;
  final String title;
  final String body;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get isRead => readAt != null;

  AppNotification asRead(DateTime time) => AppNotification(
    id: id,
    purchaseId: purchaseId,
    kind: kind,
    title: title,
    body: body,
    createdAt: createdAt,
    readAt: readAt ?? time,
  );
}
