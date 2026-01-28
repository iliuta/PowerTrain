// This file was moved from lib/ftms_device_data_features_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter_ftms/flutter_ftms.dart';
import '../../core/bloc/ftms_bloc.dart';
import '../../core/services/devices/ftms.dart';
import '../../l10n/app_localizations.dart';

class FTMSDeviceDataFeaturesTab extends StatefulWidget {
  const FTMSDeviceDataFeaturesTab({super.key});

  @override
  State<FTMSDeviceDataFeaturesTab> createState() => FTMSDeviceDataFeaturesTabState();
}

class FTMSDeviceDataFeaturesTabState extends State<FTMSDeviceDataFeaturesTab> {
  @override
  void initState() {
    super.initState();
    // Data is already merged at the source (ftms.dart service) and forwarded through ftmsBloc
  }

  Widget _buildDataFeature(String featureName, bool isSupported, dynamic value) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: isSupported ? null : Colors.grey[200],
      child: ListTile(
        leading: Icon(
          isSupported ? Icons.check_circle : Icons.cancel,
          color: isSupported ? Colors.green : Colors.grey,
        ),
        title: Text(
          featureName,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: isSupported ? Colors.black : Colors.grey[600],
          ),
        ),
        trailing: isSupported
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Text(
                  value?.toString() ?? 'N/A',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              )
            : const Text(
                'Not supported',
                style: TextStyle(
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DeviceData?>(
      stream: ftmsBloc.ftmsDeviceDataControllerStream,
      builder: (c, snapshot) {
        if (!snapshot.hasData) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(AppLocalizations.of(context)!.waitingForDeviceData),
              ],
            ),
          );
        }

        final deviceData = snapshot.data!;
        final features = deviceData.getDeviceDataFeatures();
        final parameterValues = deviceData.getDeviceDataParameterValues();
        
        // Create a map using the ParameterName.name string as key
        final valueMap = <String, String>{};
        for (var param in parameterValues) {
          final formattedValue = '${(param.value * param.factor).toStringAsFixed(2)} ${param.unit}';
          valueMap[param.name.name] = formattedValue;
        }
        
        // Helper to get value by name string
        String? getValue(String paramNameString) => valueMap[paramNameString];

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.blue[50],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Device Data Features",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Device: ${Ftms().name}",
                      style: const TextStyle(fontSize: 14, color: Colors.black54),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.refresh, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          "Live data - Updates automatically",
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              
              // Features list - organized by category
              const Padding(
                padding: EdgeInsets.all(12.0),
                child: Text(
                  'Speed & Distance:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              _buildDataFeature(
                'Average Speed',
                features[DeviceDataFlag.avgSpeedFlag] ?? false,
                getValue(DeviceDataParameterName.avgSpeed.name),
              ),
              _buildDataFeature(
                'Total Distance',
                features[DeviceDataFlag.totalDistanceFlag] ?? false,
                getValue(DeviceDataParameterName.totalDistance.name),
              ),
              _buildDataFeature(
                'Instantaneous Pace',
                features[DeviceDataFlag.instPaceFlag] ?? false,
                getValue(DeviceDataParameterName.instPace.name),
              ),
              _buildDataFeature(
                'Average Pace',
                features[DeviceDataFlag.avgPaceFlag] ?? false,
                getValue(DeviceDataParameterName.avgPace.name),
              ),
              
              const Divider(),
              const Padding(
                padding: EdgeInsets.all(12.0),
                child: Text(
                  'Cadence:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              _buildDataFeature(
                'Instantaneous Cadence',
                features[DeviceDataFlag.instCadenceFlag] ?? false,
                getValue(DeviceDataParameterName.instCadence.name),
              ),
              _buildDataFeature(
                'Average Cadence',
                features[DeviceDataFlag.avgCadenceFlag] ?? false,
                getValue(DeviceDataParameterName.avgCadence.name),
              ),
              
              const Divider(),
              const Padding(
                padding: EdgeInsets.all(12.0),
                child: Text(
                  'Power & Resistance:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              _buildDataFeature(
                'Instantaneous Power',
                features[DeviceDataFlag.instPowerFlag] ?? false,
                getValue(DeviceDataParameterName.instPower.name),
              ),
              _buildDataFeature(
                'Average Power',
                features[DeviceDataFlag.avgPowerFlag] ?? false,
                getValue(DeviceDataParameterName.avgPower.name),
              ),
              _buildDataFeature(
                'Resistance Level',
                features[DeviceDataFlag.resistanceLevelFlag] ?? false,
                getValue(DeviceDataParameterName.resistanceLevel.name),
              ),
              
              const Divider(),
              const Padding(
                padding: EdgeInsets.all(12.0),
                child: Text(
                  'Heart Rate & Metabolics:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              _buildDataFeature(
                'Heart Rate',
                features[DeviceDataFlag.heartRateFlag] ?? false,
                getValue(DeviceDataParameterName.heartRate.name),
              ),
              _buildDataFeature(
                'Metabolic Equivalent',
                features[DeviceDataFlag.metabolicEquivalentFlag] ?? false,
                getValue(DeviceDataParameterName.metabolicEquivalent.name),
              ),
              _buildDataFeature(
                'Expended Energy',
                features[DeviceDataFlag.expendedEnergyFlag] ?? false,
                getValue(DeviceDataParameterName.totalEnergy.name),
              ),
              
              const Divider(),
              const Padding(
                padding: EdgeInsets.all(12.0),
                child: Text(
                  'Time:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              _buildDataFeature(
                'Elapsed Time',
                features[DeviceDataFlag.elapsedTimeFlag] ?? false,
                getValue(DeviceDataParameterName.elapsedTime.name),
              ),
              _buildDataFeature(
                'Remaining Time',
                features[DeviceDataFlag.remainingTimeFlag] ?? false,
                getValue(DeviceDataParameterName.remainingTime.name),
              ),
              
              const Divider(),
              const Padding(
                padding: EdgeInsets.all(12.0),
                child: Text(
                  'Elevation & Inclination:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              _buildDataFeature(
                'Elevation Gain',
                features[DeviceDataFlag.elevationGainFlag] ?? false,
                getValue(DeviceDataParameterName.positiveElevationGain.name),
              ),
              _buildDataFeature(
                'Inclination and Ramp Angle',
                features[DeviceDataFlag.inclinationAndRampAngleFlag] ?? false,
                getValue(DeviceDataParameterName.inclination.name),
              ),
              
              const Divider(),
              const Padding(
                padding: EdgeInsets.all(12.0),
                child: Text(
                  'Other:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              _buildDataFeature(
                'Step Count',
                features[DeviceDataFlag.stepCountFlag] ?? false,
                getValue(DeviceDataParameterName.stepPerMinute.name),
              ),
              _buildDataFeature(
                'Stride Count',
                features[DeviceDataFlag.strideCountFlag] ?? false,
                getValue(DeviceDataParameterName.strideCount.name),
              ),
              _buildDataFeature(
                'Average Stroke',
                features[DeviceDataFlag.avgStrokeFlag] ?? false,
                getValue(DeviceDataParameterName.avgStrokeRate.name),
              ),
              _buildDataFeature(
                'Movement Direction',
                features[DeviceDataFlag.movementDirectionFlag] ?? false,
                null,
              ),
              
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}
