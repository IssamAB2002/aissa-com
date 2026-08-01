import 'package:intl/intl.dart';

import '../../income/models/transaction.dart';

class PeriodSummary {
  const PeriodSummary({
    required this.label,
    required this.start,
    required this.end,
    required this.revenue,
    required this.expenses,
  });

  final String label;
  final DateTime start;
  final DateTime end;
  final double revenue;
  final double expenses;

  double get netProfit => revenue - expenses;
}

class AnalyticsData {
  AnalyticsData(this._transactions);

  final List<AppTransaction> _transactions;

  List<PeriodSummary> monthlyLast12() {
    final now = DateTime.now();
    return List.generate(12, (i) {
      final rawMonth = now.month - i;
      final year = rawMonth <= 0 ? now.year - 1 : now.year;
      final month = rawMonth <= 0 ? rawMonth + 12 : rawMonth;
      final start = DateTime(year, month, 1);
      final end =
          month == 12 ? DateTime(year + 1, 1, 1) : DateTime(year, month + 1, 1);
      return _summary(DateFormat('MMMM yyyy').format(start), start, end);
    });
  }

  List<PeriodSummary> weeklyLast12() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final thisWeekStart = today.subtract(Duration(days: today.weekday - 1));
    return List.generate(12, (i) {
      final ws = thisWeekStart.subtract(Duration(days: i * 7));
      final we = ws.add(const Duration(days: 7));
      final label =
          '${DateFormat('MMM d').format(ws)} – ${DateFormat('MMM d').format(we.subtract(const Duration(days: 1)))}';
      return _summary(label, ws, we);
    });
  }

  List<PeriodSummary> dailyLast30() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return List.generate(30, (i) {
      final day = today.subtract(Duration(days: i));
      final label = i == 0
          ? 'Today'
          : i == 1
              ? 'Yesterday'
              : DateFormat('EEE, MMM d').format(day);
      return _summary(label, day, day.add(const Duration(days: 1)));
    });
  }

  List<PeriodSummary> monthlyInRange(DateTime start, DateTime end) {
    final result = <PeriodSummary>[];
    var year = start.year;
    var month = start.month;
    while (year < end.year || (year == end.year && month <= end.month)) {
      final s = DateTime(year, month, 1);
      final e =
          month == 12 ? DateTime(year + 1, 1, 1) : DateTime(year, month + 1, 1);
      result.add(_summary(DateFormat('MMMM yyyy').format(s), s, e));
      if (month == 12) {
        year++;
        month = 1;
      } else {
        month++;
      }
    }
    return result.reversed.toList();
  }

  List<PeriodSummary> weeklyInRange(DateTime start, DateTime end) {
    final result = <PeriodSummary>[];
    final startDay = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(end.year, end.month, end.day);
    var ws = startDay.subtract(Duration(days: startDay.weekday - 1));
    while (!ws.isAfter(endDay)) {
      final we = ws.add(const Duration(days: 7));
      final label =
          '${DateFormat('MMM d').format(ws)} – ${DateFormat('MMM d').format(we.subtract(const Duration(days: 1)))}';
      result.add(_summary(label, ws, we));
      ws = we;
    }
    return result.reversed.toList();
  }

  List<PeriodSummary> dailyInRange(DateTime start, DateTime end) {
    final result = <PeriodSummary>[];
    var day = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(end.year, end.month, end.day);
    while (!day.isAfter(endDay)) {
      result.add(_summary(
        DateFormat('EEE, MMM d').format(day),
        day,
        day.add(const Duration(days: 1)),
      ));
      day = day.add(const Duration(days: 1));
    }
    return result.reversed.toList();
  }

  PeriodSummary _summary(String label, DateTime start, DateTime end) {
    final inRange = _transactions.where(
        (t) => !t.date.isBefore(start) && t.date.isBefore(end));
    final revenue = inRange
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (s, t) => s + t.amount);
    final expenses = inRange
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (s, t) => s + t.amount);
    return PeriodSummary(
      label: label,
      start: start,
      end: end,
      revenue: revenue,
      expenses: expenses,
    );
  }
}
