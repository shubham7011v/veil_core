import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/engine/data/handlers/websocket_session_handler.dart';
import '../../domain/models/friend_record.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/bloc/theme_bloc.dart';
import '../../../../core/theme/bloc/theme_state.dart';
import '../../../../core/di/service_locator.dart' as di;
import '../../../../core/config/app_config.dart';
import '../../../profile/profile.dart';

class FriendsScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const FriendsScreen({super.key, this.onBack});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  late WebSocketSessionHandler _handler;
  final TextEditingController _searchController = TextEditingController();
  bool _isConnecting = false;
  String? _connectionError;

  @override
  void initState() {
    super.initState();
    _handler = di.sl.webSocketSessionHandler;
    _ensureConnection();
  }

  Future<void> _ensureConnection() async {
    if (_handler.connectionStatus == ConnectionStatus.connected) {
      _handler.requestFriends();
      return;
    }

    setState(() => _isConnecting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _isConnecting = false;
          _connectionError = 'Please sign in to view friends';
        });
        return;
      }

      final token = await user.getIdToken();
      if (token == null) {
        setState(() {
          _isConnecting = false;
          _connectionError = 'Authentication failed';
        });
        return;
      }

      await _handler.connect(
        AppConfig.instance.serverUrl,
        token,
        displayName: user.displayName,
      );

      _handler.requestFriends();

      if (mounted) {
        setState(() {
          _isConnecting = false;
          _connectionError = null;
        });
      }
    } on SocketException catch (_) {
      // Server is not running or unreachable
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _connectionError =
              'Unable to connect to server.\nPlease check your internet connection or try again later.';
        });
      }
    } on TimeoutException catch (_) {
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _connectionError = 'Connection timed out.\nPlease try again.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _connectionError = 'Connection failed.\nPlease try again later.';
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeBloc, ThemeState>(
      builder: (context, themeState) {
        final palette = AppColors.getPalette(themeState.mode);

        return Scaffold(
          backgroundColor: palette.background,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text(
              'THE INNER CIRCLE',
              style: GoogleFonts.cinzel(
                color: palette.primary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: palette.textSecondary),
              onPressed: () {
                if (widget.onBack != null) {
                  widget.onBack!();
                } else {
                  Navigator.pop(context);
                }
              },
            ),
          ),
          body: _buildBody(palette),
        );
      },
    );
  }

  Widget _buildBody(AppColorPalette palette) {
    if (_isConnecting) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: palette.primary),
            const SizedBox(height: 16),
            Text(
              'Connecting to server...',
              style: TextStyle(color: palette.textSecondary),
            ),
          ],
        ),
      );
    }

    if (_connectionError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off, color: palette.textTertiary, size: 64),
            const SizedBox(height: 16),
            Text(
              _connectionError!,
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.textSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _ensureConnection,
              icon: const Icon(Icons.refresh),
              label: const Text('RETRY'),
              style: ElevatedButton.styleFrom(
                backgroundColor: palette.primary,
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildAddFriendSection(palette),
        Divider(color: palette.divider, height: 1),
        Expanded(
          child: StreamBuilder<List<FriendRecord>>(
            stream: _handler.friendsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return Center(
                  child: CircularProgressIndicator(color: palette.primary),
                );
              }

              final friends = snapshot.data ?? [];

              if (friends.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.people_outline,
                        color: palette.textTertiary,
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Your circle is empty\nAdd friends to see their status',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: palette.textSecondary),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 24,
                ),
                itemCount: friends.length,
                itemBuilder: (context, index) {
                  return _buildFriendTile(friends[index], palette);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAddFriendSection(AppColorPalette palette) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ADD BY PLAYER ID',
            style: GoogleFonts.inter(
              color: palette.textTertiary,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(color: palette.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'user_123...',
                    hintStyle: TextStyle(
                      color: palette.textTertiary,
                      fontSize: 14,
                    ),
                    filled: true,
                    fillColor: palette.surfaceLight,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              InkWell(
                onTap: () {
                  if (_searchController.text.isNotEmpty) {
                    _handler.addFriend(_searchController.text);
                    _searchController.clear();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Friend request sent')),
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: palette.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.person_add_alt_1,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFriendTile(FriendRecord friend, AppColorPalette palette) {
    bool isPending = friend.status == 'pending';

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProfileViewScreen(userId: friend.friendId),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: palette.surfaceLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.divider),
        ),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: palette.primary.withValues(alpha: 0.1),
                  child: Icon(Icons.person, color: palette.primary, size: 24),
                ),
                if (friend.isOnline)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: palette.success,
                        shape: BoxShape.circle,
                        border: Border.all(color: palette.background, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    friend.name,
                    style: GoogleFonts.inter(
                      color: palette.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    friend.rank.toUpperCase(),
                    style: GoogleFonts.inter(
                      color: friend.isOnline
                          ? palette.primary
                          : palette.textTertiary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (isPending)
              ElevatedButton(
                onPressed: () => _handler.acceptFriend(friend.friendId),
                style: ElevatedButton.styleFrom(
                  backgroundColor: palette.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'ACCEPT',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              )
            else
              Text(
                friend.isOnline ? 'ONLINE' : 'AWAY',
                style: GoogleFonts.inter(
                  color: friend.isOnline
                      ? palette.success
                      : palette.textTertiary,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
