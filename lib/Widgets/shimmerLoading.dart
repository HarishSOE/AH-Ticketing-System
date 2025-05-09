import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

// ignore: must_be_immutable
class ShimmerLoading extends StatelessWidget {
  final double height;
  final double width;
  Color? baseColor;
  Color? highlightColor;
  ShimmerLoading({
    Key? key,
    required this.height,
    required this.width,
    this.baseColor,
    this.highlightColor
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return  SizedBox(
      child: Shimmer.fromColors(
        baseColor: baseColor ?? Colors.grey.shade100,
        highlightColor: highlightColor ?? Colors.white,
        direction: ShimmerDirection.ttb,
        child: Container(
          height: height,
          width: width,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: Colors.grey[200],
          ),
        ),
      ),
    );
  }
}