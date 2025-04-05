import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3, Matrix4;
import 'package:audioplayers/audioplayers.dart';

class Dice3DRoller extends StatefulWidget {
  final double size;
  final Color diceColor;
  final Color pipColor;
  final VoidCallback? onRollComplete;
  final bool useCustomFaces;
  final bool playSounds;

  const Dice3DRoller({
    Key? key,
    this.size = 200,
    this.diceColor = Colors.white,
    this.pipColor = Colors.black,
    this.onRollComplete,
    this.useCustomFaces = false,
    this.playSounds = true,
  }) : super(key: key);

  @override
  _Dice3DRollerState createState() => _Dice3DRollerState();
}

class _Dice3DRollerState extends State<Dice3DRoller> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotationX;
  late Animation<double> _rotationY;
  late Animation<double> _rotationZ;
  late Animation<double> _bounceAnimation;

  int _currentValue = 1;
  final Random _random = Random();

  // Final rotation values that determine which face is up
  late double _finalRotX;
  late double _finalRotY;
  late double _finalRotZ;

  // Sound player
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _soundsLoaded = false;

  // Custom face images
  List<ui.Image?> _faceImages = List.filled(6, null);
  bool _imagesLoaded = false;

  // Possible rotation combinations for each face (improved for realistic physics)
  final Map<int, List<List<double>>> _faceRotations = {
    1: [[0, 0, 0], [2 * pi, 0, 0], [0, 2 * pi, 0], [0, 0, 2 * pi]],
    2: [[pi / 2, 0, 0], [3 * pi / 2, 0, 0]],
    3: [[0, pi / 2, 0], [0, 3 * pi / 2, 0]],
    4: [[0, -pi / 2, 0], [0, -3 * pi / 2, 0]],
    5: [[-pi / 2, 0, 0], [-3 * pi / 2, 0, 0]],
    6: [[pi, 0, 0], [-pi, 0, 0], [pi, pi, 0], [0, pi, pi]],
  };

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 4000),
      vsync: this,
    );

    _setupAnimations();

    if (widget.playSounds) {
      _loadSounds();
    }

    if (widget.useCustomFaces) {
      _loadDiceFaceImages();
    }
  }

  Future<void> _loadSounds() async {
    try {
      await _audioPlayer.setSource(AssetSource('sounds/dice_roll.mp3'));
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      _soundsLoaded = true;
    } catch (e) {
      debugPrint('Error loading sound effects: $e');
    }
  }

  Future<void> _loadDiceFaceImages() async {
    try {
      for (int i = 1; i <= 6; i++) {
        final ByteData data = await rootBundle.load('assets/images/dice_face_$i.png');
        final Uint8List bytes = data.buffer.asUint8List();
        final ui.Codec codec = await ui.instantiateImageCodec(bytes);
        final ui.FrameInfo frameInfo = await codec.getNextFrame();

        setState(() {
          _faceImages[i-1] = frameInfo.image;
        });
      }

      setState(() {
        _imagesLoaded = true;
      });
    } catch (e) {
      debugPrint('Error loading dice face images: $e');
    }
  }

  void _setupAnimations() {
    // Select a random result
    _currentValue = _random.nextInt(6) + 1;

    // Choose one of the possible rotation combinations for this face
    final rotations = _faceRotations[_currentValue]!;
    final selectedRotation = rotations[_random.nextInt(rotations.length)];

    _finalRotX = selectedRotation[0];
    _finalRotY = selectedRotation[1];
    _finalRotZ = selectedRotation[2];

    // Add some additional rotations for a dramatic effect (multiple spins)
    final additionalSpins = 2 + _random.nextInt(3); // 2-4 additional spins

    final endX = _finalRotX + (2 * pi * additionalSpins) + (_random.nextDouble() * pi / 8);
    final endY = _finalRotY + (2 * pi * additionalSpins) + (_random.nextDouble() * pi / 8);
    final endZ = _finalRotZ + (2 * pi * additionalSpins) + (_random.nextDouble() * pi / 8);

    _rotationX = Tween<double>(begin: 0, end: endX).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutQuad),
      ),
    );

    _rotationY = Tween<double>(begin: 0, end: endY).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutQuad),
      ),
    );

    _rotationZ = Tween<double>(begin: 0, end: endZ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutQuad),
      ),
    );

    // Bounce animation for realistic landing
    _bounceAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: -40.0),
        weight: 10.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -40.0, end: 0.0),
        weight: 15.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: -20.0),
        weight: 10.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -20.0, end: 0.0),
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
        // Force a rebuild to ensure proper z-ordering once the animation completes
        setState(() {});
        if (widget.onRollComplete != null) {
          widget.onRollComplete!();
        }
      }
    });

    _controller.addListener(() => setState(() {}));
  }

  void rollDice() {
    if (_controller.isAnimating) return;

    _setupAnimations();

    if (widget.playSounds && _soundsLoaded) {
      _audioPlayer.stop();
      _audioPlayer.resume();
    }

    _controller.reset();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
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
                  child: _build3DDice(),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 50),
        ElevatedButton(
          onPressed: rollDice,
          child: const Text('Roll Dice'),
        ),
        const SizedBox(height: 50),
        Text('Current value: $_currentValue'),
      ],
    );
  }

  Widget _build3DDice() {
    final faceSize = widget.size * 0.95;
    final halfSize = faceSize / 2;

    // Calculate current rotation to determine which faces are visible
    // Use animation values during animation and final values when stopped
    final currentRotX = _controller.isAnimating ? _rotationX.value : _finalRotX;
    final currentRotY = _controller.isAnimating ? _rotationY.value : _finalRotY;
    final currentRotZ = _controller.isAnimating ? _rotationZ.value : _finalRotZ;

    // Normalize rotations for z-order calculations
    final double normalizedRotX = currentRotX % (2 * pi);
    final double normalizedRotY = currentRotY % (2 * pi);
    final double normalizedRotZ = currentRotZ % (2 * pi);

    // Calculate visibility factors based on current rotations
    final frontBackFactor = cos(normalizedRotY);
    final leftRightFactor = cos(normalizedRotX);
    final topBottomFactor = cos(normalizedRotZ);

    // Calculate the Z-order based on rotations
    final Map<String, double> zOrder = {
      'front': frontBackFactor,
      'back': -frontBackFactor,
      'right': leftRightFactor,
      'left': -leftRightFactor,
      'top': topBottomFactor,
      'bottom': -topBottomFactor,
    };

    // Sort faces by their z-order (from back to front)
    final sortedFaces = ['front', 'back', 'right', 'left', 'top', 'bottom']
      ..sort((a, b) => zOrder[a]!.compareTo(zOrder[b]!));

    // Map faces to their corresponding dice values
    final faceValueMap = {
      'front': 1,
      'back': 6,
      'right': 3,
      'left': 4,
      'top': 2,
      'bottom': 5,
    };

    // Create a list to store our rendered faces in the correct order
    final List<Widget> orderedFaces = [];

    // Build faces in the calculated order (back to front)
    for (final face in sortedFaces) {
      // Create transform for each face
      Matrix4 transform = Matrix4.identity();

      switch (face) {
        case 'front':
          transform.translate(0.0, 0.0, halfSize);
          break;
        case 'back':
          transform
            ..translate(0.0, 0.0, -halfSize)
            ..rotateY(pi);
          break;
        case 'right':
          transform
            ..translate(halfSize, 0.0, 0.0)
            ..rotateY(pi/2);
          break;
        case 'left':
          transform
            ..translate(-halfSize, 0.0, 0.0)
            ..rotateY(-pi/2);
          break;
        case 'top':
          transform
            ..translate(0.0, -halfSize, 0.0)
            ..rotateX(-pi/2);
          break;
        case 'bottom':
          transform
            ..translate(0.0, halfSize, 0.0)
            ..rotateX(pi/2);
          break;
      }

      // Add face to list
      orderedFaces.add(
        Transform(
          transform: transform,
          alignment: Alignment.center,
          child: _buildDiceFace(faceValueMap[face]!, faceSize),
        ),
      );
    }

    return Stack(
      children: orderedFaces,
    );
  }

  Widget _buildDiceFace(int value, double faceSize) {
    // Create a single face with proper styling
    return Container(
      width: faceSize,
      height: faceSize,
      decoration: BoxDecoration(
        color: widget.diceColor,
        border: Border.all(color: Colors.black26, width: 1),
        borderRadius: BorderRadius.circular(faceSize * 0.1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 5,
            offset: const Offset(1, 1),
          ),
        ],
      ),
      child: widget.useCustomFaces && _imagesLoaded
          ? _buildCustomFace(value - 1, faceSize)
          : _buildPips(value, faceSize),
    );
  }

  Widget _buildCustomFace(int faceIndex, double faceSize) {
    if (_faceImages[faceIndex] == null) {
      // Fallback to pips if image isn't loaded
      return _buildPips(faceIndex + 1, faceSize);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(faceSize * 0.1),
      child: CustomPaint(
        size: Size(faceSize, faceSize),
        painter: DiceFaceImagePainter(_faceImages[faceIndex]!),
      ),
    );
  }

  Widget _buildPips(int faceValue, double faceSize) {
    final pipSize = faceSize * 0.15;
    final padding = faceSize * 0.15;

    switch (faceValue) {
      case 1:
        return Center(
          child: _buildPip(pipSize),
        );
      case 2:
        return Padding(
          padding: EdgeInsets.all(padding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Align(alignment: Alignment.topRight, child: _buildPip(pipSize)),
              Align(alignment: Alignment.bottomLeft, child: _buildPip(pipSize)),
            ],
          ),
        );
      case 3:
        return Padding(
          padding: EdgeInsets.all(padding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Align(alignment: Alignment.topRight, child: _buildPip(pipSize)),
              Center(child: _buildPip(pipSize)),
              Align(alignment: Alignment.bottomLeft, child: _buildPip(pipSize)),
            ],
          ),
        );
      case 4:
        return Padding(
          padding: EdgeInsets.all(padding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildPip(pipSize),
                  _buildPip(pipSize),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildPip(pipSize),
                  _buildPip(pipSize),
                ],
              ),
            ],
          ),
        );
      case 5:
        return Padding(
          padding: EdgeInsets.all(padding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildPip(pipSize),
                  _buildPip(pipSize),
                ],
              ),
              Center(child: _buildPip(pipSize)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildPip(pipSize),
                  _buildPip(pipSize),
                ],
              ),
            ],
          ),
        );
      case 6:
        return Padding(
          padding: EdgeInsets.all(padding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildPip(pipSize),
                  _buildPip(pipSize),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildPip(pipSize),
                  _buildPip(pipSize),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildPip(pipSize),
                  _buildPip(pipSize),
                ],
              ),
            ],
          ),
        );
      default:
        return Center(
          child: Text(
            '$faceValue',
            style: TextStyle(
              fontSize: faceSize * 0.4,
              fontWeight: FontWeight.bold,
              color: widget.pipColor,
            ),
          ),
        );
    }
  }

  Widget _buildPip(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: widget.pipColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 2,
            offset: const Offset(0.5, 0.5),
          ),
        ],
      ),
    );
  }
}

