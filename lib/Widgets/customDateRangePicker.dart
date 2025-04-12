import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CustomDateRangePicker extends StatefulWidget {
  final DateTime initialStartDate;
  final DateTime initialEndDate;
  final Function(DateTime, DateTime) onDateRangeSelected;

  const CustomDateRangePicker({
    Key? key,
    required this.initialStartDate,
    required this.initialEndDate,
    required this.onDateRangeSelected,
  }) : super(key: key);

  @override
  State<CustomDateRangePicker> createState() => _CustomDateRangePickerState();
}

class _CustomDateRangePickerState extends State<CustomDateRangePicker> {
  late DateTime startDate;
  late DateTime endDate;
  
  final List<String> _predefinedRanges = [
    'Today',
    'Yesterday',
    'Last 7 Days',
    'Last 30 Days',
    'This Month',
    'Last Month',
    'Custom Range'
  ];
  
  String _selectedRange = 'Last 7 Days';
  
  @override
  void initState() {
    super.initState();
    startDate = widget.initialStartDate;
    endDate = widget.initialEndDate;
    
    // Set the initial selected range based on the dates
    _determineInitialSelectedRange();
  }
  
  void _determineInitialSelectedRange() {
    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);
    DateTime yesterday = today.subtract(const Duration(days: 1));
    DateTime last7Days = today.subtract(const Duration(days: 6));
    DateTime last30Days = today.subtract(const Duration(days: 29));
    
    DateTime firstDayCurrentMonth = DateTime(now.year, now.month, 1);
    DateTime lastDayPreviousMonth = DateTime(now.year, now.month, 0);
    DateTime firstDayPreviousMonth = DateTime(now.year, now.month - 1, 1);
    
    if (startDate.isAtSameMomentAs(today) && endDate.isAtSameMomentAs(today.add(const Duration(days: 1)))) {
      _selectedRange = 'Today';
    } else if (startDate.isAtSameMomentAs(yesterday) && endDate.isAtSameMomentAs(today)) {
      _selectedRange = 'Yesterday';
    } else if (startDate.isAtSameMomentAs(last7Days) && endDate.isAtSameMomentAs(today.add(const Duration(days: 1)))) {
      _selectedRange = 'Last 7 Days';
    } else if (startDate.isAtSameMomentAs(last30Days) && endDate.isAtSameMomentAs(today.add(const Duration(days: 1)))) {
      _selectedRange = 'Last 30 Days';
    } else if (startDate.isAtSameMomentAs(firstDayCurrentMonth) && endDate.isAtSameMomentAs(today.add(const Duration(days: 1)))) {
      _selectedRange = 'This Month';
    } else if (startDate.isAtSameMomentAs(firstDayPreviousMonth) && endDate.isAtSameMomentAs(lastDayPreviousMonth.add(const Duration(days: 1)))) {
      _selectedRange = 'Last Month';
    } else {
      _selectedRange = 'Custom Range';
    }
  }
  
  void _setDateRange(String range) {
    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);
    
    setState(() {
      _selectedRange = range;
      
      switch (range) {
        case 'Today':
          startDate = today;
          endDate = today.add(const Duration(days: 1));
          break;
        case 'Yesterday':
          startDate = today.subtract(const Duration(days: 1));
          endDate = today;
          break;
        case 'Last 7 Days':
          startDate = today.subtract(const Duration(days: 6));
          endDate = today.add(const Duration(days: 1));
          break;
        case 'Last 30 Days':
          startDate = today.subtract(const Duration(days: 29));
          endDate = today.add(const Duration(days: 1));
          break;
        case 'This Month':
          startDate = DateTime(now.year, now.month, 1);
          endDate = today.add(const Duration(days: 1));
          break;
        case 'Last Month':
          startDate = DateTime(now.year, now.month - 1, 1);
          endDate = DateTime(now.year, now.month, 1);
          break;
        case 'Custom Range':
          // Keep the current dates for custom range
          break;
      }
    });
  }
  
  Future<void> _selectCustomStartDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color.fromARGB(255, 208, 168, 248),
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && picked != startDate) {
      setState(() {
        startDate = picked;
        _selectedRange = 'Custom Range';
      });
    }
  }
  
  Future<void> _selectCustomEndDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: endDate,
      firstDate: startDate,
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color.fromARGB(255, 221, 192, 250),
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && picked != endDate) {
      setState(() {
        // Add one day to include the end date in the range
        endDate = DateTime(picked.year, picked.month, picked.day).add(const Duration(days: 1));
        _selectedRange = 'Custom Range';
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Date Range',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Predefined ranges
            SizedBox(
              height: 200,
              child: ListView.builder(
                itemCount: _predefinedRanges.length,
                itemBuilder: (context, index) {
                  final range = _predefinedRanges[index];
                  final isSelected = _selectedRange == range;
                  
                  return InkWell(
                    onTap: () => _setDateRange(range),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.green.withOpacity(0.1) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Text(
                            range,
                            style: TextStyle(
                              color: isSelected ? Colors.green : Colors.black,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          const Spacer(),
                          if (isSelected)
                            const Icon(Icons.check, color: Colors.green, size: 20),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            
            const Divider(),
            
            // Custom date range
            if (_selectedRange == 'Custom Range')
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Custom Range',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: _selectCustomStartDate,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Start Date',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                Text(
                                  DateFormat('MMM dd, yyyy').format(startDate),
                                  style: const TextStyle(
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: InkWell(
                          onTap: _selectCustomEndDate,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'End Date',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                Text(
                                  DateFormat('MMM dd, yyyy').format(endDate.subtract(const Duration(days: 1))),
                                  style: const TextStyle(
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            
            const SizedBox(height: 16),
            
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color.fromARGB(255, 221, 192, 250),
                  ),
                  onPressed: () {
                    widget.onDateRangeSelected(startDate, endDate);
                    Navigator.pop(context);
                  },
                  child: const Text('Apply'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}