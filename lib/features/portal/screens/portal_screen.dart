import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import 'package:dio/dio.dart';
import '../../../core/providers.dart';
import '../../../core/api_client.dart';
import '../providers/portal_provider.dart';

const _months = ['Jan','Fev','Mar','Abr','Mai','Jun','Jul','Ago','Set','Out','Nov','Dez'];

class PortalScreen extends ConsumerStatefulWidget {
  const PortalScreen({super.key});
  @override
  ConsumerState<PortalScreen> createState() => _PortalScreenState();
}

class _PortalScreenState extends ConsumerState<PortalScreen> {
  final _fmt = NumberFormat('#,##0.00', 'pt_BR');
  int? _filterYear, _filterMonth, _filterCuId;
  bool _downloading = false;
  final _years = List.generate(6, (i) => DateTime.now().year - i);

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final clientAsync = ref.watch(myClientProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meu Portal'),
        leading: auth.role != 'client'
            ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/dashboard'))
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: clientAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) {
          final is401 = e is DioException && e.response?.statusCode == 401;
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 8),
              Text(ApiClient.errorMessage(e), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              if (is401)
                ElevatedButton.icon(
                  onPressed: () async {
                    await ref.read(authProvider.notifier).logout();
                    if (context.mounted) context.go('/login');
                  },
                  icon: const Icon(Icons.login), label: const Text('Fazer login'),
                )
              else
                ElevatedButton.icon(
                  onPressed: () => ref.invalidate(myClientProvider),
                  icon: const Icon(Icons.refresh), label: const Text('Tentar novamente'),
                ),
            ]),
          );
        },
        data: (client) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final cur = ref.read(creditsFilterProvider);
            if (cur == null || cur.clientId != client.id) {
              ref.read(creditsFilterProvider.notifier).state =
                  CreditsFilter(clientId: client.id);
            }
          });

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(creditsProvider);
              ref.invalidate(myClientProvider);
              ref.invalidate(consumerUnitsProvider(client.id));
            },
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _clientCard(client)),
                SliverToBoxAdapter(child: _ucSelector(client.id)),
                SliverToBoxAdapter(child: _filtersRow(client.id)),
                SliverToBoxAdapter(child: _downloadRow(client.id)),
                _creditsList(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _clientCard(ClientInfo c) => Card(
    margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 40, height: 40,
            decoration: const BoxDecoration(color: Color(0xFF1A7F37), shape: BoxShape.circle),
            child: const Icon(Icons.person, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            Text(c.cpfCnpj, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: c.active ? Colors.green.shade100 : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(c.active ? 'Ativo' : 'Inativo',
              style: TextStyle(
                color: c.active ? Colors.green.shade800 : Colors.grey,
                fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ]),
        if (c.email != null) ...[
          const Divider(height: 20),
          Row(children: [
            const Icon(Icons.email_outlined, size: 14, color: Colors.grey),
            const SizedBox(width: 6),
            Text(c.email!, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          ]),
        ],
      ]),
    ),
  );

  Widget _ucSelector(int clientId) {
    final ucsAsync = ref.watch(consumerUnitsProvider(clientId));
    return ucsAsync.when(
      loading: () => const SizedBox(height: 48, child: Center(child: LinearProgressIndicator())),
      error: (_, __) => const SizedBox.shrink(),
      data: (ucs) {
        if (ucs.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
              child: Row(children: [
                const Icon(Icons.electric_meter_outlined, size: 16, color: Color(0xFF1A7F37)),
                const SizedBox(width: 6),
                Text('Unidades Consumidoras (${ucs.length})',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1A7F37))),
              ]),
            ),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  // Chip "Todas"
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FilterChip(
                      label: const Text('Todas'),
                      selected: _filterCuId == null,
                      onSelected: (_) {
                        setState(() => _filterCuId = null);
                        _applyFilter(clientId);
                      },
                      selectedColor: const Color(0xFF1A7F37),
                      labelStyle: TextStyle(
                        color: _filterCuId == null ? Colors.white : null,
                        fontSize: 12,
                      ),
                      showCheckmark: false,
                    ),
                  ),
                  // Chip por UC
                  ...ucs.map((uc) {
                    final id = uc['id'] as int;
                    final num = uc['installation_number'] as String;
                    final selected = _filterCuId == id;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: FilterChip(
                        avatar: const Icon(Icons.bolt, size: 14),
                        label: Text(num),
                        selected: selected,
                        onSelected: (_) {
                          setState(() => _filterCuId = selected ? null : id);
                          _applyFilter(clientId);
                        },
                        selectedColor: const Color(0xFF1A7F37),
                        labelStyle: TextStyle(
                          color: selected ? Colors.white : null,
                          fontSize: 12,
                        ),
                        showCheckmark: false,
                      ),
                    );
                  }),
                ],
              ),
            ),
            // Detalhes da UC selecionada
            if (_filterCuId != null) _ucDetail(ucs, _filterCuId!),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  Widget _ucDetail(List<Map<String, dynamic>> ucs, int ucId) {
    final uc = ucs.firstWhere((u) => u['id'] == ucId, orElse: () => {});
    if (uc.isEmpty) return const SizedBox.shrink();
    final fmt = NumberFormat('#,##0.0', 'pt_BR');
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A7F37).withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1A7F37).withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.electric_meter, color: Color(0xFF1A7F37), size: 20),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('UC ${uc['installation_number']}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          if (uc['address'] != null)
            Text(uc['address'], style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ])),
        if (uc['estimated_monthly_credit_kwh'] != null)
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${fmt.format(double.tryParse(uc['estimated_monthly_credit_kwh'].toString()) ?? 0)} kWh',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1A7F37))),
            const Text('estimado/mês', style: TextStyle(fontSize: 10, color: Colors.grey)),
          ]),
      ]),
    );
  }

  Widget _filtersRow(int clientId) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(children: [
      Expanded(child: DropdownButtonFormField<int?>(
        initialValue: _filterYear,
        decoration: const InputDecoration(labelText: 'Ano', isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
        items: [
          const DropdownMenuItem(value: null, child: Text('Todos')),
          ..._years.map((y) => DropdownMenuItem(value: y, child: Text('$y'))),
        ],
        onChanged: (v) {
          setState(() => _filterYear = v);
          _applyFilter(clientId);
        },
      )),
      const SizedBox(width: 8),
      Expanded(child: DropdownButtonFormField<int?>(
        initialValue: _filterMonth,
        decoration: const InputDecoration(labelText: 'Mês', isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
        items: [
          const DropdownMenuItem(value: null, child: Text('Todos')),
          ...List.generate(12, (i) => DropdownMenuItem(value: i+1, child: Text(_months[i]))),
        ],
        onChanged: (v) {
          setState(() => _filterMonth = v);
          _applyFilter(clientId);
        },
      )),
    ]),
  );

  Widget _downloadRow(int clientId) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
    child: Row(children: [
      Expanded(child: OutlinedButton.icon(
        onPressed: _downloading ? null : () => _download(clientId, 'pdf'),
        icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
        label: const Text('PDF', style: TextStyle(color: Colors.red)),
        style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
      )),
      const SizedBox(width: 8),
      Expanded(child: OutlinedButton.icon(
        onPressed: _downloading ? null : () => _download(clientId, 'excel'),
        icon: const Icon(Icons.table_chart, color: Color(0xFF1A7F37)),
        label: const Text('Excel', style: TextStyle(color: Color(0xFF1A7F37))),
        style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF1A7F37))),
      )),
      if (_downloading) ...[
        const SizedBox(width: 8),
        const SizedBox(width: 20, height: 20,
          child: CircularProgressIndicator(strokeWidth: 2)),
      ],
    ]),
  );

  Widget _creditsList() {
    final creditsAsync = ref.watch(creditsProvider);
    return creditsAsync.when(
      loading: () => const SliverFillRemaining(child: Center(child: CircularProgressIndicator())),
      error: (e, _) => SliverFillRemaining(child: Center(child: Text(ApiClient.errorMessage(e)))),
      data: (records) {
        if (records.isEmpty) {
          return const SliverFillRemaining(
            child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.inbox_outlined, size: 48, color: Colors.grey),
              SizedBox(height: 8),
              Text('Nenhum registro encontrado', style: TextStyle(color: Colors.grey)),
            ])),
          );
        }
        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (ctx, i) {
              if (i == 0) return _creditsHeader(records);
              return _creditTile(records[i - 1]);
            },
            childCount: records.length + 1,
          ),
        );
      },
    );
  }

  Widget _creditsHeader(List<CreditRecord> records) {
    final totalRecebido = records.fold(0.0, (s, r) => s + r.received);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('Histórico de Créditos',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const Spacer(),
          Text('${records.length} registro(s)',
            style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ]),
        if (records.isNotEmpty) Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text('Total recebido: ${_fmt.format(totalRecebido)} kWh',
            style: const TextStyle(fontSize: 12, color: Color(0xFF1A7F37))),
        ),
      ]),
    );
  }

  Widget _creditTile(CreditRecord r) {
    final isOk = r.calcStatus == 'exact';
    final isMissing = r.calcStatus == 'missing';
    final color = isMissing ? Colors.red : isOk ? Colors.blue : Colors.green;
    final statusLabel = isMissing ? 'Faltante' : isOk ? 'Exato' : 'Excedente';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('${_months[r.month - 1]}/${r.year}',
              style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            if (_filterCuId == null)
              Text(r.installationNumber,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.grey)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(statusLabel,
                style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            _InfoCol('Recebido', '${_fmt.format(r.received)} kWh'),
            _InfoCol('Esperado', '${_fmt.format(r.estimated)} kWh'),
            _InfoCol('Diferença',
              '${r.difference >= 0 ? '+' : ''}${_fmt.format(r.difference)} kWh',
              color: r.difference < 0 ? Colors.red : r.difference > 0 ? Colors.green : null),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            _InfoCol('Consumo', '${_fmt.format(r.consumption)} kWh'),
            _InfoCol('Saldo Acum.', '${_fmt.format(r.accumulated)} kWh'),
            const Expanded(child: SizedBox()),
          ]),
        ]),
      ),
    );
  }

  void _applyFilter(int clientId) {
    ref.read(creditsFilterProvider.notifier).state = CreditsFilter(
      clientId: clientId, year: _filterYear, month: _filterMonth,
      consumerUnitId: _filterCuId,
    );
  }

  Future<void> _download(int clientId, String type) async {
    setState(() => _downloading = true);
    try {
      final dio = await ApiClient.get();
      final params = <String, dynamic>{
        if (_filterYear != null) 'year': _filterYear,
        if (_filterMonth != null) 'month': _filterMonth,
        if (_filterCuId != null) 'consumer_unit_id': _filterCuId,
      };

      late String path;
      late String filename;
      if (type == 'pdf') {
        final resp = await dio.get('/reports/client/$clientId/pdf',
          queryParameters: params,
          options: Options(responseType: ResponseType.bytes));
        final dir = await getTemporaryDirectory();
        filename = 'relatorio_gridcred.pdf';
        path = '${dir.path}/$filename';
        await File(path).writeAsBytes(resp.data as List<int>);
      } else {
        params['client_id'] = clientId;
        final resp = await dio.get('/reports/credits/excel',
          queryParameters: params,
          options: Options(responseType: ResponseType.bytes));
        final dir = await getTemporaryDirectory();
        filename = 'creditos_gd.xlsx';
        path = '${dir.path}/$filename';
        await File(path).writeAsBytes(resp.data as List<int>);
      }

      final result = await OpenFilex.open(path);
      if (result.type != ResultType.done && mounted) {
        await SharePlus.instance.share(ShareParams(files: [XFile(path)], text: filename));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiClient.errorMessage(e)), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }
}

class _InfoCol extends StatelessWidget {
  final String label, value;
  final Color? color;
  const _InfoCol(this.label, this.value, {this.color});

  @override
  Widget build(BuildContext context) => Expanded(child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: color)),
    ],
  ));
}
