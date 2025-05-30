import 'package:flutter/material.dart';

class AccountingPage extends StatelessWidget {
  const AccountingPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Manage your accounting here.',
        style: TextStyle(fontSize: 20),
      ),
    );
  }
}