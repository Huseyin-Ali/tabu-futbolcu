// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tabu_futbolcu.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TabuFutbolcuAdapter extends TypeAdapter<TabuFutbolcu> {
  @override
  final int typeId = 34;

  @override
  TabuFutbolcu read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TabuFutbolcu(
      isim: fields[0] as String,
      tabuKelimeler: (fields[1] as List).cast<String>(),
      sonGuncelleme: fields[2] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, TabuFutbolcu obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.isim)
      ..writeByte(1)
      ..write(obj.tabuKelimeler)
      ..writeByte(2)
      ..write(obj.sonGuncelleme);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TabuFutbolcuAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
