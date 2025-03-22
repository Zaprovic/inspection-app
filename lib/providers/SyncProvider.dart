import 'package:flutter/foundation.dart';
import 'package:inspection_app/services/DatabaseService.dart';

class SyncProvider extends ChangeNotifier {
  int _pendingSyncs = 0;

  int get pendingSyncs => _pendingSyncs;

  Future<void> loadPendingSyncs() async {
    try {
      final inspectionData = await DatabaseService.instance.getAllInspections();

      final pendingCount =
          inspectionData
              .where((data) => data['status'] == 'Pendiente de sincronización')
              .length;

      // Only notify if the count actually changed
      if (_pendingSyncs != pendingCount) {
        _pendingSyncs = pendingCount;
        notifyListeners();
      }
    } catch (e) {
      print('Error loading pending syncs: $e');
    }
  }

  void incrementPendingSyncs() {
    _pendingSyncs++;
    notifyListeners();
  }

  void decrementPendingSyncs() {
    if (_pendingSyncs > 0) {
      _pendingSyncs--;
      notifyListeners();
    }
  }

  void resetPendingSyncs() {
    _pendingSyncs = 0;
    notifyListeners();
  }

  Future<void> setPendingSyncs(int count) async {
    // Only update and notify if the count actually changes
    if (_pendingSyncs != count) {
      _pendingSyncs = count;
      notifyListeners();
    }
  }
}