// Custom painter to draw the face images
class DiceFaceImagePainter extends CustomPainter {
  final ui.Image image;

  DiceFaceImagePainter(this.image);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint();
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(0, 0, size.width, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Example of a themed dice
class ThemedDice3DRoller extends StatelessWidget {
  final String theme;
  final double size;
  final VoidCallback? onRollComplete;

  const ThemedDice3DRoller({
    Key? key,
    required this.theme,
    this.size = 150,
    this.onRollComplete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Different themes have different colors and use custom faces
    switch (theme.toLowerCase()) {
      case 'casino':
        return Dice3DRoller(
          size: size,
          diceColor: const Color(0xFFAA0000),
          pipColor: Colors.white,
          useCustomFaces: true,
          onRollComplete: onRollComplete,
        );
      case 'neon':
        return Dice3DRoller(
          size: size,
          diceColor: Colors.black,
          pipColor: const Color(0xFF00FFFF),
          useCustomFaces: true,
          onRollComplete: onRollComplete,
        );
      case 'gold':
        return Dice3DRoller(
          size: size,
          diceColor: const Color(0xFFDAA520),
          pipColor: const Color(0xFF8B4513),
          useCustomFaces: true,
          onRollComplete: onRollComplete,
        );
      case 'wooden':
        return Dice3DRoller(
          size: size,
          diceColor: const Color(0xFF8B4513),
          pipColor: Colors.white,
          useCustomFaces: true,
          onRollComplete: onRollComplete,
        );
      default:
        return Dice3DRoller(
          size: size,
          onRollComplete: onRollComplete,
        );
    }
  }
}

// Example usage:
class Dice3DRollerDemo extends StatelessWidget {
  const Dice3DRollerDemo({Key? key}) : super(key: key);

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
            // Standard dice with sound effects
            Dice3DRoller(
              size: 150,
              diceColor: Colors.white,
              pipColor: Colors.black,
              playSounds: true,
              onRollComplete: () {
                debugPrint('Dice roll completed!');
              },
            ),
            const SizedBox(height: 30),
            // Themed dice examples
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                ThemedDice3DRoller(theme: 'casino', size: 90),
                SizedBox(width: 20),
                ThemedDice3DRoller(theme: 'wooden', size: 90),
              ],
            ),
          ],
        ),
      ),
    );
  }
}