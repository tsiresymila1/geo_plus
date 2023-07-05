import 'package:isar/isar.dart';
import 'package:json_annotation/json_annotation.dart';

part 'position.g.dart';

@JsonSerializable()
@collection
class PositionEntity {
  PositionEntity(): id = Isar.autoIncrement;
  final Id id ;
  int? timestamp;
  double? longitude;
  double? latitude;
  double? altitude;
  double? speed;
  double? accuracy;
  double? speedAccuracy;
  factory PositionEntity.fromJson(Map<String, dynamic> json) => _$PositionEntityFromJson(json);
  Map<String, dynamic> toJson() => _$PositionEntityToJson(this);

}