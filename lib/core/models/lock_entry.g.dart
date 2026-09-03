// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lock_entry.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LockEntryAdapter extends TypeAdapter<LockEntry> {
  @override
  final int typeId = 0;

  @override
  LockEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LockEntry(
      id: fields[0] as String,
      packageName: fields[1] as String,
      appName: fields[2] as String,
      appIconBytes: (fields[3] as List).cast<int>(),
      startTime: fields[4] as DateTime,
      durationHours: fields[5] as int,
      isActive: fields[6] == null ? true : fields[6] as bool,
      isScheduled: fields[7] == null ? false : fields[7] as bool,
      scheduledStart: fields[8] as String?,
      scheduledEnd: fields[9] as String?,
      scheduledDays:
          fields[10] == null ? [] : (fields[10] as List?)?.cast<int>(),
    );
  }

  @override
  void write(BinaryWriter writer, LockEntry obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.packageName)
      ..writeByte(2)
      ..write(obj.appName)
      ..writeByte(3)
      ..write(obj.appIconBytes)
      ..writeByte(4)
      ..write(obj.startTime)
      ..writeByte(5)
      ..write(obj.durationHours)
      ..writeByte(6)
      ..write(obj.isActive)
      ..writeByte(7)
      ..write(obj.isScheduled)
      ..writeByte(8)
      ..write(obj.scheduledStart)
      ..writeByte(9)
      ..write(obj.scheduledEnd)
      ..writeByte(10)
      ..write(obj.scheduledDays);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LockEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
