import 'dart:math';

/// Represents a risk factor from the risk register that can be quantified
/// for risk-adjusted forecasting.
class RiskFactor {
  final String id;
  final String title;
  final double probability; // 0-1
  final double costImpact;  // dollar impact if risk materializes
  final int scheduleImpactDays; // schedule impact if risk materializes
  final String category; // 'schedule' | 'cost' | 'scope' | 'quality'

  const RiskFactor({
    required this.id,
    required this.title,
    this.probability = 0.5,
    this.costImpact = 0,
    this.scheduleImpactDays = 0,
    this.category = 'cost',
  });

  /// Expected Monetary Value (EMV) = probability × costImpact
  double get emv => probability * costImpact;
}

class ForecastResult {
  final double eac;
  final double etc;
  final double vac;
  final double tcpii;
  final double tcpis;
  final String methodology;
  final DateTime forecastDate;
  final double confidenceLevel;

  // ── P2.4: Enhanced forecast result fields ──
  /// EAC lower bound (optimistic scenario).
  final double eacLow;
  /// EAC upper bound (pessimistic scenario).
  final double eacHigh;
  /// Composite EAC using CPI×SPI formula for schedule-critical projects.
  final double eacComposite;
  /// Risk-adjusted EAC incorporating risk register quantification.
  final double eacRiskAdjusted;
  /// Total Expected Monetary Value from risk factors.
  final double totalRiskEmv;
  /// Independent Estimate at Completion (IEAC) — statistical regression.
  final double ieac;

  ForecastResult({
    required this.eac,
    required this.etc,
    required this.vac,
    required this.tcpii,
    required this.tcpis,
    required this.methodology,
    required this.forecastDate,
    required this.confidenceLevel,
    this.eacLow = 0,
    this.eacHigh = 0,
    this.eacComposite = 0,
    this.eacRiskAdjusted = 0,
    this.totalRiskEmv = 0,
    this.ieac = 0,
  });
}

