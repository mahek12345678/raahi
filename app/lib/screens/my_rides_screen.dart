import 'package:flutter/material.dart';

class MyRidesScreen extends StatelessWidget {
  const MyRidesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(title: const Text('My Rides')),
        body: DefaultTabController(
          length: 3,
          child: Column(children: [
            const TabBar(tabs: [Tab(text: 'Upcoming'), Tab(text: 'Ongoing'), Tab(text: 'Completed')]),
            Expanded(
              child: TabBarView(children: [
                _rideList('Upcoming'),
                _rideList('Ongoing'),
                _rideList('Completed'),
              ]),
            )
          ]),
        ),
      ),
    );
  }

  Widget _rideList(String title) {
    return ListView.builder(
      itemCount: 3,
      itemBuilder: (context, i) => Card(
        child: ListTile(
          title: Text('$title Ride ${i + 1}'),
          subtitle: const Text('Hostel → Lecture Hall • 9:00 AM'),
          trailing: ElevatedButton(onPressed: () {}, child: const Text('Track')),
        ),
      ),
    );
  }
}
