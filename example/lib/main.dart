import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:audify/audify.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audioplayers/audioplayers.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Audify',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        primaryColor: const Color(0xFF6C63FF),
        scaffoldBackgroundColor: const Color(0xFF0A0E27),
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF6C63FF),
          secondary: const Color(0xFFFF6584),
          surface: const Color(0xFF1A1F3A),
          surfaceContainerHighest: const Color(0xFF2A2F4A),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1A1F3A),
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          ),
        ),
      ),
      home: const AudifyDemo(),
    );
  }
}

class AudifyDemo extends StatefulWidget {
  const AudifyDemo({super.key});

  @override
  State<AudifyDemo> createState() => _AudifyDemoState();
}

class _AudifyDemoState extends State<AudifyDemo> {
  late AudifyController _controller;
  late AudioPlayer _audioPlayer;
  bool _isInitialized = false;
  bool _isCapturing = false;
  bool _isPlaying = false;
  String _statusMessage = 'Not initialized';
  int _selectedVisualizer = 0;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _controller = AudifyController();
    _audioPlayer = AudioPlayer();
    _setupAudioPlayer();
    _initializeVisualizer();
  }

  void _setupAudioPlayer() {
    // Listen to player state changes
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });

    // Listen to duration changes
    _audioPlayer.onDurationChanged.listen((duration) {
      if (mounted) {
        setState(() {
          _duration = duration;
        });
      }
    });

    // Listen to position changes
    _audioPlayer.onPositionChanged.listen((position) {
      if (mounted) {
        setState(() {
          _position = position;
        });
      }
    });

    // Listen to completion
    _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() {
          _position = Duration.zero;
          _isPlaying = false;
        });
      }
    });
  }

  Future<void> _initializeVisualizer() async {
    try {
      setState(() {
        _statusMessage = 'Checking permissions...';
      });

      // Request RECORD_AUDIO permission (required for Android Visualizer API)
      final status = await Permission.microphone.request();

      if (!status.isGranted) {
        setState(() {
          _statusMessage = 'Microphone permission denied';
        });
        return;
      }

      setState(() {
        _statusMessage = 'Initializing...';
      });

      await _controller.initialize(
        audioSessionId: 0, // 0 for system audio
        captureSize: 2048,
      );

      setState(() {
        _isInitialized = true;
        _statusMessage = 'Initialized';
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing visualizer: $e');
      }

      setState(() {
        _statusMessage = 'Error: $e';
      });
    }
  }

  Future<void> _playMusic() async {
    try {
      await _audioPlayer.play(AssetSource('musics/music.mp3'));

      // Auto-start capture when music plays
      if (_isInitialized && !_isCapturing) {
        await _controller.startCapture();
        setState(() {
          _isCapturing = true;
          _statusMessage = 'Playing music & visualizing...';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error playing music: $e';
      });
    }
  }

  Future<void> _pauseMusic() async {
    await _audioPlayer.pause();
  }

  Future<void> _resumeMusic() async {
    await _audioPlayer.resume();
  }

  Future<void> _stopMusic() async {
    await _audioPlayer.stop();
    setState(() {
      _position = Duration.zero;
    });
  }

  Future<void> _seekTo(Duration position) async {
    await _audioPlayer.seek(position);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _controller.dispose();
    super.dispose();
  }

  Widget _buildVisualizer() {
    if (!_isInitialized) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Initializing visualizer...'),
          ],
        ),
      );
    }

    switch (_selectedVisualizer) {
      case 0:
        return Center(
          child: SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: CircularSpectrumVisualizer(
              controller: _controller,
              color: Colors.purpleAccent,
              glowColor: Colors.purple.withValues(alpha: 0.6),
              barCount: 40,
              barWidth: 3.0,
              gap: 2,
              smoothing: 0.7,
              // Example: Add album artwork in the center
              // centerImage: const AssetImage('assets/album_art.png'),
              // Or use NetworkImage for online images:
              // centerImage: const NetworkImage('https://example.com/album.jpg'),
            ),
          ),
        );
      case 1:
        return Center(
          child: SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: BarSpectrumVisualizer(
              controller: _controller,
              color: Colors.purpleAccent,
              glowColor: Colors.purple.withValues(alpha: 0.6),
              barCount: 32,
              barWidth: 4,
              gap: 6,
              smoothing: 0.75,
              mirror: false,
            ),
          ),
        );
      default:
        return const Center(child: Text('Unknown visualizer'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF0A0E27),
              const Color(0xFF1A1F3A),
              const Color(0xFF0A0E27),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header with status
              _buildHeader(),

              const SizedBox(height: 16),

              // Visualizer selector
              _buildVisualizerSelector(),

              const SizedBox(height: 20),

              // Main visualizer area
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0xFF6C63FF).withValues(alpha: 0.2),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
                        blurRadius: 20,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: _buildVisualizer(),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Music Player Card
              _buildMusicPlayerCard(),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Audify Demo',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  foreground: Paint()
                    ..shader = const LinearGradient(
                      colors: [Color(0xFF6C63FF), Color(0xFFFF6584)],
                    ).createShader(const Rect.fromLTWH(0, 0, 200, 70)),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _statusMessage,
                style: TextStyle(
                  color: _isCapturing
                      ? const Color(0xFF4CAF50)
                      : Colors.white60,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (!_isInitialized) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _initializeVisualizer,
              icon: const Icon(Icons.play_arrow_rounded, size: 20),
              label: const Text('Start Visualizer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVisualizerSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F3A).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildVisualizerButton('Circular', 0, Icons.album_rounded),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildVisualizerButton('Bars', 1, Icons.bar_chart_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildVisualizerButton(String label, int index, IconData icon) {
    final isSelected = _selectedVisualizer == index;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedVisualizer = index;
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? const LinearGradient(
                      colors: [Color(0xFF6C63FF), Color(0xFF5A52D5)],
                    )
                  : null,
              color: isSelected ? null : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: const Color(0xFF6C63FF).withValues(alpha: 0.4),
                        blurRadius: 12,
                        spreadRadius: 0,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: isSelected ? Colors.white : Colors.white54,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white54,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMusicPlayerCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [const Color(0xFF1A1F3A), const Color(0xFF2A2F4A)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Now Playing Info
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFFFF6584)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.music_note_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'music.mp3',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isPlaying ? 'Playing...' : 'Paused',
                      style: TextStyle(color: Colors.white60, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Progress bar
          Column(
            children: [
              SliderTheme(
                data: SliderThemeData(
                  trackHeight: 4,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 6,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 16,
                  ),
                  activeTrackColor: const Color(0xFF6C63FF),
                  inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
                  thumbColor: const Color(0xFF6C63FF),
                  overlayColor: const Color(0xFF6C63FF).withValues(alpha: 0.2),
                ),
                child: Slider(
                  value: _position.inSeconds.toDouble(),
                  max: _duration.inSeconds.toDouble().clamp(
                    1.0,
                    double.infinity,
                  ),
                  onChanged: (value) {
                    _seekTo(Duration(seconds: value.toInt()));
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(_position),
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      _formatDuration(_duration),
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Playback controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildControlButton(
                icon: Icons.stop_rounded,
                onPressed: _stopMusic,
                size: 44,
                isSecondary: true,
              ),
              const SizedBox(width: 20),
              _buildControlButton(
                icon: _isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                onPressed: () {
                  if (_isPlaying) {
                    _pauseMusic();
                  } else if (_position.inSeconds > 0) {
                    _resumeMusic();
                  } else {
                    _playMusic();
                  }
                },
                size: 72,
                isPrimary: true,
              ),
              const SizedBox(width: 20),
              _buildControlButton(
                icon: Icons.forward_10_rounded,
                onPressed: _isPlaying || _position.inSeconds > 0
                    ? () => _seekTo(_position + const Duration(seconds: 10))
                    : null,
                size: 44,
                isSecondary: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required double size,
    bool isPrimary = false,
    bool isSecondary = false,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: isPrimary
            ? const LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFF5A52D5)],
              )
            : null,
        color: isSecondary ? Colors.white.withValues(alpha: 0.1) : null,
        shape: BoxShape.circle,
        boxShadow: isPrimary
            ? [
                BoxShadow(
                  color: const Color(0xFF6C63FF).withValues(alpha: 0.4),
                  blurRadius: 16,
                  spreadRadius: 0,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(size / 2),
          child: Icon(
            icon,
            color: onPressed != null ? Colors.white : Colors.white38,
            size: isPrimary ? size * 0.5 : size * 0.45,
          ),
        ),
      ),
    );
  }
}
