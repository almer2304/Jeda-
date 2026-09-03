import 'package:hive/hive.dart';

part 'blocked_domain.g.dart';

@HiveType(typeId: 1)
class BlockedDomain {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String domain;

  @HiveField(2)
  final String category;

  @HiveField(3)
  bool isEnabled;

  BlockedDomain({
    required this.id,
    required this.domain,
    required this.category,
    this.isEnabled = true,
  });
}
