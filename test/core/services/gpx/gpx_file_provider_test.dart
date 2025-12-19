import 'package:flutter_test/flutter_test.dart';
import 'package:ftms/core/services/gpx/gpx_file_provider.dart';
import 'package:ftms/core/models/device_types.dart';
import 'package:ftms/core/services/gpx/gpx_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GpxFileProvider', () {
    test('getRandomGpxFile returns a valid path for rower', () async {
      final result = await GpxFileProvider.getRandomGpxFile(DeviceType.rower);
      if (result != null) {
        expect(result, startsWith('assets/gpx/rower/'));
        expect(result, endsWith('.gpx'));
      } else {
        expect(result, isNull);
      }
    });

    test('getRandomGpxFile returns a valid path for indoorBike', () async {
      final result = await GpxFileProvider.getRandomGpxFile(DeviceType.indoorBike);
      if (result != null) {
        expect(result, startsWith('assets/gpx/indoorBike/'));
        expect(result, endsWith('.gpx'));
      } else {
        expect(result, isNull);
      }
    });

    test('getSortedGpxData returns sorted list for rower', () async {
      final result = await GpxFileProvider.getSortedGpxData(DeviceType.rower);
      expect(result, isA<List<GpxData>>());
      for (int i = 1; i < result.length; i++) {
        expect(result[i - 1].totalDistance, lessThanOrEqualTo(result[i].totalDistance));
      }
    });

    test('getSortedGpxData returns sorted list for indoorBike', () async {
      final result = await GpxFileProvider.getSortedGpxData(DeviceType.indoorBike);
      expect(result, isA<List<GpxData>>());
      for (int i = 1; i < result.length; i++) {
        expect(result[i - 1].totalDistance, lessThanOrEqualTo(result[i].totalDistance));
      }
    });
  });
}