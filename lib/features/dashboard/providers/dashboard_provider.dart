import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_client.dart';

class DashboardData {
  final int totalClients, totalUnits, totalPlants, totalRecords;
  final double totalMissingKwh, totalExcessKwh;
  final List<Map<String, dynamic>> discrepancies;
  final String? discPeriod;
  final List<Map<String, dynamic>> monthlyCredits;

  const DashboardData({
    required this.totalClients, required this.totalUnits,
    required this.totalPlants, required this.totalRecords,
    required this.totalMissingKwh, required this.totalExcessKwh,
    required this.discrepancies, required this.monthlyCredits,
    this.discPeriod,
  });

  factory DashboardData.fromJson(Map<String, dynamic> j) {
    final s = j['stats'] as Map<String, dynamic>;
    return DashboardData(
      totalClients: s['total_clients'] ?? 0,
      totalUnits: s['total_consumer_units'] ?? 0,
      totalPlants: s['total_power_plants'] ?? 0,
      totalRecords: s['total_credit_records'] ?? 0,
      totalMissingKwh: (s['total_missing_kwh'] ?? 0).toDouble(),
      totalExcessKwh: (s['total_excess_kwh'] ?? 0).toDouble(),
      discrepancies: List<Map<String, dynamic>>.from(j['discrepancies'] ?? []),
      discPeriod: j['disc_period'],
      monthlyCredits: List<Map<String, dynamic>>.from(j['monthly_credits'] ?? []),
    );
  }
}

final dashboardProvider = FutureProvider<DashboardData>((ref) async {
  final dio = await ApiClient.get();
  final resp = await dio.get('/dashboard/');
  return DashboardData.fromJson(resp.data as Map<String, dynamic>);
});
