// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'quota_entry.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class QuotaEntryAdapter extends TypeAdapter<QuotaEntry> {
  @override
  final int typeId = 2;

  @override
  QuotaEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return QuotaEntry(
      id: fields[0] as String,
      groupName: fields[1] as String,
      packageNames: (fields[2] as List).cast<String>(),
      appNames: (fields[3] as List).cast<String>(),
      dailyQuotaMinutes: fields[4] as int,
      usedTodaySeconds: fields[5] == null ? 0 : fields[5] as int,
      lastResetDate: fields[6] as DateTime,
      emergencyTickets: fields[7] == null ? 2 : fields[7] as int,
      lastTicketResetDate: fields[8] as DateTime,
      activeEmergencyUntil: fields[9] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, QuotaEntry obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.groupName)
      ..writeByte(2)
      ..write(obj.packageNames)
      ..writeByte(3)
      ..write(obj.appNames)
      ..writeByte(4)
      ..write(obj.dailyQuotaMinutes)
      ..writeByte(5)
      ..write(obj.usedTodaySeconds)
      ..writeByte(6)
      ..write(obj.lastResetDate)
      ..writeByte(7)
      ..write(obj.emergencyTickets)
      ..writeByte(8)
      ..write(obj.lastTicketResetDate)
      ..writeByte(9)
      ..write(obj.activeEmergencyUntil);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuotaEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
