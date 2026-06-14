import 'package:flutter/material.dart';
import '../theme/admin_theme.dart';
import '../utils/responsive_utils.dart';
import '../widgets/admin_scaffold.dart';
import 'battery_swap_stations_list_screen.dart';

class BatterySwapStationsScreen extends StatelessWidget {
  const BatterySwapStationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Battery Swap Stations',
      body: Padding(
        padding: responsivePadding(context),
        child: const BatterySwapStationsListScreen(),
      ),
    );
  }
}
