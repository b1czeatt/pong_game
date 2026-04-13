import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const PongApp());
}

enum Difficulty { easy, normal, hard }

extension DifficultyX on Difficulty {
  String get label {
    switch (this) {
      case Difficulty.easy:
        return 'Easy';
      case Difficulty.normal:
        return 'Normal';
      case Difficulty.hard:
        return 'Hard';
    }
  }

  String get description {
    switch (this) {
      case Difficulty.easy:
        return 'A slower AI and calmer ball speed.';
      case Difficulty.normal:
        return 'Balanced for the standard Pong experience.';
      case Difficulty.hard:
        return 'Sharper AI reactions and faster rallies.';
    }
  }

  double get aiSpeed {
    switch (this) {
      case Difficulty.easy:
        return 300;
      case Difficulty.normal:
        return 360;
      case Difficulty.hard:
        return 460;
    }
  }

  double get serveSpeed {
    switch (this) {
      case Difficulty.easy:
        return 250;
      case Difficulty.normal:
        return 305;
      case Difficulty.hard:
        return 345;
    }
  }

  double get maxBallSpeed {
    switch (this) {
      case Difficulty.easy:
        return 720;
      case Difficulty.normal:
        return 780;
      case Difficulty.hard:
        return 860;
    }
  }
}

enum MatchWinner { player, ai }

class MatchResult {
  MatchResult({
    required this.playerScore,
    required this.aiScore,
    required this.winner,
    DateTime? playedAt,
  }) : playedAt = playedAt ?? DateTime.now();

  final int playerScore;
  final int aiScore;
  final MatchWinner winner;
  final DateTime playedAt;

  bool get playerWon => winner == MatchWinner.player;
}

class PongApp extends StatelessWidget {
  const PongApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6CE0FF),
          secondary: Color(0xFFFFAD6C),
          surface: Color(0xFF10192D),
        ),
      ),
      home: const PongShell(),
    );
  }
}

class PongShell extends StatefulWidget {
  const PongShell({super.key});

  @override
  State<PongShell> createState() => _PongShellState();
}

class _PongShellState extends State<PongShell> {
  static const int _historyLimit = 8;

  int _currentIndex = 0;
  Difficulty _difficulty = Difficulty.normal;
  final List<MatchResult> _recentMatches = <MatchResult>[];

  int _playerWins = 0;
  int _aiWins = 0;

  int get _matchesPlayed => _playerWins + _aiWins;

  void _setDifficulty(Difficulty difficulty) {
    setState(() {
      _difficulty = difficulty;
    });
  }

  void _recordMatch(MatchResult result) {
    setState(() {
      if (result.playerWon) {
        _playerWins++;
      } else {
        _aiWins++;
      }
      _recentMatches.insert(0, result);
      if (_recentMatches.length > _historyLimit) {
        _recentMatches.removeLast();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = _currentIndex == 0 ? 'Flutter Pong' : 'Statistics & Settings';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        centerTitle: false,
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: <Widget>[
          PongScreen(
            difficulty: _difficulty,
            onMatchFinished: _recordMatch,
            isVisible: _currentIndex == 0,
          ),
          StatisticsPage(
            difficulty: _difficulty,
            matchesPlayed: _matchesPlayed,
            playerWins: _playerWins,
            aiWins: _aiWins,
            recentMatches: _recentMatches,
            onDifficultyChanged: _setDifficulty,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.sports_esports_outlined),
            selectedIcon: Icon(Icons.sports_esports),
            label: 'Play',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Stats',
          ),
        ],
      ),
    );
  }
}

class PongScreen extends StatefulWidget {
  const PongScreen({
    super.key,
    required this.difficulty,
    required this.onMatchFinished,
    required this.isVisible,
  });

  final Difficulty difficulty;
  final ValueChanged<MatchResult> onMatchFinished;
  final bool isVisible;

  @override
  State<PongScreen> createState() => _PongScreenState();
}

