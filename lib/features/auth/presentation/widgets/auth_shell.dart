import 'package:flutter/material.dart';

class AuthShell extends StatelessWidget {
  const AuthShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.maxFormWidth = 460,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final double maxFormWidth;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;

            if (wide) {
              return Row(
                children: [
                  const Expanded(flex: 5, child: _BrandPanel()),
                  Expanded(
                    flex: 4,
                    child: _FormPanel(
                      title: title,
                      subtitle: subtitle,
                      maxFormWidth: maxFormWidth,
                      child: child,
                    ),
                  ),
                ],
              );
            }

            return _FormPanel(
              title: title,
              subtitle: subtitle,
              maxFormWidth: maxFormWidth,
              showMobileBrand: true,
              child: child,
            );
          },
        ),
      ),
    );
  }
}

class _FormPanel extends StatelessWidget {
  const _FormPanel({
    required this.title,
    required this.subtitle,
    required this.maxFormWidth,
    required this.child,
    this.showMobileBrand = false,
  });

  final String title;
  final String subtitle;
  final double maxFormWidth;
  final Widget child;
  final bool showMobileBrand;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF8FAFC),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxFormWidth),
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showMobileBrand) ...[
                    const _CompactBrand(),
                    const SizedBox(height: 34),
                  ],
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF101828),
                        ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: const Color(0xFF667085),
                          height: 1.45,
                        ),
                  ),
                  const SizedBox(height: 30),
                  child,
                  const SizedBox(height: 24),
                  Text(
                    'CMX Web Portal',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF98A2B3),
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0B3B82), Color(0xFF175CD3)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -120,
            right: -100,
            child: _Glow(size: 330, opacity: 0.12),
          ),
          Positioned(
            bottom: -110,
            left: -90,
            child: _Glow(size: 300, opacity: 0.10),
          ),
          Padding(
            padding: const EdgeInsets.all(64),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _CompactBrand(onDark: true),
                const Spacer(),
                const Icon(
                  Icons.security_rounded,
                  color: Colors.white,
                  size: 66,
                ),
                const SizedBox(height: 26),
                Text(
                  'Secure access to your CMX portal.',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                ),
                const SizedBox(height: 18),
                Text(
                  'One responsive Flutter authentication experience for web, Android and iOS.',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.82),
                        height: 1.55,
                      ),
                ),
                const Spacer(),
                Text(
                  'LOGIN  •  OTP SIGNUP  •  PASSWORD RESET',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Colors.white70,
                        letterSpacing: 1.2,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactBrand extends StatelessWidget {
  const _CompactBrand({this.onDark = false});

  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final foreground = onDark ? Colors.white : const Color(0xFF101828);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: onDark ? Colors.white : const Color(0xFF175CD3),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            'C',
            style: TextStyle(
              color: onDark ? const Color(0xFF175CD3) : Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'CMX',
          style: TextStyle(
            color: foreground,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity),
      ),
    );
  }
}
