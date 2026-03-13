import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../models/drink.dart';
import '../../../models/drink_entry.dart';
import '../../../providers/entries_provider.dart';
import '../../../router/route_names.dart';
import '../../../services/haptic_service.dart';
import '../../../services/supabase_service.dart';
import '../../../widgets/common/bb_button.dart';
import '../../../widgets/common/bb_success_overlay.dart';

class DrinkTrackerScreen extends ConsumerStatefulWidget {
  const DrinkTrackerScreen({super.key});

  @override
  ConsumerState<DrinkTrackerScreen> createState() =>
      _DrinkTrackerScreenState();
}

class _DrinkTrackerScreenState extends ConsumerState<DrinkTrackerScreen> {
  final _searchController = TextEditingController();
  final _customAmountController = TextEditingController();
  DateTime _trackedAt = DateTime.now();
  List<Drink> _allDrinks = [];
  List<Drink> _filteredDrinks = [];
  Drink? _selectedDrink;
  int? _selectedAmount;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _showSuccess = false;
  int _todayTotal = 0;

  @override
  void initState() {
    super.initState();
    _loadDrinks();
    _loadTodayTotal();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _customAmountController.dispose();
    super.dispose();
  }

  Future<void> _loadDrinks() async {
    try {
      final data = await SupabaseService.client
          .from('drinks')
          .select()
          .order('name');
      setState(() {
        _allDrinks = (data as List).map((e) => Drink.fromDbRow(e)).toList();
        _filteredDrinks = _allDrinks;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadTodayTotal() async {
    try {
      final userId = SupabaseService.userId;
      if (userId == null) return;
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final data = await SupabaseService.client
          .from('drink_entries')
          .select('amount_ml')
          .eq('user_id', userId)
          .gte('tracked_at', startOfDay.toIso8601String())
          .lt('tracked_at', startOfDay.add(const Duration(days: 1)).toIso8601String());
      final total = (data as List).fold<int>(0, (sum, e) => sum + (e['amount_ml'] as int));
      setState(() => _todayTotal = total);
    } catch (_) {}
  }

  void _filterDrinks(String query) {
    if (query.isEmpty) {
      setState(() => _filteredDrinks = _allDrinks);
      return;
    }
    final words = query.toLowerCase().split(' ');
    setState(() {
      _filteredDrinks = _allDrinks.where((d) {
        final name = d.name.toLowerCase();
        return words.every((w) => name.contains(w));
      }).toList()
        ..sort((a, b) {
          final aStarts = a.name.toLowerCase().startsWith(query.toLowerCase());
          final bStarts = b.name.toLowerCase().startsWith(query.toLowerCase());
          if (aStarts && !bStarts) return -1;
          if (!aStarts && bStarts) return 1;
          return a.name.compareTo(b.name);
        });
    });
  }

  Future<void> _save() async {
    if (_selectedDrink == null || _selectedAmount == null) return;
    setState(() => _isSaving = true);
    try {
      final entry = DrinkEntry(
        id: const Uuid().v4(),
        trackedAt: _trackedAt,
        drinkId: _selectedDrink!.id,
        drinkName: _selectedDrink!.name,
        amountMl: _selectedAmount!,
      );
      await ref.read(entriesProvider.notifier).addDrinkEntry(entry);
      setState(() => _showSuccess = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fehler beim Speichern.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showSuccess) {
      return BbSuccessOverlay(
        message: 'Getränk gespeichert!',
        onDismissed: () {
          if (mounted) context.go(RoutePaths.dashboard);
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        title: const Text('Was hast du getrunken?'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Today's total
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.info.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.water_drop, color: AppTheme.info),
                        const SizedBox(width: 8),
                        Text(
                          'Heute: $_todayTotal ml',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.info,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Search
                  TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Getränk suchen...',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: _filterDrinks,
                  ),
                  const SizedBox(height: 16),

                  // Drink grid
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _filteredDrinks.take(20).map((drink) {
                      final isSelected = _selectedDrink?.id == drink.id;
                      return GestureDetector(
                        onTap: () {
                          HapticService.selection();
                          setState(() => _selectedDrink = drink);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.primary.withValues(alpha: 0.2)
                                : AppTheme.card,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? AppTheme.primary : AppTheme.border,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Text(
                            drink.name,
                            style: TextStyle(
                              fontWeight:
                                  isSelected ? FontWeight.w600 : FontWeight.w400,
                              color: AppTheme.foreground,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  if (_selectedDrink != null) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'Menge',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    // Predefined sizes
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: AppConstants.drinkSizes.map((size) {
                        final isSelected = _selectedAmount == size;
                        return GestureDetector(
                          onTap: () {
                            HapticService.selection();
                            setState(() => _selectedAmount = size);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.primary.withValues(alpha: 0.2)
                                  : AppTheme.card,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected ? AppTheme.primary : AppTheme.border,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Text(
                              '$size ml',
                              style: TextStyle(
                                fontWeight:
                                    isSelected ? FontWeight.w600 : FontWeight.w400,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                    // Custom amount
                    TextField(
                      controller: _customAmountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: 'Andere Menge (ml)',
                      ),
                      onChanged: (v) {
                        final parsed = int.tryParse(v);
                        if (parsed != null && parsed > 0) {
                          setState(() => _selectedAmount = parsed);
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // Date/Time
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.access_time),
                      title: Text(
                        '${_trackedAt.day}.${_trackedAt.month}.${_trackedAt.year} '
                        '${_trackedAt.hour.toString().padLeft(2, '0')}:'
                        '${_trackedAt.minute.toString().padLeft(2, '0')} Uhr',
                      ),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _trackedAt,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                          locale: const Locale('de'),
                        );
                        if (date != null && mounted) {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(_trackedAt),
                          );
                          if (time != null) {
                            setState(() {
                              _trackedAt = DateTime(
                                date.year, date.month, date.day,
                                time.hour, time.minute,
                              );
                            });
                          }
                        }
                      },
                    ),
                    const SizedBox(height: 24),
                    BbButton(
                      label: 'Getränk speichern',
                      isLoading: _isSaving,
                      onPressed: _selectedAmount != null ? _save : null,
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
