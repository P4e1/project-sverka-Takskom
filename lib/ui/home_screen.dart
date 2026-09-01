import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils/number_parse.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _query = '';
  ReconStatus? _filter;
  final _toleranceCtrl = TextEditingController(text: '0.01');

  @override
  void dispose() {
    _toleranceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      body: Column(
        children: [
          _buildHeader(),
          if (state.error != null)
            Container(
              width: double.infinity,
              color: AppColors.redDeep,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, size: 16, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(state.error!,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13))),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16, color: Colors.white),
                    onPressed: state.clearError,
                  ),
                ],
              ),
            ),
          Expanded(
            child: Row(
              children: [
                SizedBox(width: 400, child: _buildLeft(state)),
                const VerticalDivider(width: 1),
                Expanded(child: _buildRight(state)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 80,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.black, AppColors.redDeep],
        ),
        border: Border(bottom: BorderSide(color: AppColors.red, width: 2)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          _logo('assets/logo_letunovsky.png', 56),
          const SizedBox(width: 16),
          Container(width: 1, height: 40, color: AppColors.border),
          const SizedBox(width: 16),
          _logo('assets/logo_myasnoy.png', 30),
          const Spacer(),
          const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('СВЕРКА РОЗНИЧНЫХ ПРОДАЖ',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.6,
                      color: AppColors.cream)),
              SizedBox(height: 3),
              Text('Таксском-Касса  ↔  1С',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _logo(String asset, double height) {
    return Image.asset(
      asset,
      height: height,
      errorBuilder: (_, __, ___) => Container(
        height: height,
        width: height * 2.2,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text('logo',
            style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
      ),
    );
  }

  Widget _buildLeft(AppState state) {
    return Container(
      color: AppColors.surface,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _card(
            step: '1',
            title: 'Справочник магазинов',
            subtitle: state.directoryReady
                ? '${state.stores.length} магазинов'
                : 'Колонка A — магазин, колонка B — адрес',
            done: state.directoryReady,
            child: _pickButton(
              label: state.directoryReady ? 'Обновить' : 'Загрузить xlsx',
              icon: Icons.folder_open,
              onTap: () async {
                final res = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['xlsx'],
                );
                final path = res?.files.single.path;
                if (path != null && mounted) {
                  context.read<AppState>().loadDirectory(path);
                }
              },
            ),
          ),
          const SizedBox(height: 12),
          _card(
            step: '2',
            title: 'Отчёт Таксском',
            subtitle: state.taxcomHint ?? 'Сводный отчёт по сменам',
            done: state.taxcomReady,
            child: _pickButton(
              label: state.taxcomReady ? 'Заменить' : 'Выбрать xlsx',
              icon: Icons.table_chart_outlined,
              onTap: () async {
                final res = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['xlsx'],
                );
                final path = res?.files.single.path;
                if (path != null && mounted) {
                  context.read<AppState>().loadTaxcom(path);
                }
              },
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    _badge('3'),
                    const SizedBox(width: 10),
                    const Text('Данные из 1С',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    if (state.onecReady)
                      const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Icon(Icons.check_circle,
                            color: AppColors.ok, size: 18),
                      ),
                  ]),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Магазины',
                                style: TextStyle(
                                    fontSize: 11, color: AppColors.textMuted)),
                            const SizedBox(height: 4),
                            TextField(
                              maxLines: 10,
                              minLines: 6,
                              style: const TextStyle(
                                  fontFamily: 'monospace', fontSize: 11),
                              decoration: const InputDecoration(
                                hintText: 'Мичуринск\nЯрмарка Тула\n…',
                                isDense: true,
                              ),
                              onChanged: (v) =>
                                  state.applyTwoColumn(v, state.amountsText),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 110,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Суммы',
                                style: TextStyle(
                                    fontSize: 11, color: AppColors.textMuted)),
                            const SizedBox(height: 4),
                            TextField(
                              maxLines: 10,
                              minLines: 6,
                              style: const TextStyle(
                                  fontFamily: 'monospace', fontSize: 11),
                              decoration: const InputDecoration(
                                hintText: '29 347,10\n33 948,00\n…',
                                isDense: true,
                              ),
                              onChanged: (v) =>
                                  state.applyTwoColumn(state.namesText, v),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (state.pasteProblems.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '⚠ ${state.pasteProblems.first}',
                        style: const TextStyle(
                            color: AppColors.warn, fontSize: 11),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Text('Допуск, ₽',
                      style: TextStyle(
                          color: AppColors.textMuted, fontSize: 13)),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 80,
                    child: TextField(
                      controller: _toleranceCtrl,
                      decoration: const InputDecoration(isDense: true),
                      onChanged: (v) =>
                          state.setTolerance(parseAmount(v) ?? 0),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({
    required String step,
    required String title,
    required String subtitle,
    required bool done,
    required Widget child,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              _badge(step),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600))),
              if (done)
                const Icon(Icons.check_circle, color: AppColors.ok, size: 18),
            ]),
            const SizedBox(height: 4),
            Text(subtitle,
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 12)),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }

  Widget _badge(String n) => Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
            color: AppColors.red, shape: BoxShape.circle),
        child: Text(n,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white)),
      );

  Widget _pickButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16),
        label: Text(label),
      ),
    );
  }

  Widget _buildRight(AppState state) {
    final summary = state.summary;

    if (!state.canReconcile) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Загрузи справочник и отчёт Таксском,\nвставь данные из 1С — результат появится здесь.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: AppColors.textMuted, fontSize: 14, height: 1.6),
          ),
        ),
      );
    }

    final rows = summary.rows.where((r) {
      if (_filter != null && r.status != _filter) {
        return false;
      }
      if (_query.isEmpty) return true;
      return r.storeName.toLowerCase().contains(_query.toLowerCase());
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(
            children: [
              _kpi('Совпало', '${summary.okCount}', AppColors.ok),
              const SizedBox(width: 10),
              _kpi(
                  'Расхождений',
                  '${summary.mismatchCount}',
                  summary.mismatchCount > 0
                      ? AppColors.redBright
                      : AppColors.ok),
              const SizedBox(width: 10),
              _kpi(
                  'Дельта',
                  '${formatMoney(summary.totalDiff)} ₽',
                  summary.totalDiff.abs() <= state.tolerance
                      ? AppColors.ok
                      : AppColors.redBright),
              const Spacer(),
              SizedBox(
                width: 200,
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Поиск',
                    isDense: true,
                    prefixIcon: Icon(Icons.search, size: 16),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: state.busy
                    ? null
                    : () async {
                        final path = await FilePicker.platform.saveFile(
                          fileName: 'Сверка.csv',
                          type: FileType.custom,
                          allowedExtensions: ['csv'],
                        );
                        if (path != null && mounted) {
                          await context.read<AppState>().exportCsv(path);
                        }
                      },
                icon: const Icon(Icons.download, size: 16),
                label: const Text('Экспорт'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 6,
            children: [
              _chip('Все', null, summary.rows.length),
              _chip('Расхождения', ReconStatus.mismatch,
                  summary.mismatchCount),
              _chip('Нет в 1С', ReconStatus.missingInOnec,
                  summary.missingCount),
              _chip('Совпало', ReconStatus.ok, summary.okCount),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: rows.isEmpty
              ? const Center(
                  child: Text('Нет строк по фильтру',
                      style: TextStyle(color: AppColors.textMuted)))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: rows.length,
                  itemBuilder: (_, i) {
                    final row = rows[i];
                    return _RowCard(
                      row: row,
                      onMerge: () =>
                          showGroupDialog(context, state, row.storeName),
                      onUngroup: state.groups.isEmpty
                          ? null
                          : () => state.removeFromGroup(row.storeName),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _kpi(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 10.5,
                  color: AppColors.textMuted,
                  letterSpacing: 0.5)),
          const SizedBox(height: 3),
          Text(value,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  Widget _chip(String label, ReconStatus? status, int count) {
    final active = _filter == status;
    return ChoiceChip(
      label: Text('$label ($count)',
          style: TextStyle(
              fontSize: 12,
              color: active ? Colors.white : AppColors.textMuted)),
      selected: active,
      onSelected: (_) => setState(() => _filter = status),
      backgroundColor: AppColors.surfaceAlt,
      selectedColor: AppColors.redDeep,
      side: const BorderSide(color: AppColors.border),
    );
  }
}

Future<void> showGroupDialog(
    BuildContext context, AppState state, String memberLabel) async {
  final names = state.stores.map((s) => s.name).toList()..sort();

  final picked = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Объединить «$memberLabel» с',
          style: const TextStyle(fontSize: 15)),
      content: SizedBox(
        width: 420,
        height: 420,
        child: ListView.builder(
          itemCount: names.length,
          itemBuilder: (_, i) => ListTile(
            dense: true,
            title: Text(names[i], style: const TextStyle(fontSize: 13)),
            onTap: () => Navigator.pop(ctx, names[i]),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Отмена'),
        ),
      ],
    ),
  );

  if (picked != null && picked != memberLabel) {
    await state.addToGroup(memberLabel, picked);
  }
}

class _RowCard extends StatelessWidget {
  const _RowCard({required this.row, this.onMerge, this.onUngroup});

  final ReconRow row;
  final VoidCallback? onMerge;
  final VoidCallback? onUngroup;

  Color get _color => switch (row.status) {
        ReconStatus.ok => AppColors.ok,
        ReconStatus.mismatch => AppColors.redBright,
        _ => AppColors.warn,
      };

  bool get _canMerge =>
      onMerge != null && row.taxcomAmount == null && row.onecAmount != null;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: _color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(row.storeName,
                                style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600)),
                            if (row.taxcomLabels.isNotEmpty &&
                                row.taxcomLabels.first != row.storeName)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  row.taxcomLabels.join(' | '),
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textMuted),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('ОФД: ${formatMoney(row.taxcomAmount)} ₽',
                              style: const TextStyle(fontSize: 12)),
                          Text('1С: ${formatMoney(row.onecAmount)} ₽',
                              style: const TextStyle(fontSize: 12)),
                          if (row.taxcomAmount != null &&
                              row.onecAmount != null)
                            Text(
                              'Δ ${formatMoney(row.diff)} ₽',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: row.status == ReconStatus.ok
                                      ? AppColors.textMuted
                                      : _color),
                            ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(
                          color: _color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                          border:
                              Border.all(color: _color.withValues(alpha: 0.4)),
                        ),
                        child: Text(row.status.title,
                            style: TextStyle(
                                color: _color,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600)),
                      ),
                      if (_canMerge)
                        IconButton(
                          icon: const Icon(Icons.merge_type, size: 18),
                          tooltip: 'Объединить с другой точкой',
                          onPressed: onMerge,
                        ),
                      if (!_canMerge && onUngroup != null)
                        IconButton(
                          icon: const Icon(Icons.link_off, size: 16),
                          tooltip: 'Разъединить',
                          onPressed: onUngroup,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
