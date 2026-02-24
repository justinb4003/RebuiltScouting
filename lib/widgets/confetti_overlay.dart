import 'dart:math';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

class ConfettiOverlay extends StatefulWidget {
  const ConfettiOverlay({super.key});

  @override
  State<ConfettiOverlay> createState() => ConfettiOverlayState();
}

class ConfettiOverlayState extends State<ConfettiOverlay> {
  late final ConfettiController _controller =
      ConfettiController(duration: const Duration(milliseconds: 400));

  void fire() {
    _controller.stop();
    _controller.play();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConfettiWidget(
        confettiController: _controller,
        blastDirection: pi / 2,
        blastDirectionality: BlastDirectionality.explosive,
        numberOfParticles: 15,
        maxBlastForce: 20,
        minBlastForce: 5,
        gravity: 0.3,
        colors: const [
          Colors.blue,
          Colors.green,
          Colors.orange,
          Colors.red,
          Colors.purple,
          Colors.yellow,
        ],
      ),
    );
  }
}
