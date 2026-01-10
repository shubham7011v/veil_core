import 'main_common.dart';

void main() {
  // Default to Dev config if run without target
  mainCommon(env: 'dev', appName: 'Bluff Dev');
}
