import 'package:flutter/material.dart';
import '../../../../config/app_theme.dart';
import '../../../../models/gut_feeling_entry.dart';
import '../../../../utils/gut_feeling_rating.dart';
import 'gut_feeling_edit_state.dart';

class GutFeelingDetail extends StatefulWidget {
  final GutFeelingEntry gut;
  final bool isEditing;
  final GutFeelingEditState? editState;

  const GutFeelingDetail({
    super.key,
    required this.gut,
    required this.isEditing,
    this.editState,
  });

  @override
  State<GutFeelingDetail> createState() => _GutFeelingDetailState();
}

class _GutFeelingDetailState extends State<GutFeelingDetail> {
  int _gutFeelingTab = 0;

  double _calculateEditAvg() {
    final es = widget.editState!;
    final values = <int>[
      es.bloating,
      es.gas,
      es.cramps,
      es.fullness,
    ];
    if (es.stress != null) values.add(es.stress!);
    if (es.happiness != null) values.add(es.happiness!);
    if (es.energy != null) values.add(es.energy!);
    if (es.focus != null) values.add(es.focus!);
    if (es.bodyFeel != null) values.add(es.bodyFeel!);
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
      final es = widget.editState!;
      return Column(
        children: [
          _editSlider('Blähbauch', es.bloating, es.onBloatingChanged),
          _editSlider('Blähungen', es.gas, es.onGasChanged),
          _editSlider('Krämpfe', es.cramps, es.onCrampsChanged),
          _editSlider('Völlegefühl', es.fullness, es.onFullnessChanged),
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
      final es = widget.editState!;
      return Column(
        children: [
          _editSlider('Stress', es.stress ?? 3, es.onStressChanged),
          _editSlider('Glück', es.happiness ?? 3, es.onHappinessChanged),
          _editSlider('Energie', es.energy ?? 3, es.onEnergyChanged),
          _editSlider('Fokus', es.focus ?? 3, es.onFocusChanged),
          _editSlider(
              'Körpergefühl', es.bodyFeel ?? 3, es.onBodyFeelChanged),
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
