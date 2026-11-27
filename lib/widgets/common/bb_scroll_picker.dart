import 'package:material_ui/material_ui.dart';
import '../../config/app_theme.dart';
import '../../services/haptic_service.dart';
import '../../config/constants.dart';
import '../../utils/reduced_motion.dart';

class BbScrollPicker extends StatefulWidget {
  final List<int> items;
  final int? selectedValue;
  final ValueChanged<int> onChanged;
  final String Function(int)? labelBuilder;
  final double itemHeight;
  final int visibleItems;

  /// When true, the picker fills its parent height instead of using a fixed height.
  final bool expand;

  /// What the picker sets, e.g. 'Geburtsjahr'. Screen readers read it with
  /// the current item as the value and step through the items with
  /// increase/decrease (swipe up/down), since the wheel can't be scrolled
  /// with one.
  final String semanticLabel;

  const BbScrollPicker({
    super.key,
    required this.items,
    this.selectedValue,
    required this.onChanged,
    this.labelBuilder,
    this.itemHeight = 44,
    this.visibleItems = 5,
    this.expand = false,
    required this.semanticLabel,
  });

  @override
  State<BbScrollPicker> createState() => _BbScrollPickerState();
}

class _BbScrollPickerState extends State<BbScrollPicker> {
  late final FixedExtentScrollController _controller;

  /// The item the wheel stands on.
  late int _index;

  /// Counts the steps; while the latest one's animation runs, the items the
  /// wheel passes on its way are not selections.
  int _steps = 0;
  bool _stepping = false;

  @override
  void initState() {
    super.initState();
    final initialIndex = widget.selectedValue != null
        ? widget.items.indexOf(widget.selectedValue!)
        : widget.items.length ~/ 2;
    _index = initialIndex >= 0 ? initialIndex : 0;
    _controller = FixedExtentScrollController(initialItem: _index);
  }

  String _label(int index) {
    final item = widget.items[index];
    return widget.labelBuilder?.call(item) ?? item.toString();
  }

  /// The wheel's middle item became [index] while scrolling (ignored while
  /// a step's animation carries it there).
  void _onWheelChanged(int index) {
    if (_stepping || index == _index) return;
    setState(() => _index = index);
    HapticService.selection();
    widget.onChanged(widget.items[index]);
  }

  /// A screen reader's increase/decrease: selects the item [delta] away and
  /// moves the wheel there (at once under reduced motion).
  void _step(int delta) {
    final index = _index + delta;
    if (index < 0 || index >= widget.items.length) return;
    setState(() => _index = index);
    widget.onChanged(widget.items[index]);
    final duration = ReducedMotion.duration(context, AppConstants.animNormal);
    if (duration == Duration.zero) {
      _controller.jumpToItem(index);
    } else {
      final step = ++_steps;
      _stepping = true;
      _controller
          .animateToItem(index, duration: duration, curve: Curves.easeOut)
          .whenComplete(() {
            if (step == _steps) _stepping = false;
          });
    }
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
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
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
            onSelectedItemChanged: _onWheelChanged,
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
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
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
    final canIncrease = _index < widget.items.length - 1;
    final canDecrease = _index > 0;
    final picker = Semantics(
      container: true,
      label: widget.semanticLabel,
      value: _label(_index),
      increasedValue: canIncrease ? _label(_index + 1) : null,
      decreasedValue: canDecrease ? _label(_index - 1) : null,
      onIncrease: canIncrease ? () => _step(1) : null,
      onDecrease: canDecrease ? () => _step(-1) : null,
      child: ExcludeSemantics(child: _buildContent()),
    );
    if (widget.expand) return picker;
    return SizedBox(
      height: widget.itemHeight * widget.visibleItems,
      child: picker,
    );
  }
}
