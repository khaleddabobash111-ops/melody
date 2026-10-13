import 'package:flutter_riverpod/flutter_riverpod.dart';

class TabIndex extends Notifier<int> {
  @override
  int build() => 0;
  void set(int i) => state = i;
}

final tabProvider = NotifierProvider<TabIndex, int>(TabIndex.new);