class ForecastService {
  /// Calculate EAC (Estimate at Completion) and related metrics using standard EVM formulas.
  ///
  /// [methodology] can be:
  ///   - 'formula' (default): EAC = BAC / CPI
  ///   - 'manual': user-supplied EAC override
  ///   - 'riskBased': incorporates risk register quantification (P2.4 — now fully implemented)
  ///   - 'composite': EAC = AC + [(BAC - EV) / (CPI × SPI)] for schedule-critical projects
  static ForecastResult calculateEac({
    required double bac,
    required double ev,
    required double ac,
    required double pv,
    String methodology = 'formula',
    double? manualEac,
    List<RiskFactor>? riskFactors,
  }) {
    final cpi = ac > 0 ? ev / ac : 1.0;
    final spi = pv > 0 ? ev / pv : 1.0;

    // Standard CPI-based EAC
    final eacCpi = cpi > 0 ? bac / cpi : bac;

    // Composite EAC (CPI × SPI) for schedule-critical projects
    final compositeDenom = cpi * spi;
    final eacComposite = compositeDenom > 0
        ? ac + ((bac - ev) / compositeDenom)
        : bac;

    // ── P2.4: Risk-based EAC calculation ──
    double totalRiskEmv = 0;
    if (riskFactors != null && riskFactors.isNotEmpty) {
      for (final risk in riskFactors) {
        totalRiskEmv += risk.emv;
      }
    }
    // Risk-adjusted EAC = CPI-based EAC + total risk EMV
    final eacRiskAdjusted = eacCpi + totalRiskEmv;

    // Confidence range: ±15% for formula, ±25% for risk-based
    final rangeFactor = methodology == 'riskBased' ? 0.25 : 0.15;
    final eacLow = eacCpi * (1 - rangeFactor);
    final eacHigh = eacRiskAdjusted * (1 + rangeFactor);

    // IEAC (Independent Estimate at Completion) — simple statistical:
    // Average of CPI-based and composite EAC
    final ieac = (eacCpi + eacComposite) / 2;

    // Enhanced confidence: considers CPI/SPI deviation AND risk exposure
    final baseConfidence = _computeConfidence(cpi, spi);
    final riskPenalty = totalRiskEmv > 0
        ? (totalRiskEmv / bac).clamp(0, 0.3) // Max 30% confidence penalty from risk
        : 0;
    final confidence = (baseConfidence - riskPenalty).clamp(0, 1).toDouble();

    if (methodology == 'manual' && manualEac != null) {
      final eac = manualEac;
      return ForecastResult(
        eac: eac,
        etc: eac - ac,
        vac: bac - eac,
        tcpii: _computeTcpii(bac, ev, ac),
        tcpis: _computeTcpis(bac, ev, eac, ac),
        methodology: 'manual',
        forecastDate: DateTime.now(),
        confidenceLevel: 0.5,
        eacLow: eac * 0.9,
        eacHigh: eac * 1.1,
        eacComposite: eacComposite,
        eacRiskAdjusted: eacRiskAdjusted,
        totalRiskEmv: totalRiskEmv,
        ieac: ieac,
      );
    }

    if (methodology == 'riskBased') {
      // ── P2.4: Risk-based forecasting now fully implemented ──
      final eac = eacRiskAdjusted;
      return ForecastResult(
        eac: eac,
        etc: eac - ac,
        vac: bac - eac,
        tcpii: _computeTcpii(bac, ev, ac),
        tcpis: _computeTcpis(bac, ev, eac, ac),
        methodology: 'riskBased',
        forecastDate: DateTime.now(),
        confidenceLevel: confidence,
        eacLow: eacLow,
        eacHigh: eacHigh,
        eacComposite: eacComposite,
        eacRiskAdjusted: eacRiskAdjusted,
        totalRiskEmv: totalRiskEmv,
        ieac: ieac,
      );
    }

    if (methodology == 'composite') {
      return ForecastResult(
        eac: eacComposite,
        etc: eacComposite - ac,
        vac: bac - eacComposite,
        tcpii: _computeTcpii(bac, ev, ac),
        tcpis: _computeTcpis(bac, ev, eacComposite, ac),
        methodology: 'composite',
        forecastDate: DateTime.now(),
        confidenceLevel: confidence,
        eacLow: eacLow,
        eacHigh: eacHigh,
        eacComposite: eacComposite,
        eacRiskAdjusted: eacRiskAdjusted,
        totalRiskEmv: totalRiskEmv,
        ieac: ieac,
      );
    }

    // Default: CPI-based formula
    final eac = eacCpi;
    return ForecastResult(
      eac: eac,
      etc: eac - ac,
      vac: bac - eac,
      tcpii: _computeTcpii(bac, ev, ac),
      tcpis: _computeTcpis(bac, ev, eac, ac),
      methodology: methodology,
      forecastDate: DateTime.now(),
      confidenceLevel: confidence,
      eacLow: eacLow,
      eacHigh: eacHigh,
      eacComposite: eacComposite,
      eacRiskAdjusted: eacRiskAdjusted,
      totalRiskEmv: totalRiskEmv,
      ieac: ieac,
    );
  }

  static double _computeTcpii(double bac, double ev, double ac) {
    return (bac - ac) > 0 ? (bac - ev) / (bac - ac) : 1.0;
  }

  static double _computeTcpis(double bac, double ev, double eac, double ac) {
    return (eac - ac) > 0 ? (bac - ev) / (eac - ac) : 1.0;
  }

  /// Enhanced confidence heuristic: considers CPI/SPI deviation.
  /// Closer to 1.0 = higher confidence.
  static double _computeConfidence(double cpi, double spi) {
    final cpiConf = 1.0 - (cpi - 1.0).abs();
    final spiConf = 1.0 - (spi - 1.0).abs();
    return ((cpiConf + spiConf) / 2).clamp(0, 1);
  }

  // ── P3.6: Monte Carlo simulation for risk-adjusted forecasting ──

