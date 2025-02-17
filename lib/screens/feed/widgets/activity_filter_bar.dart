import 'package:flutter/material.dart';

class ActivityFilterBar extends StatelessWidget {
  final List<String> selectedTypes;
  final Function(List<String>) onFilterChanged;

  const ActivityFilterBar({
    Key? key,
    required this.selectedTypes,
    required this.onFilterChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildFilterChip(
            'All',
            selectedTypes.isEmpty,
            () => onFilterChanged([]),
          ),
          _buildFilterChip(
            'Movies',
            selectedTypes.contains('post'),
            () => _toggleFilter('post'),
          ),
          _buildFilterChip(
            'mNp(s)',
            selectedTypes.contains('fork'),
            () => _toggleFilter('fork'),
          ),
          _buildFilterChip(
            'Likes',
            selectedTypes.contains('like'),
            () => _toggleFilter('like'),
          ),
          _buildFilterChip(
            'Comments',
            selectedTypes.contains('comment'),
            () => _toggleFilter('comment'),
          ),
          _buildFilterChip(
            'Follows',
            selectedTypes.contains('follow'),
            () => _toggleFilter('follow'),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onTap(),
        backgroundColor: Colors.grey[200],
        selectedColor: Colors.blue[100],
        checkmarkColor: Colors.blue,
        labelStyle: TextStyle(
          color: isSelected ? Colors.blue[900] : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  void _toggleFilter(String type) {
    if (selectedTypes.contains(type)) {
      // If this was the only selected type, clear all filters
      if (selectedTypes.length == 1) {
        onFilterChanged([]);
      } else {
        onFilterChanged(selectedTypes.where((t) => t != type).toList());
      }
    } else {
      onFilterChanged([...selectedTypes, type]);
    }
  }
} 