import 'package:flutter_test/flutter_test.dart';
import 'package:ftms/core/bloc/ftms_bloc.dart';
import 'package:ftms/core/models/processed_ftms_data.dart';
import 'package:ftms/core/models/device_types.dart';
import 'package:flutter_ftms/src/ftms/characteristic/machine/feature/machine_feature.dart';




void main() {
  group('FTMSBloc', () {

    test('should add and receive ProcessedFtmsData', () async {
      final testData = ProcessedFtmsData(
        deviceType: DeviceType.indoorBike,
        paramValueMap: {},
      );
      final future = expectLater(
        ftmsBloc.ftmsDeviceDataControllerStream.timeout(const Duration(seconds: 2)),
        emits(testData),
      );
      ftmsBloc.ftmsDeviceDataControllerSink.add(testData);
      await future;
    });

    test('should add and receive MachineFeature', () async {
      final testFeature = MachineFeature([0, 1, 2, 3]);
      final future = expectLater(
        ftmsBloc.ftmsMachineFeaturesControllerStream.timeout(const Duration(seconds: 2)),
        emits(testFeature),
      );
      ftmsBloc.ftmsMachineFeaturesControllerSink.add(testFeature);
      await future;
    });
  });
}

