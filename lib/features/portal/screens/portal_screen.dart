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
        error: (e, _) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 8),
            Text(ApiClient.errorMessage(e), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => ref.invalidate(myClientProvider),
              icon: const Icon(Icons.refresh), label: const Text('Tentar novamente'),
            ),
          ]),
        ),
        data: (client) {
          // Inicializa filtro com o id do cliente
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
            },
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _clientCard(client)),
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
    margin: const EdgeInsets.all(16),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF1A7F37), shape: BoxShape.circle),
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

  Widget _filtersRow(int clientId) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(children: [
      // Ano
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
      // Mês
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
        style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFF1A7F37))),
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
      loading: () => const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator())),
      error: (e, _) => SliverFillRemaining(
        child: Center(child: Text(ApiClient.errorMessage(e)))),
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
              if (i == 0) return _creditsHeader(records.length);
              return _creditTile(records[i - 1]);
            },
            childCount: records.length + 1,
          ),
        );
      },
    );
  }

  Widget _creditsHeader(int count) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Row(children: [
      Text('Histórico de Créditos',
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      const Spacer(),
      Text('$count registro(s)', style: const TextStyle(color: Colors.grey, fontSize: 12)),
    ]),
  );

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
            Text(r.installationNumber,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.grey)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha:0.15),
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
