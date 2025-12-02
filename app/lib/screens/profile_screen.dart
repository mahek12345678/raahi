import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int coins = 120;
  int streak = 3;

  Future<void> _rewardSample() async {
    final uid = AuthService.currentUid() ?? FirebaseAuth.instance.currentUser?.uid;
    setState(() => coins += 10);
    setState(() => streak += 1);
    if (uid == null) return;
    try {
      await FirebaseService.updateUserCoinsAndStreak(uid, 10, incrementStreak: true);
    } catch (e) {
      // ignore: avoid_print
      print('Firebase update failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              CircleAvatar(radius: 36, child: Icon(Icons.person, size: 36)),
              SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('User Name', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text('Verified: • College ID')
              ])
            ]),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                title: const Text('Raahi Coins'),
                trailing: Text('$coins', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                title: const Text('Streak'),
                subtitle: const Text('Days of consecutive safe rides'),
                trailing: Text('$streak', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(onPressed: _rewardSample, icon: const Icon(Icons.star), label: const Text('Simulate Reward')),
            const SizedBox(height: 8),
            ListTile(leading: const Icon(Icons.verified), title: const Text('ID Verification'), trailing: ElevatedButton(onPressed: () {}, child: const Text('Upload'))),
            ListTile(leading: const Icon(Icons.contacts), title: const Text('Emergency Contacts'), onTap: () {}),
            ListTile(leading: const Icon(Icons.logout), title: const Text('Logout'), onTap: () {}),
          ]),
        ),
      ),
    );
  }
}
