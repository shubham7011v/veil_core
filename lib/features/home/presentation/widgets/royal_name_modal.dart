import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../features/profile/profile.dart';

class RoyalNameModal extends StatefulWidget {
  const RoyalNameModal({super.key});

  @override
  State<RoyalNameModal> createState() => _RoyalNameModalState();
}

class _RoyalNameModalState extends State<RoyalNameModal> {
  late TextEditingController _nameController;
  final List<String> _suggestions = [
    'Baron von Bluff',
    'Duke of Deception',
    'Knight of Knaves',
    'Lord of Lies',
    'Prince of Perjury',
  ];

  @override
  void initState() {
    super.initState();
    final randomName =
        _suggestions[DateTime.now().millisecond % _suggestions.length];
    _nameController = TextEditingController(text: randomName);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFFE5A043).withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Choose your Royal Name',
              style: GoogleFonts.cinzel(
                color: const Color(0xFFE5A043),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _nameController,
              style: GoogleFonts.inter(color: Colors.white, fontSize: 18),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.black26,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                hintText: 'Enter name...',
                hintStyle: const TextStyle(color: Colors.white24),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  if (_nameController.text.trim().isNotEmpty) {
                    context.read<ProfileBloc>().add(
                      ProfileNameUpdateRequested(_nameController.text.trim()),
                    );
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE5A043),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'CONFIRM',
                  style: GoogleFonts.cinzel(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
