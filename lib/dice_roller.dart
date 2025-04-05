import 'dart:math';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3, Matrix4;

class DiceRoller extends StatefulWidget {
  final int sides;
  final double size;
  final Color diceColor;
  final Color pipColor;
  final VoidCallback? onRollComplete;

  const DiceRoller({
    Key? key,
    this.sides = 6,
    this.size = 200,
    this.diceColor = Colors.white,
    this.pipColor = Colors.black,
    this.onRollComplete,
  }) : super(key: key);

  @override
  _DiceRollerState createState() => _DiceRollerState();
}

class _DiceRollerState extends State<DiceRoller> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotationX;
  late Animation<double> _rotationY;
  late Animation<double> _rotationZ;
  late Animation<double> _bounceAnimation;

  int _currentValue = 1;
  int _nextValue = 1;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _setupAnimations();
  }

  void _setupAnimations() {
    // Random rotations for realistic effect
    final endX = _random.nextDouble() * 10 * pi;
    final endY = _random.nextDouble() * 10 * pi;
    final endZ = _random.nextDouble() * 10 * pi;

    _rotationX = Tween<double>(begin: 0, end: endX).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOutQuad),
      ),
    );

    _rotationY = Tween<double>(begin: 0, end: endY).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOutQuad),
      ),
    );

    _rotationZ = Tween<double>(begin: 0, end: endZ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOutQuad),
      ),
    );

    // Bounce animation for realistic landing
    _bounceAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: -30.0),
        weight: 10.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -30.0, end: 0.0),
        weight: 15.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: -10.0),
        weight: 10.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -10.0, end: 0.0),
        weight: 15.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: -5.0),
        weight: 5.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -5.0, end: 0.0),
        weight: 10.0,
      ),
    ]).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.6, 1.0, curve: Curves.easeInOut),
      ),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _currentValue = _nextValue;
        });
        if (widget.onRollComplete != null) {
          widget.onRollComplete!();
        }
      }
    });

    _controller.addListener(() => setState(() {}));
  }

  void rollDice() {
    if (_controller.isAnimating) return;

    _nextValue = _random.nextInt(widget.sides) + 1;
    _setupAnimations();
    _controller.reset();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: rollDice,
          child: Container(
            height: widget.size + 50, // Add space for bounce
            width: widget.size,
            alignment: Alignment.center,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Transform(
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001) // Perspective
                    ..rotateX(_rotationX.value)
                    ..rotateY(_rotationY.value)
                    ..rotateZ(_rotationZ.value)
                    ..translate(0.0, _bounceAnimation.value, 0.0),
                  alignment: Alignment.center,
                  child: _buildDice(),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: rollDice,
          child: const Text('Roll Dice'),
        ),
      ],
    );
  }

  Widget _buildDice() {
    // This is a simplified 6-sided dice
    // For more sides, you would need different 3D models
    if (widget.sides > 6) {
      return _buildSimpleDice();
    }

    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: widget.diceColor,
        borderRadius: BorderRadius.circular(widget.size * 0.1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 10,
            offset: const Offset(5, 5),
          ),
        ],
      ),
      child: _controller.isAnimating
          ? _buildDiceFace(_random.nextInt(widget.sides) + 1)
          : _buildDiceFace(_currentValue),
    );
  }

  Widget _buildSimpleDice() {
    // For dice with more than 6 sides
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: widget.diceColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 10,
            offset: const Offset(5, 5),
          ),
        ],
      ),
      child: Center(
        child: Text(
          _controller.isAnimating
              ? '${_random.nextInt(widget.sides) + 1}'
              : '$_currentValue',
          style: TextStyle(
            fontSize: widget.size * 0.4,
            fontWeight: FontWeight.bold,
            color: widget.pipColor,
          ),
        ),
      ),
    );
  }

  Widget _buildDiceFace(int value) {
    // Layout for a standard 6-sided die
    switch (value) {
      case 1:
        return _DiceFace(
          pips: const [
            [0, 0, 0],
            [0, 1, 0],
            [0, 0, 0],
          ],
          pipColor: widget.pipColor,
          size: widget.size,
        );
      case 2:
        return _DiceFace(
          pips: const [
            [1, 0, 0],
            [0, 0, 0],
            [0, 0, 1],
          ],
          pipColor: widget.pipColor,
          size: widget.size,
        );
      case 3:
        return _DiceFace(
          pips: const [
            [1, 0, 0],
            [0, 1, 0],
            [0, 0, 1],
          ],
          pipColor: widget.pipColor,
          size: widget.size,
        );
      case 4:
        return _DiceFace(
          pips: const [
            [1, 0, 1],
            [0, 0, 0],
            [1, 0, 1],
          ],
          pipColor: widget.pipColor,
          size: widget.size,
        );
      case 5:
        return _DiceFace(
          pips: const [
            [1, 0, 1],
            [0, 1, 0],
            [1, 0, 1],
          ],
          pipColor: widget.pipColor,
          size: widget.size,
        );
      case 6:
        return _DiceFace(
          pips: const [
            [1, 0, 1],
            [1, 0, 1],
            [1, 0, 1],
          ],
          pipColor: widget.pipColor,
          size: widget.size,
        );
      default:
        return Center(
          child: Text(
            '$value',
            style: TextStyle(
              fontSize: widget.size * 0.4,
              fontWeight: FontWeight.bold,
              color: widget.pipColor,
            ),
          ),
        );
    }
  }
}

class _DiceFace extends StatelessWidget {
  final List<List<int>> pips;
  final Color pipColor;
  final double size;

  const _DiceFace({
    required this.pips,
    required this.pipColor,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(size * 0.15),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: pips.map((row) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: row.map((pip) {
              return pip == 1
                  ? Container(
                width: size * 0.15,
                height: size * 0.15,
                decoration: BoxDecoration(
                  color: pipColor,
                  shape: BoxShape.circle,
                ),
              )
                  : SizedBox(
                width: size * 0.15,
                height: size * 0.15,
              );
            }).toList(),
          );
        }).toList(),
      ),
    );
  }
}

// Example usage:
class DiceRollerDemo extends StatelessWidget {
  const DiceRollerDemo({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('3D Dice Roller'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DiceRoller(
              sides: 6,
              size: 150,
              diceColor: Colors.white,
              pipColor: Colors.black,
              onRollComplete: () {
                // Handle roll complete event
                debugPrint('Dice roll completed!');
              },
            ),
            const SizedBox(height: 20),
            // You can add multiple dice
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                DiceRoller(size: 100),
                SizedBox(width: 20),
                DiceRoller(size: 100),
              ],
            ),
          ],
        ),
      ),
    );
  }
}