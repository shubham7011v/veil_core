import 'package:flutter/material.dart';
import '../../../../core/constants/sound_assets.dart';
import '../../../../core/di/service_locator.dart';

class SoundTestScreen extends StatelessWidget {
  const SoundTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sound Test (Dev Tool)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('Music / Ambience'),
          _buildMusicTile('Lobby Ambience', SoundAssets.lobbyAmbience),
          _buildMusicTile('Game BGM', SoundAssets.gameBgm),

          const SizedBox(height: 20),
          _buildSectionHeader('Core SFX'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildSfxButton('Card Flip', SoundAssets.cardFlip),
              _buildSfxButton('Card Slide', SoundAssets.cardSlide),
              _buildSfxButton('Deal Card', SoundAssets.dealCard),
              _buildSfxButton('Chip Place', SoundAssets.chipPlace),
            ],
          ),

          const SizedBox(height: 20),
          _buildSectionHeader('UI & Feedback'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildSfxButton('Button Tap', SoundAssets.buttonTap),
              _buildSfxButton('Toggle On', SoundAssets.toggleOn),
              _buildSfxButton('Toggle Off', SoundAssets.toggleOff),
              _buildSfxButton('Success', SoundAssets.success),
              _buildSfxButton('Error', SoundAssets.error),
            ],
          ),

          const SizedBox(height: 20),
          _buildSectionHeader('Game Events'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildSfxButton('Turn Alert', SoundAssets.turnAlert),
              _buildSfxButton('Challenge', SoundAssets.challenge),
              _buildSfxButton('Win Round', SoundAssets.winRound),
              _buildSfxButton('Lose Round', SoundAssets.loseRound),
              _buildSfxButton('Bluff Caught', SoundAssets.bluffCaught),
            ],
          ),

          const SizedBox(height: 40),
          const Divider(),
          const Text(
            'Note: Files must exist in assets/audio/music/ or assets/audio/sfx/ for these to work.',
            style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildMusicTile(String name, String filename) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.music_note),
        title: Text(name),
        subtitle: Text('music/$filename'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.play_arrow),
              onPressed: () => sl.audioService.playBgm(filename),
            ),
            IconButton(
              icon: const Icon(Icons.stop),
              onPressed: () => sl.audioService.stopBgm(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSfxButton(String label, String filename) {
    return ElevatedButton.icon(
      onPressed: () => sl.audioService.playSfx(filename),
      icon: const Icon(Icons.volume_up, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }
}
