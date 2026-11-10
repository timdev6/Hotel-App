// -----------------------------------------------------------------------
// Filename: screen_splash.dart
// Original Author: Dan Grissom
// Creation Date: 5/21/2024
// Copyright: (c) 2024 CSC322
// Description: This file checks contains the splash screen which is shown
//              when the app is first opened.

//////////////////////////////////////////////////////////////////////////
// Imports
//////////////////////////////////////////////////////////////////////////
// Flutter external package imports
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

// App relative file imports

//////////////////////////////////////////////////////////////////
// StateFUL widget which manages state. Simply initializes the
// state object.
//////////////////////////////////////////////////////////////////
class ScreenSplash extends StatelessWidget {
  const ScreenSplash({super.key});

  ////////////////////////////////////////////////////////////////
  // Primary Flutter method overriden which describes the layout
  // and bindings for this widget.
  ////////////////////////////////////////////////////////////////
  @override
  Widget build(BuildContext context) {
    // Return the widget for this control
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.all(0),
          child: Center(child: Image.asset("images/logo.png", width: MediaQuery.of(context).size.width * 0.8)),
        ),
        // const Padding(
        //   padding: EdgeInsets.all(20),
        //   child: Center(
        //     child: CircularProgressIndicator(),
        //   ),
        // ),
        // SizedBox(height: 20),
        // Text(
        //   "My App",
        //   textAlign: TextAlign.center,
        //   style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
        // ),
        // SizedBox(height: 20),
        // Center(
        //   child: Lottie.asset(
        //     MediaQuery.of(context).platformBrightness == Brightness.light
        //         // ? 'animations/loading_light_mode.json'
        //         ? 'animations/loading_dots.json'
        //         : 'animations/loading_dots.json',
        //     animate: true,
        //     width: MediaQuery.of(context).size.width * 0.5,
        //   ),
        // ),
      ],
    );
  }
}
