import 'package:flutter/material.dart';
import '../../store/settings_store.dart';
import '../../constants/theme.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _ctrl = PageController();
  int _page = 0;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < 2) {
      _ctrl.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    await SettingsStore().update(
      SettingsStore().settings.copyWith(hasCompletedOnboarding: true),
    );
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _finish,
                child: const Text('Skip', style: TextStyle(color: kTextMuted)),
              ),
            ),

            // Pages
            Expanded(
              child: PageView(
                controller: _ctrl,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _OnboardingPage(
                    emoji: '✅',
                    title: 'أهلاً في TodoList',
                    subtitle: 'أداة ذكية للـ to-do بالعربي المصري واللهجة العامية.\nسريع، عملي، ومشترك مع Groq للـ voice والـ parsing.',
                    color: kPrimary,
                  ),
                  _OnboardingPage(
                    emoji: '🧠',
                    title: 'فهم عامي ومصري',
                    subtitle: 'اكتب أو اتكلم باللهجة المصرية:\n"أنا عايز أعمل meeting بكره الساعة 3 #شغل p1"\nوالأداة هتفهمه وتضيف المهمة.',
                    color: kP3Blue,
                    demo: const _NlpDemo(),
                  ),
                  _OnboardingPage(
                    emoji: '🔔',
                    title: 'خلي كل حاجة سهلة',
                    subtitle: 'أضف reminders، نظم مشاريع، وسوم، ومتابعة الكل بسرعة وبأقل جهد.',
                    color: kSuccess,
                  ),
                ],
              ),
            ),

            // Dots + button
            Padding(
              padding: const EdgeInsets.all(kSpace32),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _page == i ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _page == i ? kPrimary : kTextMuted.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    )),
                  ),
                  const SizedBox(height: kSpace24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _next,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        _page == 2 ? 'Get Started' : 'Continue',
                        style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final Color color;
  final Widget? demo;

  const _OnboardingPage({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.color,
    this.demo,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kSpace32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Emoji in circle
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 48)),
            ),
          ),
          const SizedBox(height: kSpace32),

          Text(
            title,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: kSpace12),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 16, color: kTextMuted, height: 1.5),
            textAlign: TextAlign.center,
          ),

          if (demo != null) ...[
            const SizedBox(height: kSpace32),
            demo!,
          ],
        ],
      ),
    );
  }
}

class _NlpDemo extends StatelessWidget {
  const _NlpDemo();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(kSpace12),
      decoration: BoxDecoration(
        color: isDark ? kDarkSurface : kLightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? kDarkBorder : kLightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '"Call Alex tomorrow at 3pm #work p1"',
            style: TextStyle(fontFamily: 'monospace', fontSize: 13, color: kPrimary),
          ),
          const SizedBox(height: kSpace8),
          const Divider(height: 1),
          const SizedBox(height: kSpace8),
          Wrap(
            spacing: kSpace8,
            runSpacing: 4,
            children: [
              _DemoChip(Icons.calendar_today_outlined, 'Tomorrow', kP3Blue),
              _DemoChip(Icons.access_time, '3:00 PM', kP3Blue),
              _DemoChip(Icons.folder_outlined, 'work', kTextMuted),
              _DemoChip(Icons.flag_outlined, 'P1', kP1Red),
            ],
          ),
        ],
      ),
    );
  }
}

class _DemoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _DemoChip(this.icon, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
