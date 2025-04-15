import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:async';

class AudioMessageWidget extends StatefulWidget {
  final String mediaUrl;
  final Color textColor;
  final Color linkColor;

  const AudioMessageWidget({
    Key? key,
    required this.mediaUrl,
    required this.textColor,
    required this.linkColor,
  }) : super(key: key);

  @override
  _AudioMessageWidgetState createState() => _AudioMessageWidgetState();
}

class _AudioMessageWidgetState extends State<AudioMessageWidget> {
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;

  @override
  void initState() {
    super.initState();
    _initAudioPlayer();
  }

  void _initAudioPlayer() {
    _audioPlayer = AudioPlayer();
    _loadAudio();

    // Listen to player state changes
    _playerStateSubscription = _audioPlayer.playerStateStream.listen((state) {
      if (state.playing != _isPlaying) {
        setState(() {
          _isPlaying = state.playing;
        });
      }
    });

    // Listen to position changes
    _positionSubscription = _audioPlayer.positionStream.listen((position) {
      setState(() {
        _position = position;
      });
    });

    // Listen to duration changes
    _durationSubscription = _audioPlayer.durationStream.listen((duration) {
      if (duration != null) {
        setState(() {
          _duration = duration;
        });
      }
    });
  }

  Future<void> _loadAudio() async {
    try {
      await _audioPlayer.setUrl(widget.mediaUrl);
    } catch (e) {
      print("Error loading audio: $e");
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
    }
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  void dispose() {
    _playerStateSubscription?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[200],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Play/Pause button
          IconButton(
            icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
            onPressed: () {
              if (_isPlaying) {
                _audioPlayer.pause();
              } else {
                _audioPlayer.play();
              }
            },
            color: widget.linkColor,
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(),
            iconSize: 28,
          ),
          
          SizedBox(width: 8),
          
          // Audio progress bar
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Audio progress bar
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 4,
                    thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
                  ),
                  child: Slider(
                    value: _position.inMilliseconds.toDouble(),
                    min: 0.0,
                    max: _duration.inMilliseconds.toDouble() == 0 
                        ? 1.0 // Prevent division by zero
                        : _duration.inMilliseconds.toDouble(),
                    activeColor: widget.linkColor,
                    inactiveColor: Colors.grey[400],
                    onChanged: (value) {
                      _audioPlayer.seek(Duration(milliseconds: value.toInt()));
                    },
                  ),
                ),
                
                // Duration text
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(_position),
                      style: TextStyle(
                        fontSize: 12,
                        color: widget.textColor,
                      ),
                    ),
                    Text(
                      _formatDuration(_duration),
                      style: TextStyle(
                        fontSize: 12,
                        color: widget.textColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          SizedBox(width: 8),
          
          // Microphone icon (similar to WhatsApp)
          Icon(
            Icons.mic,
            size: 18,
            color: widget.textColor.withOpacity(0.7),
          ),
        ],
      ),
    );
  }
}