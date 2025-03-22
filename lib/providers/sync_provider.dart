import 'package:flutter/foundation.dart';
import 'package:inspection_app/services/database_service.dart';

class SyncProvider extends ChangeNotifier {
  int _pendingSyncs = 0;

  int get pendingSyncs => _pendingSyncs;

  Future<void> loadPendingSyncs() async {
    try {
      final inspectionData = await DatabaseService.instance.getAllInspections();

      _pendingSyncs =
          inspectionData
              .where((data) => data['status'] == 'Pendiente de sincronización')
              .length;

      notifyListeners();
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
}
