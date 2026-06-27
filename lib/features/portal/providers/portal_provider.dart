import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_client.dart';

class ClientInfo {
  final int id;
  final String name, cpfCnpj;
  final String? email, phone;
  final bool active;
  const ClientInfo({required this.id, required this.name, required this.cpfCnpj,
    this.email, this.phone, required this.active});
  factory ClientInfo.fromJson(Map<String, dynamic> j) => ClientInfo(
    id: j['id'], name: j['name'], cpfCnpj: j['cpf_cnpj'],
    email: j['email'], phone: j['phone'],
    active: j['status'] == 'active',
  );
}

class CreditRecord {
  final String installationNumber;
  final int month, year;
  final double received, estimated, difference, consumption, accumulated;
  final String calcStatus;

  const CreditRecord({
    required this.installationNumber, required this.month, required this.year,
    required this.received, required this.estimated, required this.difference,
    required this.consumption, required this.accumulated, required this.calcStatus,
  });

  factory CreditRecord.fromJson(Map<String, dynamic> j) {
    final calc = j['calculation'] as Map<String, dynamic>?;
    double _d(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0.0;
    return CreditRecord(
      installationNumber: j['installation_number'] ?? '',
      month: j['reference_month'] ?? 0,
      year: j['reference_year'] ?? 0,
      received: _d(j['transferred_credit_kwh']),
      estimated: _d(calc?['estimated_kwh']),
      difference: _d(calc?['difference_kwh']),
      consumption: _d(j['consumption_kwh']),
      accumulated: _d(j['accumulated_balance_kwh']),
      calcStatus: calc?['status'] ?? 'exact',
    );
  }
}

// Provider do perfil do cliente logado
final myClientProvider = FutureProvider<ClientInfo>((ref) async {
  final dio = await ApiClient.get();
  final resp = await dio.get('/clients/me');
  return ClientInfo.fromJson(resp.data as Map<String, dynamic>);
});

// Params para filtros
class CreditsFilter {
  final int clientId;
  final int? year, month, consumerUnitId;
  const CreditsFilter({required this.clientId, this.year, this.month, this.consumerUnitId});

  CreditsFilter copyWith({int? year, int? month, int? consumerUnitId,
    bool clearYear = false, bool clearMonth = false, bool clearCu = false}) => CreditsFilter(
    clientId: clientId,
    year: clearYear ? null : (year ?? this.year),
    month: clearMonth ? null : (month ?? this.month),
    consumerUnitId: clearCu ? null : (consumerUnitId ?? this.consumerUnitId),
  );
}

final creditsFilterProvider = StateProvider<CreditsFilter?>((ref) => null);

final creditsProvider = FutureProvider<List<CreditRecord>>((ref) async {
  final filter = ref.watch(creditsFilterProvider);
  if (filter == null) return [];
  final dio = await ApiClient.get();
  final params = <String, dynamic>{
    'client_id': filter.clientId, 'limit': 200,
    if (filter.year != null) 'year': filter.year,
    if (filter.month != null) 'month': filter.month,
    if (filter.consumerUnitId != null) 'consumer_unit_id': filter.consumerUnitId,
  };
  final resp = await dio.get('/credits/', queryParameters: params);
  final items = resp.data['items'] as List;
  return items.map((e) => CreditRecord.fromJson(e as Map<String, dynamic>)).toList()
    ..sort((a, b) => b.year != a.year ? b.year - a.year : b.month - a.month);
});

final consumerUnitsProvider = FutureProvider.family<List<Map<String, dynamic>>, int>((ref, clientId) async {
  final dio = await ApiClient.get();
  final resp = await dio.get('/consumer-units/me');
  return List<Map<String, dynamic>>.from(resp.data as List);
});
