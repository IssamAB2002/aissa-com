import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../analytics/providers/analytics_provider.dart';
import '../models/inventaire.dart';
import '../models/inventaire_resolution.dart';
import '../models/inventaire_stock_line.dart';
import '../widgets/financial_export_option_dialog.dart';

/// Builds a finalized Inventaire session into an .xlsx workbook and hands
/// it off to the OS share sheet, so the admin can send it to an accountant.
class InventaireExportService {
  static final _dateFmt = DateFormat('dd-MM-yyyy');

  Future<void> exportAndShare({
    required Inventaire inventaire,
    required List<InventaireStockLine> stockLines,
    required List<InventaireResolution> resolvedOrders,
    required List<InventaireResolution> resolvedPurchases,
    List<InventaireResolution> resolvedOrderPayments = const [],
    List<InventaireResolution> resolvedPurchasePayments = const [],
    FinancialExportOption financialOption = FinancialExportOption.none,
    PeriodSummary? totalSummary,
    List<PeriodSummary> dailySummaries = const [],
    List<PeriodSummary> weeklySummaries = const [],
    List<PeriodSummary> monthlySummaries = const [],
  }) async {
    final excel = Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet();

    _writeSummarySheet(excel, inventaire, stockLines);
    _writeStockSheet(excel, stockLines);
    _writeResolutionSheet(excel, 'Orders Resolved', resolvedOrders);
    _writeResolutionSheet(excel, 'Purchases Resolved', resolvedPurchases);
    _writeResolutionSheet(
        excel, 'Orders Payment Settled', resolvedOrderPayments);
    _writeResolutionSheet(
        excel, 'Purchases Payment Settled', resolvedPurchasePayments);

    if (financialOption != FinancialExportOption.none && totalSummary != null) {
      _writeFinancialSummarySheet(excel, totalSummary);
      if (financialOption == FinancialExportOption.daily ||
          financialOption == FinancialExportOption.all) {
        _writeFinancialBucketSheet(excel, 'Financial Daily', dailySummaries);
      }
      if (financialOption == FinancialExportOption.weekly ||
          financialOption == FinancialExportOption.all) {
        _writeFinancialBucketSheet(excel, 'Financial Weekly', weeklySummaries);
      }
      if (financialOption == FinancialExportOption.monthly ||
          financialOption == FinancialExportOption.all) {
        _writeFinancialBucketSheet(
            excel, 'Financial Monthly', monthlySummaries);
      }
    }

    if (defaultSheet != null) excel.delete(defaultSheet);

    final bytes = excel.encode();
    if (bytes == null) {
      throw StateError('Failed to encode Inventaire workbook');
    }

    final from = inventaire.periodStart != null
        ? _dateFmt.format(inventaire.periodStart!)
        : 'debut';
    final to = _dateFmt.format(inventaire.periodEnd);
    final fileName = 'Inventaire_${from}_au_$to.xlsx';

    // XFile.fromData keeps the bytes in memory instead of writing to the
    // filesystem — works on mobile (opens the share sheet) and web (no
    // path_provider/dart:io support there, so this avoids that entirely).
    final file = XFile.fromData(
      Uint8List.fromList(bytes),
      name: fileName,
      mimeType:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );

    await Share.shareXFiles([file], text: 'Inventaire du $from au $to');
  }

  void _writeSummarySheet(
    Excel excel,
    Inventaire inventaire,
    List<InventaireStockLine> stockLines,
  ) {
    final sheet = excel['Summary'];
    final from = inventaire.periodStart != null
        ? _dateFmt.format(inventaire.periodStart!)
        : 'Depuis le début';
    final to = _dateFmt.format(inventaire.periodEnd);
    sheet.appendRow([TextCellValue('Period'), TextCellValue('$from → $to')]);
    sheet.appendRow([
      TextCellValue('Total stock valuation (cost price)'),
      DoubleCellValue(inventaire.totalStockValuation),
    ]);
    sheet.appendRow([
      TextCellValue('Products counted'),
      IntCellValue(stockLines.length),
    ]);
    sheet.appendRow([
      TextCellValue('Orders resolved'),
      IntCellValue(inventaire.totalOrdersResolved),
    ]);
    sheet.appendRow([
      TextCellValue('Purchases resolved'),
      IntCellValue(inventaire.totalPurchasesResolved),
    ]);
  }

  void _writeStockSheet(Excel excel, List<InventaireStockLine> lines) {
    final sheet = excel['Stock'];
    sheet.appendRow([
      TextCellValue('Product'),
      TextCellValue('System qty (before)'),
      TextCellValue('Counted qty'),
      TextCellValue('Delta'),
      TextCellValue('Cost price'),
      TextCellValue('Valuation'),
    ]);
    for (final line in lines) {
      sheet.appendRow([
        TextCellValue(line.productName),
        IntCellValue(line.systemQtyBefore),
        IntCellValue(line.countedQty),
        IntCellValue(line.delta),
        DoubleCellValue(line.costPrice),
        DoubleCellValue(line.valuation),
      ]);
    }
  }

  void _writeFinancialSummarySheet(Excel excel, PeriodSummary total) {
    final sheet = excel['Financial Summary'];
    sheet.appendRow(
        [TextCellValue('Total Income'), DoubleCellValue(total.revenue)]);
    sheet.appendRow(
        [TextCellValue('Total Expenses'), DoubleCellValue(total.expenses)]);
    sheet.appendRow(
        [TextCellValue('Net Profit'), DoubleCellValue(total.netProfit)]);
  }

  void _writeFinancialBucketSheet(
    Excel excel,
    String sheetName,
    List<PeriodSummary> summaries,
  ) {
    final sheet = excel[sheetName];
    sheet.appendRow([
      TextCellValue('Period'),
      TextCellValue('Income'),
      TextCellValue('Expenses'),
      TextCellValue('Net Profit'),
    ]);
    // monthlyInRange/weeklyInRange/dailyInRange return most-recent-first;
    // write chronologically ascending instead.
    for (final s in summaries.reversed) {
      sheet.appendRow([
        TextCellValue(s.label),
        DoubleCellValue(s.revenue),
        DoubleCellValue(s.expenses),
        DoubleCellValue(s.netProfit),
      ]);
    }
  }

  void _writeResolutionSheet(
    Excel excel,
    String sheetName,
    List<InventaireResolution> resolutions,
  ) {
    final sheet = excel[sheetName];
    sheet.appendRow([
      TextCellValue('Reference'),
      TextCellValue('Previous status'),
      TextCellValue('Final status'),
    ]);
    for (final r in resolutions) {
      sheet.appendRow([
        TextCellValue(r.label),
        TextCellValue(r.previousStatus),
        TextCellValue(r.newStatus),
      ]);
    }
  }
}
