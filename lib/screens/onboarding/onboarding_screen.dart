import 'package:flutter/material.dart';
import '../auth/auth_screen.dart';
import '../../widgets/network/network_wrapper.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  int _currentPage = 0;

  final List<OnboardingData> _onboardingData = [
    OnboardingData(
      image: 'assets/images/onboarding/onboarding_1.png',
      title: 'یادگیری در هر زمان، هر مکان',
      description:
          'بدون محدودیت زمان و مکان، به تمام محتوای آموزشی روی گوشی هوشمند خود دسترسی داشته باشید',
    ),
    OnboardingData(
      image: 'assets/images/onboarding/onboarding_2.png',
      title: 'یادگیری از اساتید برتر',
      description:
          'با تدریس بهترین و با تجربه ترین معلمان، مفاهیم درسی را عمیق و آسان یاد بگیرید',
    ),
    OnboardingData(
      image: 'assets/images/onboarding/onboarding_3.png',
      title: 'پوشش کامل دروس و مباحث',
      description:
          'مجموعه کاملی از ویدئوها جزوات و نمونه سوالات برای تمام دروس شما در یک اپلیکیشن',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeInOut),
        );
    // انیمیشن اولیه رو در موقعیت نهایی قرار بده
    _slideController.value = 1.0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final currentData = _onboardingData[_currentPage];
    final isLastPage = _currentPage == _onboardingData.length - 1;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Expanded(
                flex: 2,
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Image.asset(
                        currentData.image,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.image_not_supported_outlined,
                            size: 100,
                            color: colorScheme.primary,
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              Expanded(
                flex: 2,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SlideTransition(
                      position: _slideAnimation,
                      child: Column(
                        children: [
                          Text(
                            currentData.title,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                              fontFamily: 'IRANSansXFaNum',
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            currentData.description,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: colorScheme.onSurface.withValues(alpha: 0.8),
                              height: 1.5,
                              fontFamily: 'IRANSansXFaNum',
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    _buildPageIndicator(),
                    _buildActionButton(isLastPage),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToAuth() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const SimpleNetworkWrapper(child: AuthScreen()),
      ),
    );
  }

  void _nextPage() {
    if (_currentPage < _onboardingData.length - 1) {
      // ابتدا انیمیشن رو reset کن
      _slideController.reset();
      // سپس صفحه رو تغییر بده
      setState(() {
        _currentPage++;
      });
      // انیمیشن رو شروع کن
      _slideController.forward();
    } else {
      _navigateToAuth();
    }
  }

  Widget _buildPageIndicator() {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        _onboardingData.length,
        (index) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 6),
          width: _currentPage == index ? 32 : 12,
          height: 12,
          decoration: BoxDecoration(
            color: _currentPage == index
                ? colorScheme.primary
                : colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(bool isLastPage) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _nextPage,
        style: ElevatedButton.styleFrom(
          backgroundColor: isLastPage
              ? colorScheme.primary
              : colorScheme.surface,
          foregroundColor: isLastPage
              ? colorScheme.onPrimary
              : colorScheme.onSurface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: isLastPage
                ? BorderSide.none
                : BorderSide(color: colorScheme.primary, width: 2),
          ),
        ),
        child: Text(
          isLastPage ? 'شروع' : 'بعدی',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isLastPage ? colorScheme.onPrimary : colorScheme.onSurface,
            fontFamily: 'IRANSansXFaNum',
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }
}

class OnboardingData {
  final String image;
  final String title;
  final String description;

  OnboardingData({
    required this.image,
    required this.title,
    required this.description,
  });
}
