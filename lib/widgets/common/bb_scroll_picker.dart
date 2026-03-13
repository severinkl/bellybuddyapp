import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../services/haptic_service.dart';

class BbScrollPicker extends StatefulWidget {
  final List<int> items;
  final int? selectedValue;
  final ValueChanged<int> onChanged;
  final String Function(int)? labelBuilder;
  final double itemHeight;
  final int visibleItems;

  const BbScrollPicker({
    super.key,
    required this.items,
    this.selectedValue,
    required this.onChanged,
    this.labelBuilder,
    this.itemHeight = 44,
    this.visibleItems = 5,
  });

  @override
  State<BbScrollPicker> createState() => _BbScrollPickerState();
}

class _BbScrollPickerState extends State<BbScrollPicker> {
  late final FixedExtentScrollController _controller;

  @override
  void initState() {
    super.initState();
    final initialIndex = widget.selectedValue != null
        ? widget.items.indexOf(widget.selectedValue!)
        : widget.items.length ~/ 2;
    _controller = FixedExtentScrollController(
      initialItem: initialIndex >= 0 ? initialIndex : 0,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = widget.itemHeight * widget.visibleItems;
    return SizedBox(
      height: height,
      child: ShaderMask(
        shaderCallback: (bounds) {
          return LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black,
              Colors.black,
              Colors.transparent,
            ],
            stops: const [0.0, 0.25, 0.75, 1.0],
          ).createShader(bounds);
        },
        blendMode: BlendMode.dstIn,
        child: ListWheelScrollView.useDelegate(
          controller: _controller,
          itemExtent: widget.itemHeight,
          perspective: 0.005,
          diameterRatio: 1.5,
          magnification: 1.2,
          useMagnifier: true,
          physics: const FixedExtentScrollPhysics(),
          onSelectedItemChanged: (index) {
            HapticService.selection();
            widget.onChanged(widget.items[index]);
          },
          childDelegate: ListWheelChildBuilderDelegate(
            childCount: widget.items.length,
            builder: (context, index) {
              final item = widget.items[index];
              final isSelected = item == widget.selectedValue;
              final label = widget.labelBuilder?.call(item) ?? item.toString();
              return Center(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: isSelected ? 20 : 16,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected
                        ? AppTheme.foreground
                        : AppTheme.mutedForeground,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
