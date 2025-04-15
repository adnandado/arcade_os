import 'dart:math';
import 'package:flutter/material.dart';

class InfoSection extends StatelessWidget {
  final String imagePath;
  final String title;
  final String content;
  final bool isSelected;
  final double width;
  final VoidCallback onTap;
  final String detailedText;

  const InfoSection({
    required this.imagePath,
    required this.title,
    required this.content,
    required this.detailedText,
    required this.width,
    this.isSelected = false,
    required this.onTap,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double itemWidth = screenWidth * 0.35;
    return SizedBox(
      height: 375,
      width: width,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Card(
            elevation: isSelected ? 8 : 4,
            color: Colors.transparent,
            margin: const EdgeInsets.all(8.0),
            child: Stack(
              children: [
                Container(
                  height: 250,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(0),
                    border: Border.all(
                      color:
                          isSelected
                              ? Color.fromARGB(186, 233, 183, 1).withOpacity(
                                0.7 +
                                    0.3 *
                                        sin(
                                          DateTime.now()
                                                  .millisecondsSinceEpoch /
                                              400,
                                        ),
                              )
                              : Colors.transparent,
                      width:
                          2 + sin(DateTime.now().millisecondsSinceEpoch / 400),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(0),
                    child: Image.asset(imagePath, fit: BoxFit.cover),
                  ),
                ),
                Container(
                  height: 250,
                  width: double.infinity,
                  color: Colors.black.withOpacity(0.3),
                ),
                Positioned(
                  left: 16,
                  bottom: 20,
                  child: Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.8),
                          blurRadius: 2,
                          offset: Offset(1, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
