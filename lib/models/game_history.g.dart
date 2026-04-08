// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'game_history.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class GameHistoryAdapter extends TypeAdapter<GameHistory> {
  @override
  final int typeId = 33;

  @override
  GameHistory read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return GameHistory(
      takim1Ismi: fields[0] as String,
      takim2Ismi: fields[1] as String,
      takim1Skor: fields[2] as int,
      takim2Skor: fields[3] as int,
      tarih: fields[4] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, GameHistory obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.takim1Ismi)
      ..writeByte(1)
      ..write(obj.takim2Ismi)
      ..writeByte(2)
      ..write(obj.takim1Skor)
      ..writeByte(3)
      ..write(obj.takim2Skor)
      ..writeByte(4)
      ..write(obj.tarih);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GameHistoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
