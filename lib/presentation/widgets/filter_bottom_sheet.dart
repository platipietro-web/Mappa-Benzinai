import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mappa_prezzi_benzina/presentation/theme/app_theme.dart';

class FilterBottomSheet extends StatefulWidget {
  final List<String> selectedFuelTypes;
  final List<String> selectedBrands;
  final String sortBy;
  final Function(List<String>, List<String>, String) onApply;

  const FilterBottomSheet({
    Key? key,
    required this.selectedFuelTypes,
    required this.selectedBrands,
    required this.sortBy,
    required this.onApply,
  }) : super(key: key);

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  late List<String> _selectedFuelTypes;
  late List<String> _selectedBrands;
  late String _sortBy;

  // Tutti i tipi carburante con colore e icona
  static const _fuelTypes = [
    _FuelChip('Benzina',          Color(0xFF4CAF50), Icons.local_gas_station),
    _FuelChip('Benzina Speciale 100', Color(0xFF388E3C), Icons.local_gas_station),
    
    
    _FuelChip('Diesel',           Color(0xFF2196F3), Icons.local_gas_station),
    _FuelChip('Diesel+',          Color(0xFF1976D2), Icons.local_gas_station),
    _FuelChip('Diesel HVO',       Color(0xFF0D47A1), Icons.eco),
    
    _FuelChip('HVO',              Color(0xFF00796B), Icons.eco),
    _FuelChip('GPL',              Color(0xFFFF9800), Icons.bubble_chart),
    _FuelChip('Metano',           Color(0xFF9C27B0), Icons.air),
    _FuelChip('GNC',              Color(0xFF7B1FA2), Icons.air),
    _FuelChip('GNL',              Color(0xFF4A148C), Icons.air),
    _FuelChip('Idrogeno',         Color(0xFF00BCD4), Icons.bolt),
  ];

  static const List<String> _availableBrands = [
    'Agip', 'Eni', 'IP', 'Esso', 'Shell', 'Q8',
    'Tamoil', 'Total', 'TotalEnergies', 'Cepsa',
    'Lukoil', 'Pam', 'Conad', 'Retitalia',
    'Distributore', 'Pompe Bianche',
  ];

  @override
  void initState() {
    super.initState();
    _selectedFuelTypes = List.from(widget.selectedFuelTypes);
    _selectedBrands = List.from(widget.selectedBrands);
    _sortBy = widget.sortBy;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.borderColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Filtri',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
              const SizedBox(height: 20),

              // ── Tipo carburante ──────────────────────────────────────────
              _sectionHeader(
                'Tipo carburante',
                _selectedFuelTypes.isNotEmpty
                    ? TextButton(
                        onPressed: () =>
                            setState(() => _selectedFuelTypes.clear()),
                        child: Text('Deseleziona tutto',
                            style: GoogleFonts.poppins(fontSize: 12)),
                      )
                    : TextButton(
                        onPressed: () => setState(() {
                          _selectedFuelTypes = _fuelTypes
                              .map((f) => f.label)
                              .toList();
                        }),
                        child: Text('Seleziona tutto',
                            style: GoogleFonts.poppins(fontSize: 12)),
                      ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _fuelTypes.map((fuel) {
                  final isSelected =
                      _selectedFuelTypes.contains(fuel.label);
                  return _FuelFilterChip(
                    fuel: fuel,
                    isSelected: isSelected,
                    onTap: () => setState(() {
                      if (isSelected) {
                        _selectedFuelTypes.remove(fuel.label);
                      } else {
                        _selectedFuelTypes.add(fuel.label);
                      }
                    }),
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),

              // ── Brand ────────────────────────────────────────────────────
              _sectionHeader(
                'Brand',
                TextButton(
                  onPressed: () =>
                      setState(() => _selectedBrands.clear()),
                  child: Text('Tutti',
                      style: GoogleFonts.poppins(fontSize: 12)),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableBrands.map((brand) {
                  final isSelected = _selectedBrands.contains(brand);
                  return FilterChip(
                    label: Text(brand),
                    selected: isSelected,
                    onSelected: (selected) => setState(() {
                      if (selected) {
                        _selectedBrands.add(brand);
                      } else {
                        _selectedBrands.remove(brand);
                      }
                    }),
                    backgroundColor: AppTheme.backgroundColor,
                    selectedColor:
                        AppTheme.primaryColor.withOpacity(0.15),
                    checkmarkColor: AppTheme.primaryColor,
                    labelStyle: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isSelected
                          ? AppTheme.primaryColor
                          : AppTheme.textPrimaryColor,
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),

              // ── Ordina per ───────────────────────────────────────────────
              _sectionHeader('Ordina per', null),
              const SizedBox(height: 8),
              ...[
                ('price', 'Prezzo (dal più basso)', Icons.euro),
                ('distance', 'Distanza', Icons.near_me),
                ('rating', 'Valutazione', Icons.star),
              ].map((option) {
                return RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  title: Row(
                    children: [
                      Icon(option.$3,
                          size: 18, color: AppTheme.textSecondaryColor),
                      const SizedBox(width: 8),
                      Text(
                        option.$2,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: AppTheme.textPrimaryColor,
                        ),
                      ),
                    ],
                  ),
                  value: option.$1,
                  groupValue: _sortBy,
                  onChanged: (value) =>
                      setState(() => _sortBy = value!),
                  activeColor: AppTheme.primaryColor,
                );
              }),

              const SizedBox(height: 20),

              // ── Bottoni ──────────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Annulla',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        widget.onApply(
                            _selectedFuelTypes, _selectedBrands, _sortBy);
                        Navigator.pop(context);
                      },
                      child: Text('Applica',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, Widget? action) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimaryColor,
          ),
        ),
        if (action != null) action,
      ],
    );
  }
}

// ── Chip carburante colorato ───────────────────────────────────────────────────

class _FuelChip {
  final String label;
  final Color color;
  final IconData icon;
  const _FuelChip(this.label, this.color, this.icon);
}

class _FuelFilterChip extends StatelessWidget {
  final _FuelChip fuel;
  final bool isSelected;
  final VoidCallback onTap;

  const _FuelFilterChip({
    required this.fuel,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? fuel.color.withOpacity(0.15)
              : AppTheme.backgroundColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? fuel.color : AppTheme.borderColor,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(fuel.icon,
                size: 14,
                color:
                    isSelected ? fuel.color : AppTheme.textSecondaryColor),
            const SizedBox(width: 6),
            Text(
              fuel.label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected
                    ? fuel.color
                    : AppTheme.textPrimaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}