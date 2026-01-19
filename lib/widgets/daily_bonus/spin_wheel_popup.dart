import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../models/wheel_prize.dart';
import '../../providers/auth_provider.dart';
import 'coin_rain.dart';
import 'spin_wheel.dart';
import 'wheel_lights.dart';
import 'wheel_pointer.dart';

/// Premium modal popup for the daily bonus spin wheel - Blue Aura Theme
class SpinWheelPopup extends StatefulWidget {
  const SpinWheelPopup({super.key});

  /// Show the spin wheel popup as a dialog
  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.92),
      builder: (context) => const SpinWheelPopup(),
    );
  }

  @override
  State<SpinWheelPopup> createState() => _SpinWheelPopupState();
}

class _SpinWheelPopupState extends State<SpinWheelPopup>
    with TickerProviderStateMixin {
  final GlobalKey<SpinWheelState> _wheelKey = GlobalKey();
  late ConfettiController _confettiController;
  late AnimationController _pointerBounceController;
  late Animation<double> _pointerBounceAnimation;
  late AnimationController _prizeRevealController;
  late Animation<double> _prizeScaleAnimation;
  late AnimationController _screenShakeController;
  late Animation<Offset> _screenShakeAnimation;
  late AnimationController _glowPulseController;

  WheelPrize? _selectedPrize;
  bool _hasSpun = false;
  bool _isSpinning = false;
  bool _showPrizeReveal = false;
  bool _playingCoinRain = false;

  @override
  void initState() {
    super.initState();

    _confettiController = ConfettiController(
      duration: const Duration(seconds: 4),
    );

    // Multi-bounce pointer animation with physics
    _pointerBounceController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _pointerBounceAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.5)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.5, end: 0.95)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.95, end: 1.25)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.25, end: 0.98)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.98, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 20,
      ),
    ]).animate(_pointerBounceController);

    // Screen shake for impact
    _screenShakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _screenShakeAnimation = TweenSequence<Offset>([
      TweenSequenceItem(tween: Tween(begin: Offset.zero, end: const Offset(-8, 4)), weight: 1),
      TweenSequenceItem(tween: Tween(begin: const Offset(-8, 4), end: const Offset(8, -4)), weight: 1),
      TweenSequenceItem(tween: Tween(begin: const Offset(8, -4), end: const Offset(-6, 3)), weight: 1),
      TweenSequenceItem(tween: Tween(begin: const Offset(-6, 3), end: const Offset(6, -3)), weight: 1),
      TweenSequenceItem(tween: Tween(begin: const Offset(6, -3), end: const Offset(-4, 2)), weight: 1),
      TweenSequenceItem(tween: Tween(begin: const Offset(-4, 2), end: const Offset(4, -2)), weight: 1),
      TweenSequenceItem(tween: Tween(begin: const Offset(4, -2), end: const Offset(-2, 1)), weight: 1),
      TweenSequenceItem(tween: Tween(begin: const Offset(-2, 1), end: Offset.zero), weight: 1),
    ]).animate(CurvedAnimation(
      parent: _screenShakeController,
      curve: Curves.easeOut,
    ));

    _prizeRevealController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _prizeScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _prizeRevealController,
        curve: Curves.elasticOut,
      ),
    );

    // Glow pulse for idle state
    _glowPulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _pointerBounceController.dispose();
    _prizeRevealController.dispose();
    _screenShakeController.dispose();
    _glowPulseController.dispose();
    super.dispose();
  }

  void _startSpin() {
    if (_isSpinning || _hasSpun) return;

    // Determine prize BEFORE spinning
    _selectedPrize = SpinWheelConfig.selectPrize();
    final targetIndex = SpinWheelConfig.getSegmentIndex(_selectedPrize!);

    setState(() {
      _isSpinning = true;
      _hasSpun = true;
    });

    // Dramatic start haptic
    HapticFeedback.heavyImpact();

    // Start wheel spin
    _wheelKey.currentState?.startSpin(targetIndex);
  }

  void _onSpinComplete() {
    setState(() {
      _isSpinning = false;
      _showPrizeReveal = true;
    });

    // Screen shake on landing
    _screenShakeController.forward(from: 0);

    // Multi-bounce pointer
    _pointerBounceController.forward(from: 0);

    // Prize reveal after shake
    Future.delayed(const Duration(milliseconds: 150), () {
      _prizeRevealController.forward();
    });

    // Effects based on prize value
    if (_selectedPrize!.coins >= 1000 || _selectedPrize!.isJackpot) {
      // Big win - coin rain + confetti
      setState(() => _playingCoinRain = true);
      _confettiController.play();

      // Multiple haptic bursts for jackpot
      HapticFeedback.heavyImpact();
      Future.delayed(const Duration(milliseconds: 100), () => HapticFeedback.heavyImpact());
      Future.delayed(const Duration(milliseconds: 200), () => HapticFeedback.heavyImpact());
    } else if (_selectedPrize!.coins >= 500) {
      // Medium win - confetti
      _confettiController.play();
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.mediumImpact();
    }
  }

  Future<void> _collectPrize() async {
    if (_selectedPrize == null) return;

    final auth = context.read<AuthProvider>();

    // Double-check eligibility before claiming
    if (!(auth.user?.canClaimDailyBonus ?? false)) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Daily bonus already claimed!'),
            backgroundColor: AppColors.accentRed,
          ),
        );
      }
      return;
    }

    // Award coins
    await auth.claimDailyBonusWithAmount(_selectedPrize!.coins);

    if (mounted) {
      HapticFeedback.heavyImpact();
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Text('You won ', style: TextStyle(color: Colors.white)),
              const Icon(Icons.monetization_on, color: Color(0xFFFFD700), size: 20),
              Text(
                ' ${_selectedPrize!.coins} coins!',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.cardBackground,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    // Smaller wheel to fit everything without scrolling
    final wheelSize = (screenSize.width * 0.72).clamp(240.0, 300.0);

    return AnimatedBuilder(
      animation: _screenShakeAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: _screenShakeAnimation.value,
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(12),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                // Main content
                _buildMainContent(wheelSize, screenSize),

                // Confetti
                Positioned.fill(
                  child: IgnorePointer(
                    child: ConfettiWidget(
                      confettiController: _confettiController,
                      blastDirectionality: BlastDirectionality.explosive,
                      particleDrag: 0.03,
                      emissionFrequency: 0.03,
                      numberOfParticles: 30,
                      gravity: 0.15,
                      shouldLoop: false,
                      colors: const [
                        Color(0xFFFFD700), // Gold for coins
                        Color(0xFF00D4FF), // Cyan
                        Color(0xFF00A3FF), // Blue
                        Color(0xFF00FF7F), // Green
                        Colors.white,
                        Color(0xFF0066FF), // Primary blue
                        Color(0xFF7C3AED), // Purple
                      ],
                    ),
                  ),
                ),

                // Coin rain for big wins
                Positioned.fill(
                  child: CoinRain(
                    isPlaying: _playingCoinRain,
                    intensity: _selectedPrize?.isJackpot == true ? 3 : 2,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMainContent(double wheelSize, Size screenSize) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 420,
        maxHeight: screenSize.height * 0.88,
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1E3A5F), // Glass blue
              Color(0xFF0A1628), // Primary dark
            ],
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: const Color(0xFF00D4FF).withOpacity(0.6),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00D4FF).withOpacity(0.4),
              blurRadius: 50,
              spreadRadius: 10,
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.8),
              blurRadius: 40,
              offset: const Offset(0, 15),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: Stack(
            children: [
              // Animated gradient overlay
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _glowPulseController,
                  builder: (context, child) {
                    return Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment.topCenter,
                          radius: 1.5,
                          colors: [
                            const Color(0xFF00D4FF).withOpacity(0.08 + _glowPulseController.value * 0.04),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Content - no scroll needed, fits on screen
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(),
                  _buildWheelSection(wheelSize),
                  const SizedBox(height: 8),
                  _buildBottomSection(),
                  const SizedBox(height: 8),
                ],
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms)
        .scale(
          begin: const Offset(0.85, 0.85),
          end: const Offset(1, 1),
          duration: 400.ms,
          curve: Curves.easeOutBack,
        );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        children: [
          // Premium title with cyan glow
          Stack(
            children: [
              // Glow layer
              Text(
                'DAILY BONUS',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                  foreground: Paint()
                    ..color = const Color(0xFF00D4FF)
                    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
                ),
              ),
              // Main text with gradient
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [
                    Color(0xFF00D4FF), // Cyan
                    Color(0xFF00A3FF), // Blue
                    Color(0xFF0066FF), // Primary blue
                  ],
                  stops: [0.0, 0.5, 1.0],
                ).createShader(bounds),
                child: const Text(
                  'DAILY BONUS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                  ),
                ),
              ),
            ],
          )
              .animate(onPlay: (c) => c.repeat())
              .shimmer(
                duration: 2500.ms,
                color: Colors.white.withOpacity(0.4),
              ),
          const SizedBox(height: 6),
          Text(
            _showPrizeReveal ? 'CONGRATULATIONS!' : 'Spin to win free coins!',
            style: TextStyle(
              color: _showPrizeReveal
                  ? const Color(0xFF00FF7F)
                  : Colors.white.withOpacity(0.7),
              fontSize: 13,
              fontWeight: _showPrizeReveal ? FontWeight.bold : FontWeight.w500,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWheelSection(double wheelSize) {
    return SizedBox(
      height: wheelSize + 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Animated LED lights ring
          WheelLights(
            diameter: wheelSize + 28,
            isSpinning: _isSpinning,
            isPrizeRevealed: _showPrizeReveal,
          ),

          // The premium wheel
          SizedBox(
            width: wheelSize,
            height: wheelSize,
            child: SpinWheel(
              key: _wheelKey,
              targetSegmentIndex: _selectedPrize != null
                  ? SpinWheelConfig.getSegmentIndex(_selectedPrize!)
                  : null,
              onSpinComplete: _onSpinComplete,
            ),
          ),

          // Premium pointer with bounce animation
          Positioned(
            top: 4,
            child: AnimatedBuilder(
              animation: _pointerBounceAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pointerBounceAnimation.value,
                  alignment: Alignment.topCenter,
                  child: WheelPointer(
                    size: 36,
                    showGlow: _showPrizeReveal,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSection() {
    if (_showPrizeReveal && _selectedPrize != null) {
      return _buildPrizeReveal();
    }
    return _buildSpinButton();
  }

  Widget _buildSpinButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00D4FF).withOpacity(0.5),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: _isSpinning ? null : _startSpin,
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 0,
          ),
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _isSpinning
                    ? [
                        const Color(0xFF1E3A5F),
                        const Color(0xFF0A1628),
                      ]
                    : [
                        const Color(0xFF00D4FF),
                        const Color(0xFF00A3FF),
                        const Color(0xFF0066FF),
                      ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Container(
              alignment: Alignment.center,
              child: _isSpinning
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          'SPINNING...',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3,
                          ),
                        ),
                      ],
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.casino, size: 30, color: Colors.white),
                        SizedBox(width: 12),
                        Text(
                          'SPIN!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 4,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    )
        .animate(
          onPlay: (controller) => controller.repeat(reverse: true),
          autoPlay: !_hasSpun,
        )
        .scale(
          begin: const Offset(1, 1),
          end: const Offset(1.03, 1.03),
          duration: 1200.ms,
        );
  }

  Widget _buildPrizeReveal() {
    final isJackpot = _selectedPrize!.isJackpot;
    final isBigWin = _selectedPrize!.coins >= 1000;
    final isMediumWin = _selectedPrize!.coins >= 500;

    return AnimatedBuilder(
      animation: _prizeScaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _prizeScaleAnimation.value,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                // Prize card - compact
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    gradient: isJackpot
                        ? const LinearGradient(
                            colors: [Color(0xFFFFE135), Color(0xFFFFD700), Color(0xFFFFA500)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : LinearGradient(
                            colors: [
                              _selectedPrize!.color.withOpacity(0.3),
                              AppColors.cardBackground,
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isJackpot
                          ? Colors.white
                          : const Color(0xFF00D4FF).withOpacity(0.6),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (isJackpot ? const Color(0xFFFFD700) : const Color(0xFF00D4FF))
                            .withOpacity(0.5),
                        blurRadius: 20,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isJackpot || isBigWin || isMediumWin)
                        Text(
                          isJackpot ? 'JACKPOT! ' : (isBigWin ? 'BIG WIN! ' : 'NICE! '),
                          style: TextStyle(
                            color: isJackpot
                                ? const Color(0xFF1A1A1F)
                                : (isBigWin ? const Color(0xFF00FF7F) : const Color(0xFF00D4FF)),
                            fontSize: isJackpot ? 20 : 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                      Icon(
                        Icons.monetization_on,
                        color: isJackpot ? const Color(0xFF1A1A1F) : const Color(0xFFFFD700),
                        size: 32,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_selectedPrize!.coins}',
                        style: TextStyle(
                          color: isJackpot ? const Color(0xFF1A1A1F) : Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                )
                    .animate(onPlay: (c) => c.repeat(), delay: 300.ms)
                    .shimmer(duration: 2000.ms, color: Colors.white.withOpacity(0.25)),

                const SizedBox(height: 8),

                // Collect button - compact
                Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00FF7F).withOpacity(0.5),
                        blurRadius: 16,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _collectPrize,
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00FF7F), Color(0xFF00D68F)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Container(
                        alignment: Alignment.center,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle, size: 22, color: Color(0xFF1A1A1F)),
                            SizedBox(width: 8),
                            Text(
                              'COLLECT',
                              style: TextStyle(
                                color: Color(0xFF1A1A1F),
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
                    .animate(
                      onPlay: (c) => c.repeat(reverse: true),
                      delay: 500.ms,
                    )
                    .scale(
                      begin: const Offset(1, 1),
                      end: const Offset(1.03, 1.03),
                      duration: 800.ms,
                    ),
              ],
            ),
          ),
        );
      },
    );
  }
}
