// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'blocked_domain.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BlockedDomainAdapter extends TypeAdapter<BlockedDomain> {
  @override
  final int typeId = 1;

  @override
  BlockedDomain read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BlockedDomain(
      id: fields[0] as String,
      domain: fields[1] as String,
      category: fields[2] as String,
      isEnabled: fields[3] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, BlockedDomain obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.domain)
      ..writeByte(2)
      ..write(obj.category)
      ..writeByte(3)
      ..write(obj.isEnabled);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BlockedDomainAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
