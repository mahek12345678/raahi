import 'package:flutter/material.dart';

class FindRideScreen extends StatelessWidget {
  const FindRideScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(title: const Text('Find Ride')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const TextField(decoration: InputDecoration(labelText: 'Pickup', prefixIcon: Icon(Icons.my_location))),
              const SizedBox(height: 8),
              const TextField(decoration: InputDecoration(labelText: 'Drop', prefixIcon: Icon(Icons.location_on))),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: ElevatedButton(onPressed: () {}, child: const Text('Search'))),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: 4,
                  itemBuilder: (context, i) {
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(child: Text('D${i+1}')),
                        title: Text('Driver ${i+1} — 4 seats left'),
                        subtitle: const Text('Route similarity: 87% • ₹120'),
                        trailing: ElevatedButton(onPressed: () {}, child: const Text('Join')),
                      ),
                    );
                  },
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
