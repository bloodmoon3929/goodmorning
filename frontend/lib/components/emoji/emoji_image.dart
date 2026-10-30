import 'package:flutter/widgets.dart';

/// Fluent Emoji 3D 그림 (assets/emoji, MIT). 공개 저장소라 캐릭터 사진 대신 쓴다.
/// 글꼴 이모지는 기기마다 모양이 다르고 웹에서는 외부 글꼴을 받아야 해서 그림으로 넣었다.
class EmojiImage extends StatelessWidget {
  const EmojiImage(this.name, {super.key, this.size = 24});

  final String name; // 아래 표의 키 (horns, ribbon …)
  final double size;

  static const files = <String, String>{
    'bell': 'bell',
    'camera': 'camera',
    'house': 'house',
    'teddy': 'teddy_bear',
    'pin': 'round_pushpin',
    'smile': 'slightly_smiling_face',
    'globe': 'globe_with_meridians',
    'gear': 'gear',
    'star': 'star',
    'compass': 'compass',
    'phone': 'telephone_receiver',
    'link': 'link',
    'cart': 'shopping_cart',
    'receipt': 'receipt',
    'memo': 'memo',
    'speech': 'speech_balloon',
    'chart_down': 'chart_decreasing',
    'package': 'package',
    'check': 'check_mark_button',
    'warning': 'warning',
    'store': 'department_store',
    'moai': 'moai',
    'key': 'key',
    'placard': 'placard',
    'robot': 'robot',
    'die': 'game_die',
    'ribbon': 'ribbon',
    'hamster': 'hamster',
    'bolt': 'high_voltage',
    'swords': 'crossed_swords',
    'castle': 'castle',
    'crayon': 'crayon',
    'sailboat': 'sailboat',
    'horns': 'smiling_face_with_horns',
    'cat': 'cat_face',
    'rabbit': 'rabbit_face',
    'cloud': 'cloud',
    'alien': 'alien_monster',
    'sparkles': 'sparkles',
    'black_heart': 'black_heart',
    'red_heart': 'red_heart',
    'bags': 'shopping_bags',
    'map': 'world_map',
    'sunrise': 'sunrise',
    'bookmark': 'bookmark',
    'bulb': 'light_bulb',
    'party': 'party_popper',
    'megaphone': 'megaphone',
    'envelope': 'envelope',
    'mobile': 'mobile_phone',
    'lock': 'locked',
    'bust': 'bust_in_silhouette',
    'magnifier': 'magnifying_glass_tilted_left',
    'camera_flash': 'camera_with_flash',
    'picture': 'framed_picture',
  };

  static String path(String name) => 'assets/emoji/${files[name] ?? name}_3d.png';

  @override
  Widget build(BuildContext context) => Image.asset(
    path(name),
    width: size,
    height: size,
    filterQuality: FilterQuality.medium,
    gaplessPlayback: true,
    errorBuilder: (_, _, _) => SizedBox(width: size, height: size),
  );
}