class _PongScreenState extends State<PongScreen>
    with SingleTickerProviderStateMixin {
  static const double virtualWidth = 900;
  static const double virtualHeight = 540;
  static const double paddleWidth = 14;
  static const double paddleHeight = 100;
  static const int maxScore = 7;

  final FocusNode _focusNode = FocusNode();
  final Set<LogicalKeyboardKey> _pressedKeys = <LogicalKeyboardKey>{};
  final Random _random = Random();

  late final Ticker _ticker;
  Duration _lastTime = Duration.zero;

  late Paddle _leftPaddle;
  late Paddle _rightPaddle;
  late Ball _ball;

  bool _paused = false;
  bool _gameOver = false;
  bool _matchReported = false;
  int _leftScore = 0;
  int _rightScore = 0;

  @override
  void initState() {
    super.initState();
    _initMatch();
    _ticker = createTicker(_tick)..start();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void didUpdateWidget(covariant PongScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.difficulty != widget.difficulty) {
      _rightPaddle.speed = widget.difficulty.aiSpeed;
    }
  }

  void _initMatch() {
    _leftPaddle = Paddle(
      x: 24,
      y: (virtualHeight - paddleHeight) / 2,
      width: paddleWidth,
      height: paddleHeight,
      speed: 420,
    );
    _rightPaddle = Paddle(
      x: virtualWidth - paddleWidth - 24,
      y: (virtualHeight - paddleHeight) / 2,
      width: paddleWidth,
      height: paddleHeight,
      speed: widget.difficulty.aiSpeed,
    );
    _ball = Ball(
      x: virtualWidth / 2,
      y: virtualHeight / 2,
      radius: 9,
      speedX: 320,
      speedY: 200,
    );
  }

  void _tick(Duration elapsed) {
    if (_lastTime == Duration.zero) {
      _lastTime = elapsed;
      return;
    }

    final dt = ((elapsed - _lastTime).inMicroseconds / 1000000).clamp(0.0, 0.05);
    _lastTime = elapsed;

    if (widget.isVisible && !_paused && !_gameOver) {
      _update(dt);
    }

    setState(() {});
  }

  KeyEventResult _onKeyEvent(KeyEvent event) {
    final key = event.logicalKey;

    if (event is KeyDownEvent) {
      _pressedKeys.add(key);
      if (key == LogicalKeyboardKey.keyP) {
        _paused = !_paused;
      }
      if (key == LogicalKeyboardKey.keyR) {
        _resetMatch();
      }
    }
    if (event is KeyUpEvent) {
      _pressedKeys.remove(key);
    }

    return KeyEventResult.handled;
  }

  void _update(double dt) {
    final moveUp = _pressedKeys.contains(LogicalKeyboardKey.keyW) ||
        _pressedKeys.contains(LogicalKeyboardKey.arrowUp);
    final moveDown = _pressedKeys.contains(LogicalKeyboardKey.keyS) ||
        _pressedKeys.contains(LogicalKeyboardKey.arrowDown);

    if (moveUp) {
      _leftPaddle.y -= _leftPaddle.speed * dt;
    }
    if (moveDown) {
      _leftPaddle.y += _leftPaddle.speed * dt;
    }
    _leftPaddle.y = _leftPaddle.y.clamp(0, virtualHeight - _leftPaddle.height);

    final aiCenter = _rightPaddle.y + _rightPaddle.height / 2;
    final aiTarget = _ball.y;
    if (aiCenter < aiTarget - 12) {
      _rightPaddle.y += widget.difficulty.aiSpeed * dt;
    } else if (aiCenter > aiTarget + 12) {
      _rightPaddle.y -= widget.difficulty.aiSpeed * dt;
    }
    _rightPaddle.y = _rightPaddle.y.clamp(0, virtualHeight - _rightPaddle.height);

    _ball.x += _ball.speedX * dt;
    _ball.y += _ball.speedY * dt;

    if (_ball.y - _ball.radius <= 0 || _ball.y + _ball.radius >= virtualHeight) {
      _ball.speedY *= -1;
      _ball.y = _ball.y.clamp(_ball.radius, virtualHeight - _ball.radius);
    }

    if (_hitsPaddle(_leftPaddle) && _ball.speedX < 0) {
      _bounceFromPaddle(_leftPaddle);
    }
    if (_hitsPaddle(_rightPaddle) && _ball.speedX > 0) {
      _bounceFromPaddle(_rightPaddle);
    }

    if (_ball.x + _ball.radius < 0) {
      _rightScore++;
      _checkGameOver();
      _resetBall(direction: 1);
    }
    if (_ball.x - _ball.radius > virtualWidth) {
      _leftScore++;
      _checkGameOver();
      _resetBall(direction: -1);
    }
  }

  bool _hitsPaddle(Paddle paddle) {
    return _ball.x + _ball.radius > paddle.x &&
        _ball.x - _ball.radius < paddle.x + paddle.width &&
        _ball.y + _ball.radius > paddle.y &&
        _ball.y - _ball.radius < paddle.y + paddle.height;
  }

  void _bounceFromPaddle(Paddle paddle) {
    final hitPoint = (_ball.y - (paddle.y + paddle.height / 2)) / (paddle.height / 2);
    final clamped = hitPoint.clamp(-1, 1);
    final maxAngle = pi / 3;
    final angle = clamped * maxAngle;

    final speed = min(widget.difficulty.maxBallSpeed, sqrt(_ball.speedX * _ball.speedX + _ball.speedY * _ball.speedY) + 22);
    final direction = _ball.speedX > 0 ? -1 : 1;
    _ball.speedX = direction * speed * cos(angle);
    _ball.speedY = speed * sin(angle);

    if (direction > 0) {
      _ball.x = paddle.x + paddle.width + _ball.radius;
    } else {
      _ball.x = paddle.x - _ball.radius;
    }
  }

  void _checkGameOver() {
    if (_leftScore >= maxScore || _rightScore >= maxScore) {
      _gameOver = true;
      if (!_matchReported) {
        _matchReported = true;
        widget.onMatchFinished(
          MatchResult(
            playerScore: _leftScore,
            aiScore: _rightScore,
            winner: _leftScore > _rightScore ? MatchWinner.player : MatchWinner.ai,
          ),
        );
      }
    }
  }

  void _resetBall({required int direction}) {
    _ball.x = virtualWidth / 2;
    _ball.y = virtualHeight / 2;

    if (!_gameOver) {
      final randomVertical = (_random.nextDouble() * 2 - 1) * 190;
      _ball.speedX = direction * (widget.difficulty.serveSpeed + _random.nextDouble() * 40);
      _ball.speedY = randomVertical;
    } else {
      _ball.speedX = 0;
      _ball.speedY = 0;
    }
  }

  void _resetMatch() {
    _leftScore = 0;
    _rightScore = 0;
    _gameOver = false;
    _paused = false;
    _matchReported = false;

    _leftPaddle.y = (virtualHeight - _leftPaddle.height) / 2;
    _rightPaddle.y = (virtualHeight - _rightPaddle.height) / 2;
    _rightPaddle.speed = widget.difficulty.aiSpeed;

    final firstDirection = _random.nextBool() ? 1 : -1;
    _resetBall(direction: firstDirection);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final winnerText = _leftScore > _rightScore ? 'PLAYER WINS' : 'AI WINS';

    return TickerMode(
      enabled: widget.isVisible,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[Color(0xFF0B1020), Color(0xFF1A2B4F)],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: Focus(
                focusNode: _focusNode,
                onKeyEvent: (_, event) => _onKeyEvent(event),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Text(
                        'Flutter Pong',
                        style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Move: W/S or Arrow Up/Down   Pause: P   Restart: R   Difficulty: ${widget.difficulty.label}',
                        style: const TextStyle(color: Color(0xFFD1DDFF)),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      AspectRatio(
                        aspectRatio: virtualWidth / virtualHeight,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CustomPaint(
                            painter: PongPainter(
                              leftPaddle: _leftPaddle,
                              rightPaddle: _rightPaddle,
                              ball: _ball,
                              leftScore: _leftScore,
                              rightScore: _rightScore,
                              maxScore: maxScore,
                              paused: _paused,
                              gameOver: _gameOver,
                              winnerText: winnerText,
                              difficultyLabel: widget.difficulty.label,
                              virtualWidth: virtualWidth,
                              virtualHeight: virtualHeight,
                            ),
                            child: const SizedBox.expand(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PongPainter extends CustomPainter {
  PongPainter({
    required this.leftPaddle,
    required this.rightPaddle,
    required this.ball,
    required this.leftScore,
    required this.rightScore,
    required this.maxScore,
    required this.paused,
    required this.gameOver,
    required this.winnerText,
    required this.difficultyLabel,
    required this.virtualWidth,
    required this.virtualHeight,
  });

  final Paddle leftPaddle;
  final Paddle rightPaddle;
  final Ball ball;
  final int leftScore;
  final int rightScore;
  final int maxScore;
  final bool paused;
  final bool gameOver;
  final String winnerText;
  final String difficultyLabel;
  final double virtualWidth;
  final double virtualHeight;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / virtualWidth;
    final sy = size.height / virtualHeight;

    final background = Paint()..color = const Color(0xFF081020);
    canvas.drawRect(Offset.zero & size, background);

    final centerLinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..strokeWidth = 4 * sx;

    final centerX = size.width / 2;
    for (double y = 12 * sy; y < size.height; y += 28 * sy) {
      canvas.drawLine(Offset(centerX, y), Offset(centerX, y + 14 * sy), centerLinePaint);
    }

    final leftPaint = Paint()..color = const Color(0xFF6CE0FF);
    final rightPaint = Paint()..color = const Color(0xFFFFAD6C);
    canvas.drawRect(
      Rect.fromLTWH(
        leftPaddle.x * sx,
        leftPaddle.y * sy,
        leftPaddle.width * sx,
        leftPaddle.height * sy,
      ),
      leftPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        rightPaddle.x * sx,
        rightPaddle.y * sy,
        rightPaddle.width * sx,
        rightPaddle.height * sy,
      ),
      rightPaint,
    );

    final ballPaint = Paint()..color = const Color(0xFFF5F7FF);
    canvas.drawCircle(
      Offset(ball.x * sx, ball.y * sy),
      ball.radius * min(sx, sy),
      ballPaint,
    );

    final scoreStyle = TextStyle(
      color: Colors.white.withValues(alpha: 0.9),
      fontSize: 56 * min(sx, sy),
      fontWeight: FontWeight.bold,
    );
    _drawCenteredText(canvas, leftScore.toString(), scoreStyle, Offset(size.width * 0.25, 70 * sy));
    _drawCenteredText(canvas, rightScore.toString(), scoreStyle, Offset(size.width * 0.75, 70 * sy));

    _drawCenteredText(
      canvas,
      'First to $maxScore',
      TextStyle(
        color: const Color(0xFFD1DDFF).withValues(alpha: 0.85),
        fontSize: 14 * min(sx, sy),
        fontWeight: FontWeight.bold,
      ),
      Offset(size.width / 2, 26 * sy),
    );

    final difficultyStyle = TextStyle(
      color: const Color(0xFFD1DDFF).withValues(alpha: 0.75),
      fontSize: 12 * min(sx, sy),
      fontWeight: FontWeight.w600,
    );
    _drawCenteredText(canvas, 'Difficulty: $difficultyLabel', difficultyStyle, Offset(size.width * 0.84, 26 * sy));

    if (paused && !gameOver) {
      _drawOverlay(canvas, size, 'PAUSED', 'Press P to continue');
    }
    if (gameOver) {
      _drawOverlay(canvas, size, winnerText, 'Press R to restart');
    }
  }

  void _drawCenteredText(Canvas canvas, String text, TextStyle style, Offset center) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, Offset(center.dx - painter.width / 2, center.dy - painter.height / 2));
  }

  void _drawOverlay(Canvas canvas, Size size, String title, String subtitle) {
    final overlayPaint = Paint()..color = Colors.black.withValues(alpha: 0.6);
    canvas.drawRect(Offset.zero & size, overlayPaint);

    _drawCenteredText(
      canvas,
      title,
      TextStyle(
        color: Colors.white,
        fontSize: 52 * min(size.width / virtualWidth, size.height / virtualHeight),
        fontWeight: FontWeight.bold,
      ),
      Offset(size.width / 2, size.height / 2 - 18),
    );
    _drawCenteredText(
      canvas,
      subtitle,
      TextStyle(
        color: const Color(0xFFD9E2FF),
        fontSize: 20 * min(size.width / virtualWidth, size.height / virtualHeight),
        fontWeight: FontWeight.bold,
      ),
      Offset(size.width / 2, size.height / 2 + 30),
    );
  }

  @override
  bool shouldRepaint(covariant PongPainter oldDelegate) {
    return true;
  }
}

class StatisticsPage extends StatelessWidget {
  const StatisticsPage({
    super.key,
    required this.difficulty,
    required this.matchesPlayed,
    required this.playerWins,
    required this.aiWins,
    required this.recentMatches,
    required this.onDifficultyChanged,
  });

  final Difficulty difficulty;
  final int matchesPlayed;
  final int playerWins;
  final int aiWins;
  final List<MatchResult> recentMatches;
  final ValueChanged<Difficulty> onDifficultyChanged;

  @override
  Widget build(BuildContext context) {
    final winRate = matchesPlayed == 0 ? 0.0 : (playerWins / matchesPlayed) * 100.0;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF081021), Color(0xFF141E36)],
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Your match stats',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Track wins, losses, and tune the AI difficulty from here.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: const Color(0xFFD1DDFF)),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: <Widget>[
                      _StatCard(label: 'Matches played', value: matchesPlayed.toString(), icon: Icons.sports_esports),
                      _StatCard(label: 'Player wins', value: playerWins.toString(), icon: Icons.emoji_events),
                      _StatCard(label: 'AI wins', value: aiWins.toString(), icon: Icons.smart_toy),
                      _StatCard(label: 'Win rate', value: '${winRate.toStringAsFixed(0)}%', icon: Icons.percent),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Card(
                    color: const Color(0xFF101A31),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Difficulty level',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(difficulty.description, style: const TextStyle(color: Color(0xFFD1DDFF))),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<Difficulty>(
                            value: difficulty,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              labelText: 'Select difficulty',
                            ),
                            items: Difficulty.values
                                .map(
                                  (Difficulty option) => DropdownMenuItem<Difficulty>(
                                    value: option,
                                    child: Text(option.label),
                                  ),
                                )
                                .toList(),
                            onChanged: (Difficulty? value) {
                              if (value != null) {
                                onDifficultyChanged(value);
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Easy makes the AI slower. Normal is balanced. Hard reacts faster and serves the ball quicker.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF96A9D8)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Recent matches',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (recentMatches.isEmpty)
                    Card(
                      color: const Color(0xFF101A31),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'No finished matches yet. Play a round to build your stats.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    )
                  else
                    Column(
                      children: recentMatches
                          .map(
                            (MatchResult match) => Card(
                              color: const Color(0xFF101A31),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: match.playerWon ? const Color(0xFF6CE0FF) : const Color(0xFFFFAD6C),
                                  child: Icon(
                                    match.playerWon ? Icons.person : Icons.smart_toy,
                                    color: Colors.black,
                                  ),
                                ),
                                title: Text(match.playerWon ? 'Player win' : 'AI win'),
                                subtitle: Text(
                                  '${match.playerScore} - ${match.aiScore}   ${_formatMatchTime(match.playedAt)}',
                                ),
                                trailing: Text(
                                  match.playerWon ? '+1' : '-1',
                                  style: TextStyle(
                                    color: match.playerWon ? const Color(0xFF6CE0FF) : const Color(0xFFFFAD6C),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatMatchTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return 'Played at $hour:$minute';
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: Card(
        color: const Color(0xFF101A31),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                child: Icon(icon, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF96A9D8))),
                  const SizedBox(height: 4),
                  Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class Paddle {
  Paddle({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.speed,
  });

  double x;
  double y;
  final double width;
  final double height;
  double speed;
}

class Ball {
  Ball({
    required this.x,
    required this.y,
    required this.radius,
    required this.speedX,
    required this.speedY,
  });

  double x;
  double y;
  final double radius;
  double speedX;
  double speedY;
}
