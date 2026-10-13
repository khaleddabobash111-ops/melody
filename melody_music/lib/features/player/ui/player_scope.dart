import 'dart:async';
import 'package:flutter/material.dart';
import 'artwork_palette.dart';
import 'player_backend.dart';

class PlayerScopeData {
  const PlayerScopeData(this.backend, this.palette);
  final PlayerBackend backend;
  final PaletteController palette;
}

/// ضعه فوق الـ Navigator:
/// MaterialApp(builder: (c, child) => PlayerScope(backend: backend, child: child!))
class PlayerScope extends StatefulWidget {
  const PlayerScope({super.key, required this.backend, required this.child});
  final PlayerBackend backend;
  final Widget child;

  static PlayerScopeData of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_Inherited>()!.data;

  @override
  State<PlayerScope> createState() => _PlayerScopeState();
}

class _PlayerScopeState extends State<PlayerScope> {
  final _palette = PaletteController();
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _palette.update(widget.backend.currentTrack);
    _sub = widget.backend.trackStream.listen(_palette.update);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _palette.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _Inherited(data: PlayerScopeData(widget.backend, _palette), child: widget.child);
}

class _Inherited extends InheritedWidget {
  const _Inherited({required this.data, required super.child});
  final PlayerScopeData data;
  @override
  bool updateShouldNotify(_Inherited old) => old.data.backend != data.backend;
}
