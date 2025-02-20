import 'package:flutter/material.dart';

class OhftokScreen extends StatefulWidget {
  const OhftokScreen({Key? key}) : super(key: key);

  static const String routeName = '/ohftok';

  @override
  State<OhftokScreen> createState() => _OhftokScreenState();
}

class _OhftokScreenState extends State<OhftokScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ohftok'),
      ),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Text(
                'Welcome to Ohftok Screen',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 20),
              Text(
                'This is a new screen template',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 