import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swipewipe10/data/providers.dart';
import 'package:swipewipe10/screens/albums_screen.dart';
import 'package:swipewipe10/screens/home_screen.dart';
import 'package:swipewipe10/screens/swipe_screen.dart';
import 'package:swipewipe10/utils/theme.dart';

class MainNavigationView extends ConsumerWidget {
  const MainNavigationView({super.key});

  static final List<Widget> _screens = [
    const AlbumsScreen(),
    const HomeScreen(),
    const SwipeScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pageController = ref.watch(pageControllerProvider);
    final currentIndex = ref.watch(pageIndexProvider);

    void onPageChanged(int index) {
      ref.read(pageIndexProvider.notifier).state = index;
    }

    void onNavItemTapped(int index) {
      pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          _getAppBarTitle(currentIndex),
          style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 20),
        ),
        centerTitle: true,
        leading: currentIndex > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios),
                onPressed: () => onNavItemTapped(currentIndex - 1),
              )
            : null,
        actions: [
          if (currentIndex < _screens.length - 1)
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios),
              onPressed: () => onNavItemTapped(currentIndex + 1),
            ),
        ],
      ),
      body: PageView(
        controller: pageController,
        onPageChanged: onPageChanged,
        physics: currentIndex == 2 ? const NeverScrollableScrollPhysics() : const PageScrollPhysics(),
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: onNavItemTapped,
        backgroundColor: kColorBlack,
        selectedItemColor: kColorWhite,
        unselectedItemColor: kColorGreyLight,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.photo_album_outlined),
            activeIcon: Icon(Icons.photo_album),
            label: 'Albums',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.swipe_outlined),
            activeIcon: Icon(Icons.swipe),
            label: 'Swipe',
          ),
        ],
      ),
    );
  }

  String _getAppBarTitle(int index) {
    switch (index) {
      case 0:
        return 'My Albums';
      case 1:
        return 'SwipeClean';
      case 2:
        return 'Clean Up';
      default:
        return 'SwipeClean';
    }
  }
}