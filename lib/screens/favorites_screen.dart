import 'package:flutter/material.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Favoriler'),
        backgroundColor: Colors.blue,
      ),
      body: const Center(
        child: Text(
          'Favoriler sayfası yakında kullanıma açılacak',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
    );
  }
} 