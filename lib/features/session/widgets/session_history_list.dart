import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/session_bloc.dart';
import '../bloc/session_state.dart';

class SessionHistoryList extends StatelessWidget {
  const SessionHistoryList({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SessionBloc, SessionBlocState>(
      builder: (context, state) {
        final bloc = context.read<SessionBloc>();
        final logs = bloc.handler.gameLog;
        if (logs.isEmpty) {
          return const Center(
            child: Text(
              "NO RECORDS YET",
              style: TextStyle(color: Colors.white24, fontSize: 12),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: logs.length,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFD700),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      logs[index],
                      style: TextStyle(
                        color: index == 0 ? Colors.white : Colors.white70,
                        fontSize: 14,
                        fontWeight: index == 0
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
