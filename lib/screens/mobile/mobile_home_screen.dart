import 'dart:math' as math;
import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:github/github.dart';
import 'package:github_activity_feed/app/provided.dart';
import 'package:github_activity_feed/screens/mobile/user_overview.dart';
import 'package:github_activity_feed/screens/widgets/async_markdown.dart';
import 'package:github_activity_feed/screens/widgets/following_users.dart';
import 'package:github_activity_feed/screens/widgets/mobile_activity_feed.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:rxdart/rxdart.dart';

class MobileHomeScreen extends StatefulWidget {
  @override
  _MobileHomeScreenState createState() => _MobileHomeScreenState();
}

class _MobileHomeScreenState extends State<MobileHomeScreen> with ProvidedState {
  int _currentIndex = 0;
  final _activityFeed = BehaviorSubject<List<Event>>();
  final _userFollowing = BehaviorSubject<List<User>>();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_activityFeed.hasValue) {
      PaginationHelper(github.github)
          .objects(
            'GET',
            '/users/${user.login}/received_events',
            (i) => Event.fromJson(i),
            statusCode: 200,
          )
          .toList()
          .then((data) {
        _activityFeed.value = data;
        precacheReadmes(data);
      });
    }
    if (!_userFollowing.hasValue) {
      PaginationHelper(github.github)
          .objects(
            'GET',
            '/user/following',
            (i) => User.fromJson(i),
            statusCode: 200,
          )
          .toList()
          .then((data) {
        _userFollowing.value = data;
      });
    }
  }

  /// HACKY - DO NOT DO THIS IN THE UI
  Future<void> precacheReadmes(List<Event> events) async {
    final futureFiles = <Future<GitHubFile>>[];
    for(int i = 0; i < math.min(events.length, 25); i++) {
      final event = events[i];
      final slug = RepositorySlug.full(event.repo.name);
      futureFiles.add(github.github.repositories.getReadme(slug));
    }
    final files = await Future.wait(futureFiles);
    final futureCaches = <Future<void>>[];
    for(final file in files) {
      futureCaches.add(preCacheMarkdown(file.content));
    }
    await Future.wait(futureCaches);
    print('all done');
  }

  @override
  void dispose() {
    _userFollowing.close();
    _activityFeed.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: InkResponse(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: CircleAvatar(
              backgroundImage: NetworkImage(user.avatarUrl),
            ),
          ),
          onTap: () {
            return Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => UserOverview(user: user),
              ),
            );
          },
        ),
        title: Text(
          'Activity Feed',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search),
            onPressed: () {},
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          MobileActivityFeed(events: _activityFeed),
          FollowingUsers(users: _userFollowing),
        ],
      ),
      /*body: TwoTabPager(
        index: _currentIndex,
        children: [
          MobileActivityFeed(events: _activityFeed),
          FollowingUsers(users: _userFollowing),
        ],
      ),*/
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
        },
        items: [
          BottomNavigationBarItem(
            icon: Icon(MdiIcons.github),
            title: Text('Feed'),
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            title: Text('Following'),
          ),
        ],
      ),
    );
  }
}

class TwoTabPager extends StatefulWidget {
  const TwoTabPager({
    Key key,
    this.index,
    this.children,
  })  : assert(children.length == 2),
        super(key: key);

  final int index;
  final List<Widget> children;

  @override
  _TwoTabPagerState createState() => _TwoTabPagerState();
}

class _TwoTabPagerState extends State<TwoTabPager> with TickerProviderStateMixin {
  AnimationController tab0PrimaryAnimation;
  AnimationController tab0SecondaryAnimation;
  AnimationController tab1PrimaryAnimation;
  AnimationController tab1SecondaryAnimation;

  @override
  void initState() {
    super.initState();
    final duration = const Duration(milliseconds: 300);
    tab0PrimaryAnimation = AnimationController(
      value: widget.index == 0 ? 1.0 : 0.0,
      duration: duration,
      vsync: this,
    );
    tab0SecondaryAnimation = AnimationController(duration: duration, vsync: this);
    tab1PrimaryAnimation = AnimationController(
      value: widget.index == 0 ? 0.0 : 1.0,
      duration: duration,
      vsync: this,
    );
    tab1SecondaryAnimation = AnimationController(duration: duration, vsync: this);
  }

  @override
  void didUpdateWidget(TwoTabPager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      if (widget.index == 0) {
        tab0PrimaryAnimation.forward(from: 0.0);
        tab1SecondaryAnimation.forward(from: 0.0);
        tab1PrimaryAnimation.reverse();
        tab0SecondaryAnimation.reverse();
      } else {
        tab1PrimaryAnimation.forward(from: 0.0);
        tab0SecondaryAnimation.forward(from: 0.0);
        tab0PrimaryAnimation.reverse();
        tab1SecondaryAnimation.reverse();
      }
    }
  }

  @override
  void dispose() {
    tab0SecondaryAnimation.dispose();
    tab0PrimaryAnimation.dispose();
    tab1SecondaryAnimation.dispose();
    tab1PrimaryAnimation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    //PageTransitionSwitcher();
    return IgnorePointer(
      ignoring: false,
      child: Stack(
        children: [
          FadeThroughTransition(
            animation: tab0PrimaryAnimation,
            secondaryAnimation: tab0SecondaryAnimation,
            child: widget.children[0],
          ),
          FadeThroughTransition(
            animation: tab1PrimaryAnimation,
            secondaryAnimation: tab1SecondaryAnimation,
            child: widget.children[1],
          ),
        ],
      ),
    );
  }
}
