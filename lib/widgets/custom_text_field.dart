import 'package:flutter/material.dart';

abstract class CustomTextField extends StatefulWidget {
  final String label;
  final IconData icon;
  final TextEditingController controller;

  const CustomTextField({super.key, required this.label, required this.icon, required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
    );
  }
  
  }

