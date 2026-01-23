import 'package:flutter/material.dart';

class QnaScreen extends StatelessWidget {
  const QnaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QnA')),
      body: const Center(child: Text('대원 여러분의 궁금한 점을 해결해 드립니다.')),
    );
  }
}