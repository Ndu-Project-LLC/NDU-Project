import 'package:flutter/material.dart';
import 'package:ndu_project/models/control_account_model.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/services/control_account_service.dart';

class ControlAccountProvider extends ChangeNotifier {
  List<ControlAccount> _accounts = [];
  bool _isRecalculating = false;

  List<ControlAccount> get accounts => _accounts;
  bool get isRecalculating => _isRecalculating;

  /// Load accounts from a ProjectDataModel.
  void loadFromProjectData(ProjectDataModel projectData) {
    _accounts = List<ControlAccount>.from(projectData.controlAccounts);
    notifyListeners();
  }

  /// Recalculate all accounts after scope/cost/schedule changes.
  Future<void> recalculateAll(ProjectDataModel projectData) async {
    _isRecalculating = true;
    notifyListeners();

    _accounts = ControlAccountService.recalculateAll(
      accounts: _accounts,
      workPackages: projectData.workPackages,
      activities: projectData.scheduleActivities,
      costItems: projectData.costEstimateItems,
    );

    _isRecalculating = false;
    notifyListeners();
  }

  /// CRUD operations
  void addAccount(ControlAccount account) {
    _accounts.add(account);
    notifyListeners();
  }

  void updateAccount(ControlAccount account) {
    final index = _accounts.indexWhere((a) => a.id == account.id);
    if (index != -1) {
      _accounts[index] = account;
      notifyListeners();
    }
  }

  void removeAccount(String id) {
    _accounts.removeWhere((a) => a.id == id);
    notifyListeners();
  }

  ControlAccount? getAccount(String id) {
    try {
      return _accounts.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  List<ControlAccount> getAccountsByWbs(String wbsId) {
    return _accounts.where((a) => a.wbsId == wbsId).toList();
  }

  List<ControlAccount> getAccountsByObs(String obsId) {
    return _accounts.where((a) => a.obsId == obsId).toList();
  }

  double get totalBudgetAtCompletion =>
      _accounts.fold<double>(0, (s, a) => s + a.budgetAtCompletion);

  double get totalEarnedValue =>
      _accounts.fold<double>(0, (s, a) => s + a.earnedValue);

  double get totalActualCost =>
      _accounts.fold<double>(0, (s, a) => s + a.actualCost);

  double get overallCpi {
    final ac = totalActualCost;
    return ac > 0 ? totalEarnedValue / ac : 1.0;
  }

  double get overallSpi {
    final pv = _accounts.fold<double>(0, (s, a) {
      final now = DateTime.now();
      final currentKey =
          '${now.year}-${now.month.toString().padLeft(2, '0')}';
      double total = 0;
      for (final entry in a.plannedValueByPeriod.entries) {
        if (entry.key.compareTo(currentKey) <= 0) {
          total += entry.value;
        }
      }
      return s + total;
    });
    return pv > 0 ? totalEarnedValue / pv : 1.0;
  }

  void reset() {
    _accounts = [];
    _isRecalculating = false;
    notifyListeners();
  }
}
