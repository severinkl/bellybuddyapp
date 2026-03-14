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
  /// When true, the picker fills its parent height instead of using a fixed height.
  final bool expand;

  const BbScrollPicker({
    super.key,
    required this.items,
    this.selectedValue,
    required this.onChanged,
    this.labelBuilder,
    this.itemHeight = 44,
    this.visibleItems = 5,
    this.expand = false,
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

  Widget _buildContent() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          height: widget.itemHeight,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppTheme.muted.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        ShaderMask(
          shaderCallback: (bounds) {
            return const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black,
                Colors.black,
                Colors.transparent,
              ],
              stops: [0.0, 0.25, 0.75, 1.0],
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
                final label =
                    widget.labelBuilder?.call(item) ?? item.toString();
                return Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: isSelected ? 20 : 16,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
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
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.expand) {
      return _buildContent();
    }
    return SizedBox(
      height: widget.itemHeight * widget.visibleItems,
      child: _buildContent(),
    );
  }
}
