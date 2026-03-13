import 'package:flutter/material.dart';
import '../../../../config/app_theme.dart';
import '../../../../models/gut_feeling_entry.dart';
import '../../../../utils/gut_feeling_rating.dart';

class GutFeelingDetail extends StatefulWidget {
  final GutFeelingEntry gut;
  final bool isEditing;
  final int bloating;
  final int gas;
  final int cramps;
  final int fullness;
  final int? stress;
  final int? happiness;
  final int? energy;
  final int? focus;
  final int? bodyFeel;
  final ValueChanged<int> onBloatingChanged;
  final ValueChanged<int> onGasChanged;
  final ValueChanged<int> onCrampsChanged;
  final ValueChanged<int> onFullnessChanged;
  final ValueChanged<int> onStressChanged;
  final ValueChanged<int> onHappinessChanged;
  final ValueChanged<int> onEnergyChanged;
  final ValueChanged<int> onFocusChanged;
  final ValueChanged<int> onBodyFeelChanged;

  const GutFeelingDetail({
    super.key,
    required this.gut,
    required this.isEditing,
    required this.bloating,
    required this.gas,
    required this.cramps,
    required this.fullness,
    this.stress,
    this.happiness,
    this.energy,
    this.focus,
    this.bodyFeel,
    required this.onBloatingChanged,
    required this.onGasChanged,
    required this.onCrampsChanged,
    required this.onFullnessChanged,
    required this.onStressChanged,
    required this.onHappinessChanged,
    required this.onEnergyChanged,
    required this.onFocusChanged,
    required this.onBodyFeelChanged,
  });

  @override
  State<GutFeelingDetail> createState() => _GutFeelingDetailState();
}

class _GutFeelingDetailState extends State<GutFeelingDetail> {
  int _gutFeelingTab = 0;

  double _calculateEditAvg() {
    final values = <int>[
      widget.bloating,
      widget.gas,
      widget.cramps,
      widget.fullness,
    ];
    if (widget.stress != null) values.add(widget.stress!);
    if (widget.happiness != null) values.add(widget.happiness!);
    if (widget.energy != null) values.add(widget.energy!);
    if (widget.focus != null) values.add(widget.focus!);
    if (widget.bodyFeel != null) values.add(widget.bodyFeel!);
    return values.reduce((a, b) => a + b) / values.length;
  }

  @override
  Widget build(BuildContext context) {
    final rating = calculateGutFeelingRating(widget.gut);
    final displayAvg = widget.isEditing ? _calculateEditAvg() : rating.avg;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Rating pill + numeric score
        Row(
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: rating.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                rating.level.label,
                style: TextStyle(
                  color: rating.color,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${displayAvg.toStringAsFixed(1)} / 5.0',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.mutedForeground,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Tab selector
        Row(
          children: [
            _tabButton('Bauchgefühl', 0),
            const SizedBox(width: 8),
            _tabButton('Stimmung', 1),
          ],
        ),
        const SizedBox(height: 16),
        if (_gutFeelingTab == 0)
          _buildBauchgefuehlTab()
        else
          _buildStimmungTab(),
      ],
    );
  }

  Widget _tabButton(String label, int index) {
    final isActive = _gutFeelingTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _gutFeelingTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? AppTheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive ? AppTheme.primary : AppTheme.muted,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isActive ? Colors.white : AppTheme.mutedForeground,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBauchgefuehlTab() {
    if (widget.isEditing) {
      return Column(
        children: [
          _editSlider('Blähbauch', widget.bloating, widget.onBloatingChanged),
          _editSlider('Blähungen', widget.gas, widget.onGasChanged),
          _editSlider('Krämpfe', widget.cramps, widget.onCrampsChanged),
          _editSlider(
              'Völlegefühl', widget.fullness, widget.onFullnessChanged),
        ],
      );
    }
    return Column(
      children: [
        _detailRow('Blähbauch', widget.gut.bloating),
        _detailRow('Blähungen', widget.gut.gas),
        _detailRow('Krämpfe', widget.gut.cramps),
        _detailRow('Völlegefühl', widget.gut.fullness),
      ],
    );
  }

  Widget _buildStimmungTab() {
    if (widget.isEditing) {
      return Column(
        children: [
          _editSlider(
              'Stress', widget.stress ?? 3, widget.onStressChanged),
          _editSlider(
              'Glück', widget.happiness ?? 3, widget.onHappinessChanged),
          _editSlider(
              'Energie', widget.energy ?? 3, widget.onEnergyChanged),
          _editSlider(
              'Fokus', widget.focus ?? 3, widget.onFocusChanged),
          _editSlider(
              'Körpergefühl', widget.bodyFeel ?? 3, widget.onBodyFeelChanged),
        ],
      );
    }
    final hasAny = widget.gut.stress != null ||
        widget.gut.happiness != null ||
        widget.gut.energy != null ||
        widget.gut.focus != null ||
        widget.gut.bodyFeel != null;
    if (!hasAny) {
      return const Text(
        'Keine Stimmungsdaten erfasst',
        style: TextStyle(color: AppTheme.mutedForeground),
      );
    }
    return Column(
      children: [
        if (widget.gut.stress != null)
          _detailRow('Stress', widget.gut.stress!),
        if (widget.gut.happiness != null)
          _detailRow('Glück', widget.gut.happiness!),
        if (widget.gut.energy != null)
          _detailRow('Energie', widget.gut.energy!),
        if (widget.gut.focus != null)
          _detailRow('Fokus', widget.gut.focus!),
        if (widget.gut.bodyFeel != null)
          _detailRow('Körpergefühl', widget.gut.bodyFeel!),
      ],
    );
  }

  Widget _editSlider(String label, int value, ValueChanged<int> onChanged) {
    final color = getValueColor(value);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 15)),
              Text(
                '$value / 5',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: color,
              thumbColor: color,
              inactiveTrackColor: color.withValues(alpha: 0.2),
            ),
            child: Slider(
              value: value.toDouble(),
              min: 1,
              max: 5,
              divisions: 4,
              onChanged: (v) => onChanged(v.round()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, int value) {
    final color = getValueColor(value);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 15)),
          Text(
            '$value / 5',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
