import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/providers.dart';
import '../providers/dashboard_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dash = ref.watch(dashboardProvider);
    final auth = ref.watch(authProvider);
    final fmt = NumberFormat('#,##0.00', 'pt_BR');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: auth.username ?? '',
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: Container(
            color: const Color(0xFF1A7F37),
            child: Row(children: [
              _NavBtn('Portal', Icons.supervised_user_circle,
                  () => context.go('/portal')),
            ]),
          ),
        ),
      ),
      body: dash.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 8),
            Text('Erro ao carregar dashboard', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(e.toString(), style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => ref.invalidate(dashboardProvider),
              icon: const Icon(Icons.refresh), label: const Text('Tentar novamente'),
            ),
          ]),
        ),
        data: (d) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(dashboardProvider),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Stats grid
              GridView.count(
                crossAxisCount: 2, shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12, mainAxisSpacing: 12,
                childAspectRatio: 1.6,
                children: [
                  _StatCard('Clientes', d.totalClients.toString(), Icons.people, const Color(0xFF1A7F37)),
                  _StatCard('Unidades', d.totalUnits.toString(), Icons.home, Colors.blue),
                  _StatCard('Usinas', d.totalPlants.toString(), Icons.solar_power, Colors.orange),
                  _StatCard('Registros', d.totalRecords.toString(), Icons.storage, Colors.purple),
                ],
              ),
              const SizedBox(height: 12),

              // Missing / Excess
              Row(children: [
                Expanded(child: _KwhCard('Créditos Faltantes',
                    fmt.format(d.totalMissingKwh), Colors.red)),
                const SizedBox(width: 12),
                Expanded(child: _KwhCard('Créditos Excedentes',
                    fmt.format(d.totalExcessKwh), Colors.green)),
              ]),
              const SizedBox(height: 16),

              // Discrepâncias
              if (d.discrepancies.isNotEmpty) ...[
                Card(
                  color: Colors.red.shade50,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.red.shade200),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Row(children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.red),
                        const SizedBox(width: 8),
                        Text('Discrepâncias — ${d.discPeriod ?? ''}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text('${d.discrepancies.length}',
                            style: const TextStyle(color: Colors.white, fontSize: 12)),
                        ),
                      ]),
                    ),
                    const Divider(height: 1),
                    ...d.discrepancies.map((r) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.flash_on, color: Colors.red, size: 18),
                      title: Text(r['installation_number'] ?? '', style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
                      subtitle: Text('${r['client_name']} · ${r['plant_name']}',
                        style: const TextStyle(fontSize: 11)),
                      trailing: Text(
                        fmt.format((r['difference_kwh'] ?? 0).toDouble()),
                        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    )),
                  ]),
                ),
              ] else
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(children: const [
                      Icon(Icons.check_circle, color: Colors.green),
                      SizedBox(width: 8),
                      Text('Nenhuma discrepância no último período'),
                    ]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _NavBtn(this.label, this.icon, this.onTap);

  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: onTap,
    icon: Icon(icon, color: Colors.white70, size: 16),
    label: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
  );
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatCard(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) => Card(
    color: color.withValues(alpha:0.1),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500)),
          Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold)),
        ]),
      ]),
    ),
  );
}

class _KwhCard extends StatelessWidget {
  final String label, value;
  final Color color;
  const _KwhCard(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Card(
    color: color.withValues(alpha:0.08),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: color.withValues(alpha:0.3)),
    ),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(children: [
        Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text('$value kWh', style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center),
      ]),
    ),
  );
}
