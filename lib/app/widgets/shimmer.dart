import 'package:flutter/material.dart';

class ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerBox({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.borderRadius = 8,
  });

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _anim = Tween<double>(begin: -1, end: 2).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            stops: [
              (_anim.value - 0.5).clamp(0.0, 1.0),
              _anim.value.clamp(0.0, 1.0),
              (_anim.value + 0.5).clamp(0.0, 1.0),
            ],
            colors: const [
              Color(0xFFE5E7EB),
              Color(0xFFF3F4F6),
              Color(0xFFE5E7EB),
            ],
          ),
        ),
      ),
    );
  }
}

// Card skeleton para lista de vets
class VetCardSkeleton extends StatelessWidget {
  const VetCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          const ShimmerBox(width: 52, height: 52, borderRadius: 26),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ShimmerBox(height: 14, borderRadius: 6),
                const SizedBox(height: 8),
                ShimmerBox(width: MediaQuery.of(context).size.width * 0.35, height: 12, borderRadius: 6),
                const SizedBox(height: 8),
                ShimmerBox(width: MediaQuery.of(context).size.width * 0.25, height: 12, borderRadius: 6),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: const [
              ShimmerBox(width: 60, height: 16, borderRadius: 6),
              SizedBox(height: 6),
              ShimmerBox(width: 40, height: 12, borderRadius: 6),
            ],
          ),
        ],
      ),
    );
  }
}

// Card skeleton para consultas
class ConsultationCardSkeleton extends StatelessWidget {
  const ConsultationCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const ShimmerBox(width: 44, height: 44, borderRadius: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ShimmerBox(height: 14, borderRadius: 6),
                    const SizedBox(height: 6),
                    ShimmerBox(
                        width: MediaQuery.of(context).size.width * 0.4,
                        height: 12,
                        borderRadius: 6),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const ShimmerBox(width: 70, height: 24, borderRadius: 12),
            ],
          ),
          const SizedBox(height: 12),
          const ShimmerBox(height: 1),
          const SizedBox(height: 12),
          Row(
            children: const [
              ShimmerBox(width: 80, height: 12, borderRadius: 6),
              SizedBox(width: 16),
              ShimmerBox(width: 60, height: 12, borderRadius: 6),
            ],
          ),
        ],
      ),
    );
  }
}
