import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CreateRideScreen extends StatefulWidget {
  final String? initialPickup;
  final String? initialDrop;
  final DateTime? initialDateTime;
  final String? initialVehicle;
  final bool autoConfirm;

  const CreateRideScreen({Key? key, this.initialPickup, this.initialDrop, this.initialDateTime, this.initialVehicle, this.autoConfirm = false}) : super(key: key);

  @override
  State<CreateRideScreen> createState() => _CreateRideScreenState();
}

class _CreateRideScreenState extends State<CreateRideScreen> {
  late final TextEditingController _pickupCtrl;
  late final TextEditingController _dropCtrl;
  DateTime? _date;
  int _seats = 1;
  bool _recurring = false;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(title: const Text('Create Ride')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            const SizedBox(height: 8),
            TextField(controller: _pickupCtrl, decoration: const InputDecoration(labelText: 'Pickup')),
            const SizedBox(height: 8),
            TextField(controller: _dropCtrl, decoration: const InputDecoration(labelText: 'Drop')),
            const SizedBox(height: 8),
            ListTile(
              title: Text(_date == null ? 'Select Date & Time' : _date.toString()),
              trailing: ElevatedButton(onPressed: _pickDateTime, child: const Text('Pick')),
            ),
            Row(children: [
              const Text('Seats'),
              IconButton(icon: const Icon(Icons.remove), onPressed: () => setState(() => _seats = (_seats - 1).clamp(1, 6))),
              Text('$_seats'),
              IconButton(icon: const Icon(Icons.add), onPressed: () => setState(() => _seats = (_seats + 1).clamp(1, 6))),
            ]),
            SwitchListTile(title: const Text('Recurring'), value: _recurring, onChanged: (v) => setState(() => _recurring = v)),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _createRide, child: const Text('Create Trip'))
          ]),
        ),
      ),
    );
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
    if (date == null) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (time == null) return;
    setState(() {
      _date = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _createRide() async {
    final ride = {
      'pickup': _pickupCtrl.text,
      'drop': _dropCtrl.text,
      'date': _date?.toIso8601String(),
      'seats': _seats,
      'recurring': _recurring,
      'status': 'open',
      'createdAt': DateTime.now().toIso8601String(),
      'ownerId': FirebaseAuth.instance.currentUser?.uid ?? 'anonymous',
    };

    try {
      final id = await FirebaseService.createRide(ride);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ride created: $id')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to create ride (no Firebase)')));
      }
    }
  }
  
  @override
  void initState() {
    super.initState();
    _pickupCtrl = TextEditingController(text: widget.initialPickup ?? '');
    _dropCtrl = TextEditingController(text: widget.initialDrop ?? '');
    _date = widget.initialDateTime;

    if (widget.autoConfirm) {
      // Auto-create after a short delay so UI can render
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) _createRide();
      });
    }
  }

  @override
  void dispose() {
    _pickupCtrl.dispose();
    _dropCtrl.dispose();
    super.dispose();
  }
}
