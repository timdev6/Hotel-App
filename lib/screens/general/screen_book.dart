import 'package:flutter/material.dart';

import 'package:csc322_starter_app/widgets/booking/cards.dart';
import 'package:csc322_starter_app/widgets/booking/rooms.dart';

class ScreenBook extends StatefulWidget {
  const ScreenBook({super.key});

  @override
  State<ScreenBook> createState() => _ScrenBookState();
}

class _ScrenBookState extends State<ScreenBook> {
  void _openRooms() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (context) => const Rooms()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Your Stay'),
      ),
      body: Column(
        children: [
          IntrinsicHeight(
            child: Row(
              children: [
                _Item(label: 'CHECK-IN', value: '2024-06-10'),
                const VerticalDivider(width: 32, thickness: 1),
            _Item(label: 'CHECK-OUT', value: '2024-06-17'),
                const VerticalDivider(width: 32, thickness: 1),
                _Item(label: 'GUESTS', value: '2'),
              ],
            ),
          ),
          SizedBox(height: 20),
          Cards(onTap: _openRooms),
          SizedBox(height: 20),
          Cards(onTap: _openRooms),
        ],
      ),
    );
  }
}

class _Item extends StatelessWidget {
  final String label;
  final String value;

  const _Item({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}