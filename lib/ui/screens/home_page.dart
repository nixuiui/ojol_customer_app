import 'package:flutter/material.dart';
import 'package:ojol_customer_app/ui/screens/map_area.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  List<StatefulWidget> _layoutPage;

  @override
  void initState() {
    _layoutPage = [
      MapArea(),
      MapArea(),
      MapArea(),
    ];
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _layoutPage.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        selectedItemColor: Colors.black87,
        unselectedItemColor: Colors.grey[400],
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home), title: Text('', style: TextStyle(fontSize: 0))
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history), title: Text('', style: TextStyle(fontSize: 0))
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_circle), title: Text('', style: TextStyle(fontSize: 0))
          ),
        ],
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onTabItem,
      )
    );
  }

  void _onTabItem(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }
}