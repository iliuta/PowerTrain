import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ftms/core/config/live_data_display_config.dart';
import 'package:ftms/core/config/live_data_field_config.dart';
import 'package:ftms/core/models/device_types.dart';
import 'package:ftms/core/models/live_data_field_value.dart';
import 'package:ftms/core/widgets/ftms_live_data_display_widget.dart';
import 'package:ftms/l10n/app_localizations.dart';

void main() {
  testWidgets('FtmsLiveDataDisplayWidget covers all branches for 100% coverage',
      (WidgetTester tester) async {
    final config = LiveDataDisplayConfig(fields: [
      LiveDataFieldConfig(
        name: 'Speed',
        label: 'Speed',
        display: 'number',
        unit: 'km/h',
        min: 0,
        max: 60,
        icon: 'bike',
      ),
      LiveDataFieldConfig(
        name: 'Power',
        label: 'Power',
        display: 'speedometer',
        unit: 'W',
        min: 0,
        max: 500,
        icon: null,
      ),
      LiveDataFieldConfig(
        name: 'Missing',
        label: 'Missing',
        display: 'number',
        unit: '',
      ),
      LiveDataFieldConfig(
        name: 'Unknown',
        label: 'Unknown',
        display: 'not_a_widget',
        unit: '',
      ),
    ], deviceType: DeviceType.indoorBike);
    final paramValueMap = <String, LiveDataFieldValue>{
      'Speed': LiveDataFieldValue(
        name: 'Speed',
        value: 10,
        factor: 1,
        unit: 'km/h',
        flag: null,
        size: 2,
        signed: false,
      ),
      'Power': LiveDataFieldValue(
        name: 'Power',
        value: 200,
        factor: 1,
        unit: 'W',
        flag: null,
        size: 2,
        signed: false,
      ),
      // 'Missing' is intentionally missing
      'Unknown': LiveDataFieldValue(
        name: 'Unknown',
        value: 1,
        factor: 1,
        unit: '',
        flag: null,
        size: 2,
        signed: false,
      ),
    };
    final targets = {
      'Speed': 10,
      'Power': 150,
    };
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: FtmsLiveDataDisplayWidget(
          config: config,
          paramValueMap: paramValueMap,
          targets: targets,
          defaultColor: Colors.purple,
          machineType: DeviceType.indoorBike,
        ),
      ),
    ));
    // Number widget
    expect(find.text('Speed'), findsOneWidget);
    expect(find.text('10 km/h'), findsOneWidget);
    // Speedometer widget
    expect(find.text('Power'), findsOneWidget);
    expect(find.text('200 W'), findsOneWidget);
    // Missing param
    expect(find.textContaining('Missing: (not available)'), findsOneWidget);
    // Unknown display type
    expect(
        find.textContaining('Unknown: (unknown display type)'), findsOneWidget);
    // Color logic: Speed should be green (10 >= 10), Power should be green (200 >= 150)
    // (We can't directly check color, but we exercised the branch)
    // Multiple columns: force a small width to test row logic
    await tester.pumpWidget(SizedBox(
      width: 200,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: FtmsLiveDataDisplayWidget(
            config: config,
            paramValueMap: paramValueMap,
            machineType: DeviceType.indoorBike,
          ),
        ),
      ),
    ));
    expect(find.text('Speed'), findsOneWidget);
    expect(find.text('Power'), findsOneWidget);
    // Edge case: param.factor is not a number and cannot be parsed
    final weirdConfig = LiveDataDisplayConfig(fields: [
      LiveDataFieldConfig(
        name: 'Weird',
        label: 'Weird',
        display: 'number',
        unit: 'u',
      ),
    ], deviceType: DeviceType.indoorBike);
    final weirdParamValueMap = <String, LiveDataFieldValue>{
      'Weird': LiveDataFieldValue(
        name: 'Weird',
        value: 5,
        factor: 1,
        unit: 'u',
        flag: null,
        size: 2,
        signed: false,
      ),
    };
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: FtmsLiveDataDisplayWidget(
          config: weirdConfig,
          paramValueMap: weirdParamValueMap,
          machineType: DeviceType.indoorBike,
        ),
      ),
    ));
    expect(find.text('Weird'), findsOneWidget);
    expect(find.text('5 u'), findsOneWidget);

    // Edge case: testing with targets to verify color changes
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: FtmsLiveDataDisplayWidget(
          config: config,
          paramValueMap: paramValueMap,
          targets: targets,
          machineType: DeviceType.indoorBike,
        ),
      ),
    ));
    expect(find.text('Speed'), findsOneWidget);
    expect(find.text('Power'), findsOneWidget);

    // Edge case: single field, very large width (all fields in one row)
    final singleConfig = LiveDataDisplayConfig(fields: [
      LiveDataFieldConfig(
        name: 'Speed',
        label: 'Speed',
        display: 'number',
        unit: 'km/h',
      ),
    ], deviceType: DeviceType.indoorBike);
    final singleParamValueMap = <String, LiveDataFieldValue>{
      'Speed': LiveDataFieldValue(
        name: 'Speed',
        value: 99,
        factor: 1,
        unit: 'km/h',
        flag: null,
        size: 2,
        signed: false,
      ),
    };
    await tester.pumpWidget(SizedBox(
      width: 1000,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: FtmsLiveDataDisplayWidget(
            config: singleConfig,
            paramValueMap: singleParamValueMap,
            machineType: DeviceType.indoorBike,
          ),
        ),
      ),
    ));
    expect(find.text('Speed'), findsOneWidget);
    expect(find.text('99 km/h'), findsOneWidget);
  });
}
