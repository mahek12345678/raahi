import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({Key? key}) : super(key: key);

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Email fields
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;

  // Phone fields
  final _phoneCtrl = TextEditingController(text: '+91');
  final _codeCtrl = TextEditingController();
  String? _verificationId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _signInEmail() async {
    setState(() => _loading = true);
    try {
      await AuthService.signInWithEmail(_emailCtrl.text.trim(), _passwordCtrl.text);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Email sign-in failed: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _registerEmail() async {
    setState(() => _loading = true);
    try {
      await AuthService.registerWithEmail(_emailCtrl.text.trim(), _passwordCtrl.text);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Register failed: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendPhoneCode() async {
    setState(() => _loading = true);
    try {
      final id = await AuthService.verifyPhoneNumber(_phoneCtrl.text.trim());
      setState(() => _verificationId = id);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code sent')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Phone verification failed: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitSmsCode() async {
    if (_verificationId == null) return;
    setState(() => _loading = true);
    try {
      await AuthService.signInWithSmsCode(_verificationId!, _codeCtrl.text.trim());
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('SMS sign-in failed: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')), 
      body: Column(children: [
        TabBar(controller: _tabController, tabs: const [Tab(text: 'Email'), Tab(text: 'Phone')]),
        Expanded(
          child: TabBarView(controller: _tabController, children: [
            _emailTab(),
            _phoneTab(),
          ]),
        )
      ]),
    );
  }

  Widget _emailTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email')),
        const SizedBox(height: 8),
        TextField(controller: _passwordCtrl, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
        const SizedBox(height: 12),
        if (_loading) const CircularProgressIndicator(),
        if (!_loading) Row(children: [
          ElevatedButton(onPressed: _signInEmail, child: const Text('Sign in')),
          const SizedBox(width: 8),
          ElevatedButton(onPressed: _registerEmail, child: const Text('Register')),
        ])
      ]),
    );
  }

  Widget _phoneTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        TextField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'Phone (+country)')),
        const SizedBox(height: 8),
        ElevatedButton(onPressed: _sendPhoneCode, child: const Text('Send Code')),
        const SizedBox(height: 12),
        if (_verificationId != null) ...[
          TextField(controller: _codeCtrl, decoration: const InputDecoration(labelText: 'Enter SMS code')),
          const SizedBox(height: 8),
          ElevatedButton(onPressed: _submitSmsCode, child: const Text('Verify')),
        ],
        if (_loading) const Padding(padding: EdgeInsets.only(top:12.0), child: CircularProgressIndicator()),
      ]),
    );
  }
}
