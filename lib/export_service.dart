import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import 'app_state.dart';
import 'models.dart';

class ExportService {
  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm');
  static final DateFormat _fileDateFormat = DateFormat('yyyyMMdd_HHmmss');

  static Future<void> exportCsv(AppState state) async {
    if (kIsWeb) {
      throw UnsupportedError('Web 端暂不支持 CSV 导出，请使用 PDF 导出或移动端。');
    }

    final unit = state.profile.weightUnit;
    final rows = <List<Object>>[
      [
        '记录类型',
        '记录ID',
        '日期',
        '餐次',
        '食物',
        '食物ID',
        '克数',
        '热量(kcal)',
        '备注',
        '来源',
        '体重(${unit.label})',
      ],
    ];

    for (final meal in state.meals) {
      if (meal.items.isEmpty) {
        rows.add(_mealRow(meal, null));
      } else {
        for (final item in meal.items) {
          rows.add(_mealRow(meal, item));
        }
      }
    }
    for (final weight in state.weights) {
      rows.add([
        '体重',
        weight.id,
        _dateFormat.format(weight.date),
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        unit.toDisplay(weight.kg),
      ]);
    }

    final csv = rows.map((row) => row.map(_csvCell).join(',')).join('\r\n');
    final bytes = Uint8List.fromList(utf8.encode('\ufeff$csv\r\n'));
    final filename = 'meican_${_fileDateFormat.format(DateTime.now())}.csv';
    final file = XFile.fromData(bytes, mimeType: 'text/csv', name: filename);
    await SharePlus.instance.share(
      ShareParams(files: [file], subject: '每餐数据', text: '饮食与体重记录 CSV'),
    );
  }

  static Future<void> exportPdf(AppState state) async {
    final font = await PdfGoogleFonts.notoSansSCRegular();
    final document = pw.Document();
    final unit = state.profile.weightUnit;
    final sortedMeals = [...state.meals]
      ..sort((first, second) => first.date.compareTo(second.date));
    final sortedWeights = [...state.weights]
      ..sort((first, second) => first.date.compareTo(second.date));

    final recordedDays = sortedMeals
        .map((meal) => DateTime(meal.date.year, meal.date.month, meal.date.day))
        .toSet()
        .length;
    final totalIntake = sortedMeals.fold<double>(
      0,
      (sum, meal) => sum + meal.totalKcal,
    );
    final totalExpenditure = NutritionMath.tdee(state.profile) * recordedDays;
    final totalDeficit = totalExpenditure - totalIntake;

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(base: font),
        build: (context) => [
          pw.Text(
            '每餐 - 饮食与体重报告',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text('导出时间：${_dateFormat.format(DateTime.now())}'),
          pw.SizedBox(height: 16),
          pw.Text('摘要', style: pw.TextStyle(fontSize: 15)),
          pw.SizedBox(height: 6),
          pw.Text('有饮食记录天数：$recordedDays 天'),
          pw.Text('总摄入：${totalIntake.toStringAsFixed(1)} kcal'),
          pw.Text(
            '估算总消耗：${totalExpenditure.toStringAsFixed(1)} kcal'
            '（按当前 TDEE × 记录天数）',
          ),
          pw.Text('累计热量缺口：${totalDeficit.toStringAsFixed(1)} kcal'),
          pw.Text(
            '基础代谢 BMR：${NutritionMath.bmr(state.profile).toStringAsFixed(1)} kcal/天；'
            '日常消耗 TDEE：${NutritionMath.tdee(state.profile).toStringAsFixed(1)} kcal/天',
          ),
          pw.Text(
            '热量消耗、缺口与减重仅为估算；减重预测按 7700 kcal/kg 脂肪换算。',
            style: const pw.TextStyle(fontSize: 9),
          ),
          pw.SizedBox(height: 18),
          pw.Text('饮食明细', style: pw.TextStyle(fontSize: 15)),
          pw.SizedBox(height: 6),
          if (sortedMeals.isEmpty)
            pw.Text('暂无饮食记录')
          else
            pw.TableHelper.fromTextArray(
              headers: ['日期', '餐次', '食物', '克数', '热量(kcal)', '备注', '来源'],
              data: [for (final meal in sortedMeals) ..._pdfMealRows(meal)],
              headerStyle: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
              ),
              cellStyle: const pw.TextStyle(fontSize: 8),
              cellAlignment: pw.Alignment.centerLeft,
              cellPadding: const pw.EdgeInsets.all(4),
              columnWidths: {
                0: const pw.FixedColumnWidth(68),
                1: const pw.FixedColumnWidth(38),
                2: const pw.FlexColumnWidth(1.2),
                3: const pw.FixedColumnWidth(38),
                4: const pw.FixedColumnWidth(52),
                5: const pw.FlexColumnWidth(1.5),
                6: const pw.FixedColumnWidth(40),
              },
            ),
          pw.SizedBox(height: 18),
          pw.Text('体重明细', style: pw.TextStyle(fontSize: 15)),
          pw.SizedBox(height: 6),
          if (sortedWeights.isEmpty)
            pw.Text('暂无体重记录')
          else
            pw.TableHelper.fromTextArray(
              headers: ['日期', '体重(${unit.label})'],
              data: [
                for (final weight in sortedWeights)
                  [
                    _dateFormat.format(weight.date),
                    unit.formatValue(weight.kg),
                  ],
              ],
              headerStyle: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
              ),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellAlignment: pw.Alignment.centerLeft,
              cellPadding: const pw.EdgeInsets.all(4),
            ),
        ],
      ),
    );

    final bytes = await document.save();
    final filename = 'meican_${_fileDateFormat.format(DateTime.now())}.pdf';
    if (kIsWeb) {
      final shared = await Printing.sharePdf(bytes: bytes, filename: filename);
      if (!shared) {
        throw Exception('PDF 分享未完成，请重试。');
      }
      return;
    }

    final file = XFile.fromData(
      bytes,
      mimeType: 'application/pdf',
      name: filename,
    );
    await SharePlus.instance.share(
      ShareParams(files: [file], subject: '每餐报告', text: '饮食与体重报告 PDF'),
    );
  }

  static List<Object> _mealRow(MealEntry meal, MealItem? item) {
    return [
      '饮食',
      meal.id,
      _dateFormat.format(meal.date),
      meal.mealType,
      item?.name ?? '',
      item?.id ?? '',
      item?.grams ?? '',
      item?.kcal ?? '',
      meal.note,
      meal.source,
      '',
    ];
  }

  static List<List<String>> _pdfMealRows(MealEntry meal) {
    if (meal.items.isEmpty) {
      return [
        [
          _dateFormat.format(meal.date),
          meal.mealType,
          '（无食物明细）',
          '',
          meal.totalKcal.toStringAsFixed(1),
          meal.note,
          meal.source,
        ],
      ];
    }
    return [
      for (final item in meal.items)
        [
          _dateFormat.format(meal.date),
          meal.mealType,
          item.name,
          item.grams.toStringAsFixed(1),
          item.kcal.toStringAsFixed(1),
          meal.note,
          meal.source,
        ],
    ];
  }

  static String _csvCell(Object value) {
    var text = value.toString();
    if (RegExp(r'^\s*[=+\-@]').hasMatch(text) ||
        text.startsWith('\t') ||
        text.startsWith('\r')) {
      text = "'$text";
    }
    return '"${text.replaceAll('"', '""')}"';
  }
}
