import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class OfflineBanner extends StatefulWidget {
  final Widget child;
  const OfflineBanner({super.key, required this.child});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner>
    with SingleTickerProviderStateMixin {
  bool _isOffline = false;
  late StreamSubscription<List<ConnectivityResult>> _sub;
  late AnimationController _animCtrl;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));

    _sub = Connectivity().onConnectivityChanged.listen(_onConnectivityChanged);
    // Verifica estado inicial
    Connectivity().checkConnectivity().then((results) {
      _onConnectivityChanged(results);
    });
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final offline = results.every((r) => r == ConnectivityResult.none);
    if (offline == _isOffline) return;
    setState(() => _isOffline = offline);
    if (offline) {
      _animCtrl.forward();
    } else {
      _animCtrl.reverse();
    }
  }

  @override
  void dispose() {
    _sub.cancel();
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SlideTransition(
            position: _slideAnim,
            child: SafeArea(
              bottom: false,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: const BoxDecoration(
                    color: Color(0xFFEF4444),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.wifi_off_rounded,
                          color: Colors.white, size: 18),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Sem conexão — verifique sua internet',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
