import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/models/lock_entry.dart';
import '../../core/services/native_bridge_service.dart';
import '../../core/services/storage_service.dart';

class AddLockScreen extends ConsumerStatefulWidget {
  const AddLockScreen({super.key});

  @override
  ConsumerState<AddLockScreen> createState() => _AddLockScreenState();
}

class _AddLockScreenState extends ConsumerState<AddLockScreen> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _installedApps = [];
  List<Map<String, dynamic>> _filteredApps = [];
  bool _isLoading = true;
  String? _error;

  Map<String, dynamic>? _selectedApp;
  
  // Tab/Mode state
  bool _isScheduled = false;

  // Instant mode state
  int _durationYears = 0;
  int _durationMonths = 0;
  int _durationWeeks = 0;
  int _durationDays = 0;
  int _durationHours = 1;

  // Scheduled mode state
  TimeOfDay _startTime = const TimeOfDay(hour: 6, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 15, minute: 0);
  final List<int> _selectedDays = [1, 2, 3, 4, 5]; // Mon-Fri default

  @override
  void initState() {
    super.initState();
    _loadApps();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadApps() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final nativeBridge = ref.read(nativeBridgeServiceProvider);
      final apps = await nativeBridge.getInstalledApps();
      
      apps.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));

      if (mounted) {
        setState(() {
          _installedApps = apps;
          _filteredApps = apps;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Gagal memuat daftar aplikasi: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredApps = _installedApps.where((app) {
        final name = (app['name'] as String).toLowerCase();
        return name.contains(query);
      }).toList();
    });
  }

  int _calculateTotalHours() {
    return (_durationYears * 365 * 24) + 
           (_durationMonths * 30 * 24) + 
           (_durationWeeks * 7 * 24) + 
           (_durationDays * 24) + 
           _durationHours;
  }

  Future<void> _startFocus() async {
    if (_selectedApp == null) return;

    final storage = ref.read(storageServiceProvider);
    
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String formattedStart = "${twoDigits(_startTime.hour)}:${twoDigits(_startTime.minute)}";
    String formattedEnd = "${twoDigits(_endTime.hour)}:${twoDigits(_endTime.minute)}";

    final totalHours = _isScheduled ? 0 : _calculateTotalHours();
    if (!openLockValidation(totalHours)) return;

    final entry = LockEntry(
      id: const Uuid().v4(),
      packageName: _selectedApp!['packageName'],
      appName: _selectedApp!['name'],
      appIconBytes: [], 
      startTime: DateTime.now(),
      durationHours: totalHours,
      isScheduled: _isScheduled,
      scheduledStart: _isScheduled ? formattedStart : null,
      scheduledEnd: _isScheduled ? formattedEnd : null,
      scheduledDays: _isScheduled ? _selectedDays : null,
    );

    await storage.addLock(entry);

    final activeRules = storage.getActiveRules();
    ref.read(nativeBridgeServiceProvider).startMonitoring(activeRules);

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isScheduled ? 'Jadwal fokus disimpan 🌿' : 'Detox dimulai 🌿'),
          backgroundColor: const Color(0xFF87A878),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  bool openLockValidation(int totalHours) {
    if (!_isScheduled && totalHours <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Durasi kunci tidak boleh 0!'), backgroundColor: Colors.red),
      );
      return false;
    }
    return true;
  }

  String _getEndTimePreview() {
    final endTime = DateTime.now().add(Duration(hours: _calculateTotalHours()));
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    
    if (_calculateTotalHours() > 24) {
      return "${twoDigits(endTime.day)}/${twoDigits(endTime.month)}/${endTime.year}";
    }
    return "${twoDigits(endTime.hour)}:${twoDigits(endTime.minute)}";
  }

  Future<void> _pickTime(bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF87A878),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  Widget _buildDayChip(int dayIndex, String label) {
    final isSelected = _selectedDays.contains(dayIndex);
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: const Color(0xFF87A878),
      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
      onSelected: (selected) {
        setState(() {
          if (selected) {
            _selectedDays.add(dayIndex);
          } else {
            if (_selectedDays.length > 1) { // Prevent unselecting all
              _selectedDays.remove(dayIndex);
            }
          }
        });
      },
    );
  }

  Widget _buildDurationPicker(String label, int value, ValueChanged<int?> onChanged, int max) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        DropdownButton<int>(
          value: value,
          icon: const Icon(Icons.arrow_drop_down, size: 16),
          underline: const SizedBox(),
          items: List.generate(max + 1, (index) {
            return DropdownMenuItem(
              value: index,
              child: Text(index.toString(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            );
          }),
          onChanged: (val) {
            if (val != null) onChanged(val);
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Pilih App & Durasi', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFF5F0E8),
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ChoiceChip(
                  label: const Text('Detox Penuh'),
                  selected: !_isScheduled,
                  selectedColor: const Color(0xFF87A878),
                  labelStyle: TextStyle(color: !_isScheduled ? Colors.white : Colors.black),
                  onSelected: (val) {
                    if (val) setState(() => _isScheduled = false);
                  },
                ),
                const SizedBox(width: 16),
                ChoiceChip(
                  label: const Text('Jadwal Rutin'),
                  selected: _isScheduled,
                  selectedColor: const Color(0xFF87A878),
                  labelStyle: TextStyle(color: _isScheduled ? Colors.white : Colors.black),
                  onSelected: (val) {
                    if (val) setState(() => _isScheduled = true);
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari aplikasi...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF87A878)))
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(_error!, textAlign: TextAlign.center),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadApps,
                              child: const Text('Coba Lagi'),
                            )
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredApps.length,
                        itemBuilder: (context, index) {
                          final app = _filteredApps[index];
                          final pkgName = app['packageName'] as String;
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.grey[200],
                              child: const Icon(Icons.apps, color: Colors.grey),
                            ),
                            title: Text(app['name']),
                            subtitle: Text(pkgName, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            trailing: Radio<String>(
                              value: pkgName,
                              groupValue: _selectedApp?['packageName'],
                              activeColor: const Color(0xFF87A878),
                              onChanged: (String? value) {
                                setState(() {
                                  _selectedApp = app;
                                });
                              },
                            ),
                            onTap: () {
                              setState(() {
                                _selectedApp = app;
                              });
                            },
                          );
                        },
                      ),
          ),
          
          // Bottom Control Panel
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: 20,
              vertical: isKeyboardOpen ? 12 : 20,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                )
              ],
            ),
            child: SafeArea(
              child: _isScheduled ? _buildScheduledPanel(isKeyboardOpen) : _buildInstantPanel(isKeyboardOpen),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstantPanel(bool isKeyboardOpen) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!isKeyboardOpen) ...[
          const Text(
            'Durasi Kunci Penuh',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildDurationPicker('Tahun', _durationYears, (v) => setState(() => _durationYears = v!), 5),
                const SizedBox(width: 12),
                _buildDurationPicker('Bulan', _durationMonths, (v) => setState(() => _durationMonths = v!), 11),
                const SizedBox(width: 12),
                _buildDurationPicker('Minggu', _durationWeeks, (v) => setState(() => _durationWeeks = v!), 4),
                const SizedBox(width: 12),
                _buildDurationPicker('Hari', _durationDays, (v) => setState(() => _durationDays = v!), 6),
                const SizedBox(width: 12),
                _buildDurationPicker('Jam', _durationHours, (v) => setState(() => _durationHours = v!), 23),
              ],
            ),
          ),
          if (_selectedApp != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F0E8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFF87A878), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "${_selectedApp!['name']} akan dikunci sampai ${_getEndTimePreview()}. Aturan tidak dapat dihapus 🔒",
                      style: const TextStyle(fontSize: 12, color: Color(0xFF2D2D2D)),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
        ],
        SizedBox(
          width: double.infinity,
          height: isKeyboardOpen ? 46 : 52,
          child: ElevatedButton(
            onPressed: _selectedApp == null ? null : _startFocus,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF87A878),
              disabledBackgroundColor: Colors.grey[300],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              'Mulai Detox 🌱',
              style: TextStyle(fontSize: isKeyboardOpen ? 15 : 17, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScheduledPanel(bool isKeyboardOpen) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!isKeyboardOpen) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(
                children: [
                  const Text("Mulai Jam", style: TextStyle(color: Colors.grey, fontSize: 13)),
                  TextButton(
                    onPressed: () => _pickTime(true),
                    child: Text(
                      "${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}",
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF87A878)),
                    ),
                  ),
                ],
              ),
              const Text("-", style: TextStyle(fontSize: 22, color: Colors.grey)),
              Column(
                children: [
                  const Text("Selesai Jam", style: TextStyle(color: Colors.grey, fontSize: 13)),
                  TextButton(
                    onPressed: () => _pickTime(false),
                    child: Text(
                      "${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}",
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF87A878)),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              _buildDayChip(1, 'Sen'),
              _buildDayChip(2, 'Sel'),
              _buildDayChip(3, 'Rab'),
              _buildDayChip(4, 'Kam'),
              _buildDayChip(5, 'Jum'),
              _buildDayChip(6, 'Sab'),
              _buildDayChip(7, 'Min'),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F0E8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.lock_outline, color: Color(0xFF87A878), size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Jadwal harian yang sudah dibuat tidak dapat dihapus 🔒",
                    style: TextStyle(fontSize: 11, color: Color(0xFF2D2D2D)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        SizedBox(
          width: double.infinity,
          height: isKeyboardOpen ? 46 : 52,
          child: ElevatedButton(
            onPressed: _selectedApp == null ? null : _startFocus,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF87A878),
              disabledBackgroundColor: Colors.grey[300],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              'Buat Jadwal 🌱',
              style: TextStyle(fontSize: isKeyboardOpen ? 15 : 17, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}
