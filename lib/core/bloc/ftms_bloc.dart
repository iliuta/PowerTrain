// This file was moved from lib/bloc.dart
import 'dart:async';
import 'package:flutter_ftms/flutter_ftms.dart';
import '../models/processed_ftms_data.dart';

class FTMSBloc {
  final StreamController<ProcessedFtmsData?> _ftmsDeviceDataController =
  StreamController<ProcessedFtmsData?>.broadcast();

  StreamSink<ProcessedFtmsData?> get ftmsDeviceDataControllerSink =>
      _ftmsDeviceDataController.sink;
  Stream<ProcessedFtmsData?> get ftmsDeviceDataControllerStream =>
      _ftmsDeviceDataController.stream;

  final StreamController<MachineFeature?> _ftmsMachineFeaturesController =
  StreamController<MachineFeature?>.broadcast();

  StreamSink<MachineFeature?> get ftmsMachineFeaturesControllerSink =>
      _ftmsMachineFeaturesController.sink;
  Stream<MachineFeature?> get ftmsMachineFeaturesControllerStream =>
      _ftmsMachineFeaturesController.stream;
}

final FTMSBloc ftmsBloc = FTMSBloc();
