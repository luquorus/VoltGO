import 'package:flutter/material.dart';
import '../theme/admin_theme.dart';
import '../utils/responsive_utils.dart';
import '../widgets/admin_scaffold.dart';
import 'charging_stations_list_screen.dart';

class ChargingStationsScreen extends StatelessWidget {
  const ChargingStationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Charging Stations',
      body: Padding(
        padding: EdgeInsets.all(responsivePadding(context)),
        child: const ChargingStationsListScreen(),
      ),
    );
  }
}
