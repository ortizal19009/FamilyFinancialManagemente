import 'package:flutter/foundation.dart';

import 'offline/sync_service.dart';

class AppServices {
  AppServices._();

  static final SyncService syncService = SyncService();
  static final ValueNotifier<int> dataRefreshNotifier = ValueNotifier<int>(0);

  static void requestDataRefresh() {
    dataRefreshNotifier.value++;
  }
}
