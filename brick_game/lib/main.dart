import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'dart:ui';

void main() {
  runApp(const BrickGameApp());
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
}

class BrickGameApp extends StatelessWidget {
  const BrickGameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Advanced Brick Shooter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const GameScreen(),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  // Game state
  double _planeX = 0.5;
  double _planeY = 0.85;
  double _planeWidth = 0.12;
  double _planeHeight = 0.08;
  double _planeVelocity = 0.0;

  List<Bullet> _bullets = [];
  List<Brick> _bricks = [];
  List<PowerUp> _powerUps = [];
  List<Particle> _particles = [];

  int _score = 0;
  int _highScore = 0;
  int _lives = 3;
  bool _gameOver = false;
  bool _gameStarted = false;
  bool _isPaused = false;

  // Game settings
  double _brickBaseSpeed = 0.004;
  int _brickSpawnRate = 45;
  int _brickSpawnCounter = 0;
  int _powerUpChance = 15; // 1 in 15 chance

  // Power-up states
  bool _rapidFire = false;
  int _rapidFireTimer = 0;
  bool _shieldActive = false;
  int _shieldTimer = 0;

  Random _random = Random();
  DateTime _lastFrameTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    );

    _animation = Tween<double>(begin: 0, end: 1).animate(_controller)
      ..addListener(_gameLoop);

    _controller.repeat();
  }

  void _gameLoop() {
    if (!_gameStarted || _gameOver || _isPaused) return;

    final now = DateTime.now();
    final deltaTime = now.difference(_lastFrameTime).inMilliseconds / 16.0;
    _lastFrameTime = now;

    _updateGame(deltaTime);
    setState(() {});
  }

  void _updateGame(double deltaTime) {
    // Update plane position with momentum
    _planeX += _planeVelocity * deltaTime;
    _planeX = _planeX.clamp(0.0, 1.0 - _planeWidth);

    // Apply friction
    _planeVelocity *= 0.92;
    if (_planeVelocity.abs() < 0.001) _planeVelocity = 0.0;

    // Update bullets
    _bullets.removeWhere((bullet) {
      bullet.y -= bullet.speed * deltaTime;
      return bullet.y < -0.1;
    });

    // Update bricks
    _bricks.removeWhere((brick) {
      brick.y += brick.speed * deltaTime;
      return brick.y > 1.2;
    });

    // Update power-ups
    _powerUps.removeWhere((powerUp) {
      powerUp.y += powerUp.speed * deltaTime;
      if (powerUp.y > 1.2) return true;

      // Check power-up collection
      if (_checkCollision(
        _planeX, _planeY, _planeWidth, _planeHeight,
        powerUp.x, powerUp.y, powerUp.width, powerUp.height,
      )) {
        _activatePowerUp(powerUp.type);
        _addParticles(powerUp.x + powerUp.width/2, powerUp.y + powerUp.height/2,
            Colors.yellow, 15);
        return true;
      }
      return false;
    });

    // Update particles
    _particles.removeWhere((particle) {
      particle.x += particle.vx * deltaTime;
      particle.y += particle.vy * deltaTime;
      particle.lifetime--;
      return particle.lifetime <= 0;
    });

    // Spawn new bricks
    _brickSpawnCounter++;
    if (_brickSpawnCounter >= _brickSpawnRate) {
      _spawnBricks(1 + (_score ~/ 15));
      _brickSpawnCounter = 0;

      // Increase difficulty
      if (_score > 0 && _score % 10 == 0) {
        _brickBaseSpeed += 0.0005;
      }
    }

    // Update power-up timers
    if (_rapidFire) {
      _rapidFireTimer--;
      if (_rapidFireTimer <= 0) {
        _rapidFire = false;
      }
    }

    if (_shieldActive) {
      _shieldTimer--;
      if (_shieldTimer <= 0) {
        _shieldActive = false;
      }
    }

    // Check collisions
    _checkCollisions();
  }

  void _spawnBricks(int count) {
    for (int i = 0; i < count; i++) {
      final brickType = _random.nextInt(5);
      double width, height, speed;
      Color color;
      int hitPoints;

      switch (brickType) {
        case 0: // Small fast brick
          width = 0.08 + _random.nextDouble() * 0.04;
          height = 0.04 + _random.nextDouble() * 0.02;
          speed = _brickBaseSpeed * 1.5;
          color = Colors.red[400]!;
          hitPoints = 1;
          break;
        case 1: // Medium normal brick
          width = 0.12 + _random.nextDouble() * 0.06;
          height = 0.06 + _random.nextDouble() * 0.03;
          speed = _brickBaseSpeed;
          color = Colors.blue[400]!;
          hitPoints = 2;
          break;
        case 2: // Large slow brick
          width = 0.16 + _random.nextDouble() * 0.08;
          height = 0.08 + _random.nextDouble() * 0.04;
          speed = _brickBaseSpeed * 0.7;
          color = Colors.green[400]!;
          hitPoints = 3;
          break;
        default: // Standard brick
          width = 0.1 + _random.nextDouble() * 0.1;
          height = 0.05 + _random.nextDouble() * 0.05;
          speed = _brickBaseSpeed;
          color = Colors.primaries[_random.nextInt(Colors.primaries.length)];
          hitPoints = 1;
      }

      _bricks.add(Brick(
        x: _random.nextDouble() * (1.0 - width),
        y: -0.1 - _random.nextDouble() * 0.2,
        width: width,
        height: height,
        speed: speed,
        color: color,
        hitPoints: hitPoints,
      ));

      // Chance to spawn power-up with brick
      if (_random.nextInt(_powerUpChance) == 0) {
        _powerUps.add(PowerUp(
          x: _random.nextDouble() * 0.8 + 0.1,
          y: -0.1 - _random.nextDouble() * 0.2,
          width: 0.06,
          height: 0.06,
          speed: _brickBaseSpeed * 0.8,
          type: _random.nextInt(2) == 0 ? PowerUpType.rapidFire : PowerUpType.shield,
        ));
      }
    }
  }

  void _activatePowerUp(PowerUpType type) {
    switch (type) {
      case PowerUpType.rapidFire:
        _rapidFire = true;
        _rapidFireTimer = 300; // 5 seconds at 60fps
        break;
      case PowerUpType.shield:
        _shieldActive = true;
        _shieldTimer = 450; // 7.5 seconds at 60fps
        break;
    }
  }

  void _checkCollisions() {
    // Bullet-Brick collisions
    List<Bullet> bulletsToRemove = [];
    List<Brick> bricksToRemove = [];

    for (var bullet in _bullets) {
      for (var brick in _bricks) {
        if (_checkCollision(
          bullet.x, bullet.y, bullet.width, bullet.height,
          brick.x, brick.y, brick.width, brick.height,
        )) {
          bulletsToRemove.add(bullet);
          brick.hitPoints--;

          _addParticles(
            brick.x + brick.width/2,
            brick.y + brick.height/2,
            brick.color.withOpacity(0.7),
            8 + _random.nextInt(5),
          );

          if (brick.hitPoints <= 0) {
            bricksToRemove.add(brick);
            _score += (1 + (brick.width * 10).toInt());

            // Chance to spawn power-up when brick is destroyed
            if (_random.nextInt(_powerUpChance ~/ 2) == 0) {
              _powerUps.add(PowerUp(
                x: brick.x + brick.width/2 - 0.03,
                y: brick.y + brick.height/2 - 0.03,
                width: 0.06,
                height: 0.06,
                speed: _brickBaseSpeed * 0.8,
                type: _random.nextInt(2) == 0 ? PowerUpType.rapidFire : PowerUpType.shield,
              ));
            }
          }
          break;
        }
      }
    }

    _bullets.removeWhere((bullet) => bulletsToRemove.contains(bullet));
    _bricks.removeWhere((brick) => bricksToRemove.contains(brick));

    // Plane-Brick collisions
    if (!_shieldActive) {
      for (var brick in _bricks) {
        if (brick.y + brick.height > _planeY &&
            _checkCollision(
              _planeX, _planeY, _planeWidth, _planeHeight,
              brick.x, brick.y, brick.width, brick.height,
            )) {
          _addExplosion(brick.x + brick.width/2, brick.y + brick.height/2);
          _bricks.remove(brick);
          _lives -= 1;

          if (_lives <= 0) {
            _gameOver = true;
            if (_score > _highScore) {
              _highScore = _score;
            }
          }
          break;
        }
      }
    }
  }

  void _addExplosion(double x, double y) {
    _addParticles(x, y, Colors.orange, 25);
    _addParticles(x, y, Colors.red, 15);
  }

  void _addParticles(double x, double y, Color color, int count) {
    for (int i = 0; i < count; i++) {
      _particles.add(Particle(
        x: x,
        y: y,
        vx: (_random.nextDouble() - 0.5) * 0.02,
        vy: (_random.nextDouble() - 0.5) * 0.02,
        color: color.withOpacity(0.7 + _random.nextDouble() * 0.3),
        size: 2 + _random.nextDouble() * 4,
        lifetime: 20 + _random.nextInt(30),
      ));
    }
  }

  bool _checkCollision(double x1, double y1, double w1, double h1,
      double x2, double y2, double w2, double h2) {
    return x1 < x2 + w2 &&
        x1 + w1 > x2 &&
        y1 < y2 + h2 &&
        y1 + h1 > y2;
  }

  void _shoot() {
    if (!_gameOver && _gameStarted && !_isPaused) {
      final now = DateTime.now().millisecondsSinceEpoch;

      // Rapid fire allows shooting every 5 frames (12 bullets/sec)
      if (_rapidFire || _bullets.isEmpty || now - (_bullets.last.timestamp) > 150) {
        _bullets.add(Bullet(
          x: _planeX + _planeWidth / 2 - 0.01,
          y: _planeY,
          width: 0.02,
          height: 0.05,
          speed: 0.035,
          timestamp: now,
        ));

        // Add recoil effect
        _planeVelocity += _random.nextDouble() * 0.01 - 0.005;
      }
    }
  }

  void _moveLeft() {
    if (!_gameOver && _gameStarted && !_isPaused) {
      _planeVelocity -= 0.015;
    }
  }

  void _moveRight() {
    if (!_gameOver && _gameStarted && !_isPaused) {
      _planeVelocity += 0.015;
    }
  }

  void _startGame() {
    setState(() {
      _gameStarted = true;
      _gameOver = false;
      _isPaused = false;
      _score = 0;
      _lives = 3;
      _planeX = 0.5;
      _planeVelocity = 0.0;
      _bricks.clear();
      _bullets.clear();
      _powerUps.clear();
      _particles.clear();
      _brickBaseSpeed = 0.004;
      _rapidFire = false;
      _shieldActive = false;
      _spawnBricks(5);
      _lastFrameTime = DateTime.now();
    });
  }

  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
      if (!_isPaused) {
        _lastFrameTime = DateTime.now();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isPortrait = screenSize.height > screenSize.width;

    return Scaffold(
      body: GestureDetector(
        onTap: _shoot,
        onHorizontalDragUpdate: (details) {
          if (details.delta.dx < 0) {
            _moveLeft();
          } else if (details.delta.dx > 0) {
            _moveRight();
          }
        },
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF001133), Color(0xFF000000)],
            ),
          ),
          child: Stack(
            children: [
              // Starfield background
              _buildStarfield(screenSize),

              // Game elements
              ..._buildGameElements(screenSize),

              // UI Overlay
              _buildUIOverlay(),

              // Game messages
              if (!_gameStarted) _buildStartMessage(),
              if (_gameOver) _buildGameOverMessage(),
              if (_isPaused) _buildPauseMessage(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStarfield(Size size) {
    return CustomPaint(
      size: size,
      painter: StarfieldPainter(),
    );
  }

  List<Widget> _buildGameElements(Size size) {
    return [
      // Particles
      ..._particles.map((particle) => Positioned(
        left: particle.x * size.width,
        top: particle.y * size.height,
        child: Container(
          width: particle.size,
          height: particle.size,
          decoration: BoxDecoration(
            color: particle.color,
            shape: BoxShape.circle,
          ),
        ),
      )),

      // Power-ups
      ..._powerUps.map((powerUp) => Positioned(
        left: powerUp.x * size.width,
        top: powerUp.y * size.height,
        child: Container(
          width: powerUp.width * size.width,
          height: powerUp.height * size.height,
          decoration: BoxDecoration(
            color: powerUp.type == PowerUpType.rapidFire
                ? Colors.yellow.withOpacity(0.8)
                : Colors.blue.withOpacity(0.8),
            shape: BoxShape.circle,
            border: Border.all(
              color: powerUp.type == PowerUpType.rapidFire
                  ? Colors.orange
                  : Colors.lightBlue,
              width: 2,
            ),
          ),
          child: Center(
            child: Icon(
              powerUp.type == PowerUpType.rapidFire
                  ? Icons.bolt
                  : Icons.shield,
              color: Colors.white,
              size: powerUp.width * size.width * 0.7,
            ),
          ),
        ),
      )),

      // Bricks
      ..._bricks.map((brick) => Positioned(
        left: brick.x * size.width,
        top: brick.y * size.height,
        child: Container(
          width: brick.width * size.width,
          height: brick.height * size.height,
          decoration: BoxDecoration(
            color: brick.color,
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: brick.color.withOpacity(0.5),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
          ),
          child: brick.hitPoints > 1
              ? Center(
            child: Text(
              brick.hitPoints.toString(),
              style: TextStyle(
                color: Colors.white,
                fontSize: brick.width * size.width * 0.3,
                fontWeight: FontWeight.bold,
              ),
            ),
          )
              : null,
        ),
      )),

      // Bullets
      ..._bullets.map((bullet) => Positioned(
        left: bullet.x * size.width,
        top: bullet.y * size.height,
        child: Container(
          width: bullet.width * size.width,
          height: bullet.height * size.height,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Colors.yellow, Colors.orange],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      )),

      // Plane with shield effect
      Positioned(
        left: _planeX * size.width,
        top: _planeY * size.height,
        child: Stack(
          children: [
            Container(
              width: _planeWidth * size.width,
              height: _planeHeight * size.height,
              child: CustomPaint(
                painter: PlanePainter(),
              ),
            ),
            if (_shieldActive)
              Container(
                width: _planeWidth * size.width * 1.4,
                height: _planeHeight * size.height * 1.4,
                margin: EdgeInsets.all((_planeWidth * size.width * 0.2) *
                    (0.8 + 0.2 * sin(DateTime.now().millisecondsSinceEpoch / 200))),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blue.withOpacity(0.2),
                  border: Border.all(
                    color: Colors.lightBlue.withOpacity(
                        0.8 + 0.2 * sin(DateTime.now().millisecondsSinceEpoch / 150)),
                    width: 2,
                  ),
                ),
              ),
          ],
        ),
      ),
    ];
  }

  Widget _buildUIOverlay() {
    return Positioned(
      top: 30,
      left: 0,
      right: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Score: $_score',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    shadows: [
                    Shadow(
                    blurRadius: 4,
                    color: Colors.black,
                    offset: Offset(1, 1),
                    ),
                    ],
                  ),
                ),
                Text(
                  'High: $_highScore',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    shadows: [
                      Shadow(
                        blurRadius: 4,
                        color: Colors.black,
                        offset: Offset(1, 1),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            Row(
              children: [
                if (_rapidFire)
                  _buildPowerUpIndicator(Icons.bolt, Colors.yellow, _rapidFireTimer),
                if (_shieldActive)
                  _buildPowerUpIndicator(Icons.shield, Colors.blue, _shieldTimer),

                IconButton(
                  icon: Icon(
                    _isPaused ? Icons.play_arrow : Icons.pause,
                    color: Colors.white,
                    size: 30,
                  ),
                  onPressed: _togglePause,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPowerUpIndicator(IconData icon, Color color, int timer) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(
              value: timer / (icon == Icons.bolt ? 300 : 450),
              backgroundColor: color.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              strokeWidth: 3,
            ),
          ),
          Icon(
            icon,
            color: color,
            size: 18,
          ),
        ],
      ),
    );
  }

  Widget _buildStartMessage() {
    return Center(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'ADVANCED\nBRICK SHOOTER',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  shadows: [
                  Shadow(
                  blurRadius: 10,
                  color: Colors.blue,
                  offset: Offset(0, 0),
                  ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                'Swipe to move\nTap to shoot\n\nCollect power-ups:\n',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 20),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildPowerUpDescription(Icons.bolt, 'Rapid Fire', Colors.yellow),
                  const SizedBox(width: 20),
                  _buildPowerUpDescription(Icons.shield, 'Shield', Colors.blue),
                ],
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _startGame,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'START GAME',
                  style: TextStyle(fontSize: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPowerUpDescription(IconData icon, String text, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 30),
        const SizedBox(height: 5),
        Text(text, style: TextStyle(color: color, fontSize: 16)),
      ],
    );
  }

  Widget _buildGameOverMessage() {
    return Center(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'GAME OVER',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      blurRadius: 10,
                      color: Colors.black,
                      offset: Offset(0, 0),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Score: $_score',
                style: const TextStyle(color: Colors.white, fontSize: 30),
              ),
              if (_score == _highScore && _score > 0)
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text(
                    'NEW HIGH SCORE!',
                    style: TextStyle(
                      color: Colors.yellow,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _startGame,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'PLAY AGAIN',
                  style: TextStyle(fontSize: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPauseMessage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'PAUSED',
            style: TextStyle(
              color: Colors.white,
              fontSize: 40,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(
                  blurRadius: 10,
                  color: Colors.black,
                  offset: Offset(0, 0),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _togglePause,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'RESUME',
              style: TextStyle(fontSize: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class StarfieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    final random = Random(12345); // Fixed seed for consistent starfield

    // Draw stars
    for (int i = 0; i < 150; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final starSize = random.nextDouble() * 1.5;
      final opacity = 0.5 + random.nextDouble() * 0.5;

      canvas.drawCircle(
        Offset(x, y),
        starSize,
        paint..color = Colors.white.withOpacity(opacity),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class PlanePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width * 0.5, 0)
      ..lineTo(size.width * 0.7, size.height * 0.4)
      ..lineTo(size.width * 0.6, size.height * 0.4)
      ..lineTo(size.width * 0.6, size.height)
      ..lineTo(size.width * 0.4, size.height)
      ..lineTo(size.width * 0.4, size.height * 0.4)
      ..lineTo(size.width * 0.3, size.height * 0.4)
      ..close();

    canvas.drawPath(path, paint);

    // Cockpit
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.2),
      size.width * 0.1,
      paint..color = Colors.lightBlue,
    );

    // Engine details
    paint.color = Colors.blue[900]!;
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.45, size.height * 0.7, size.width * 0.1, size.height * 0.2),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class Bullet {
  double x;
  double y;
  double width;
  double height;
  double speed;
  int timestamp;

  Bullet({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.speed,
    required this.timestamp,
  });
}

class Brick {
  double x;
  double y;
  double width;
  double height;
  double speed;
  Color color;
  int hitPoints;

  Brick({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.speed,
    required this.color,
    this.hitPoints = 1,
  });
}

enum PowerUpType { rapidFire, shield }

class PowerUp {
  double x;
  double y;
  double width;
  double height;
  double speed;
  PowerUpType type;

  PowerUp({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.speed,
    required this.type,
  });
}

class Particle {
  double x;
  double y;
  double vx;
  double vy;
  Color color;
  double size;
  int lifetime;

  Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.color,
    required this.size,
    required this.lifetime,
  });
}