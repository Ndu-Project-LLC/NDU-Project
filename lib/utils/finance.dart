/// Finance utility functions for core metrics.
/// Note: In this app, detailed time-series cashflows are not always available.
/// These helpers provide generic calculations and safe fallbacks.
library;

import 'dart:math' as math;

class Finance {
  /// Net Present Value given a discount rate and a list of cashflows where
  /// index 0 is today (usually a negative outflow).
  static double npv(double rate, List<double> cashflows) {
    if (!rate.isFinite || cashflows.isEmpty) return 0;
    double total = 0;
    for (int t = 0; t < cashflows.length; t++) {
      final cf = cashflows[t];
      total += cf / math.pow(1 + rate, t);
    }
    return total;
  }

  /// Internal Rate of Return using Newton-Raphson.
  /// Provide an initial guess; defaults to 10%.
  /// Returns NaN if no convergence.
  static double irr(List<double> cashflows, {double guess = 0.1, int maxIter = 100, double tol = 1e-7}) {
    if (cashflows.isEmpty) return double.nan;

    double rate = guess;
    for (int i = 0; i < maxIter; i++) {
      final f = _npvWithRate(rate, cashflows);
      final df = _dNpvDr(rate, cashflows);
      if (df.abs() < 1e-12) break;
      final next = rate - f / df;
      if ((next - rate).abs() < tol) {
        return next;
      }
      rate = next;
    }
    return double.nan;
  }

  /// Discounted Cash Flow is the present value of all (usually positive) inflows.
  /// If outflows are included in the list, it simply returns their PV as well.
  static double dcf(double rate, List<double> cashflows) {
    return npv(rate, cashflows);
  }

  static double _npvWithRate(double r, List<double> cfs) {
    double total = 0;
    for (int t = 0; t < cfs.length; t++) {
      total += cfs[t] / math.pow(1 + r, t);
    }
    return total;
  }

  static double _dNpvDr(double r, List<double> cfs) {
    double total = 0;
    for (int t = 1; t < cfs.length; t++) {
      total += -t * cfs[t] / math.pow(1 + r, t + 1);
    }
    return total;
  }
}
