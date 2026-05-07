import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

Future<String?> persistProfileAvatarFromXFile(XFile x) async {
  final dir = await getApplicationDocumentsDirectory();
  final dest = File('${dir.path}/profile_avatar.jpg');
  await File(x.path).copy(dest.path);
  return dest.path;
}