  /// Run a Monte Carlo simulation for Estimate at Completion.
  ///
  /// Uses PERT distributions from [riskFactors] to generate [iterations]
  /// random samples. Each iteration adds a random risk cost to the
  /// CPI-based EAC, producing a probability distribution of outcomes.
  ///
  /// Returns a [MonteCarloResult] with percentiles, histogram data,
  /// and the probability of exceeding the budget.
  static MonteCarloResult runMonteCarlo({
    required double bac,
    required double ev,
    required double ac,
    required double pv,
    required List<RiskFactor> riskFactors,
    int iterations = 1000,
    int seed = 42,
  }) {
    final cpi = ac > 0 ? ev / ac : 1.0;
    final baseEac = cpi > 0 ? bac / cpi : bac;

    // Simple pseudo-random number generator (LCG) for reproducibility
    int rngState = seed;
    double random() {
      rngState = (rngState * 1103515245 + 12345) & 0x7FFFFFFF;
      return rngState / 0x7FFFFFFF;
    }

    // PERT random variate using beta approximation
    double pertRandom(double min, double mostLikely, double max) {
      final u = random();
      // Simplified PERT sampling: use triangular distribution as approximation
      final fc = mostLikely > min
          ? (mostLikely - min) / (max - min)
          : 0.5;
      if (u < fc) {
        return min + (max - min) * sqrt(u * fc);
      } else {
        return max - (max - min) * sqrt((1 - u) * (1 - fc));
      }
    }

    final results = <double>[];
    for (int i = 0; i < iterations; i++) {
      double riskCost = 0;
      for (final risk in riskFactors) {
        // Each risk either occurs (with its probability) or doesn't
        if (random() <= risk.probability) {
          // Use PERT distribution for cost impact
          riskCost += pertRandom(
            risk.costImpact * 0.5,
            risk.costImpact,
            risk.costImpact * 1.5,
          );
        }
      }
      results.add(baseEac + riskCost);
    }

    results.sort();

    // Compute percentiles
    double percentile(int p) {
      final index = ((p / 100) * (results.length - 1)).round();
      return results[index.clamp(0, results.length - 1)];
    }

    // Build histogram (10 bins)
    final minVal = results.first;
    final maxVal = results.last;
    final binWidth = (maxVal - minVal) / 10;
    final histogram = <double, int>{};
    if (binWidth > 0) {
      for (final val in results) {
        final bin = ((val - minVal) / binWidth).floor().clamp(0, 9);
        final binStart = minVal + bin * binWidth;
        histogram[binStart] = (histogram[binStart] ?? 0) + 1;
      }
    }

    // Probability of exceeding BAC
    final exceedBacProb =
        results.where((v) => v > bac).length / results.length;

    return MonteCarloResult(
      p10: percentile(10),
      p25: percentile(25),
      p50: percentile(50),
      p75: percentile(75),
      p80: percentile(80),
      p90: percentile(90),
      mean: results.reduce((a, b) => a + b) / results.length,
      stdDev: _computeStdDev(results),
      exceedBacProbability: exceedBacProb,
      iterations: iterations,
      histogram: histogram,
    );
  }

  static double _computeStdDev(List<double> values) {
    if (values.isEmpty) return 0;
    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance =
        values.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) /
            values.length;
    return sqrt(variance);
  }
}

/// ── P3.6: Monte Carlo simulation result ──
class MonteCarloResult {
  /// 10th percentile EAC (optimistic).
  final double p10;
  /// 25th percentile EAC.
  final double p25;
  /// 50th percentile EAC (median).
  final double p50;
  /// 75th percentile EAC.
  final double p75;
  /// 80th percentile EAC (commonly used for management reserve).
  final double p80;
  /// 90th percentile EAC (pessimistic).
  final double p90;
  /// Mean (expected) EAC across all iterations.
  final double mean;
  /// Standard deviation of EAC distribution.
  final double stdDev;
  /// Probability that EAC will exceed BAC.
  final double exceedBacProbability;
  /// Number of simulation iterations.
  final int iterations;
  /// Histogram of EAC values (bin start → count).
  final Map<double, int> histogram;

  const MonteCarloResult({
    required this.p10,
    required this.p25,
    required this.p50,
    required this.p75,
    required this.p80,
    required this.p90,
    required this.mean,
    required this.stdDev,
    required this.exceedBacProbability,
    required this.iterations,
    required this.histogram,
  });
}
