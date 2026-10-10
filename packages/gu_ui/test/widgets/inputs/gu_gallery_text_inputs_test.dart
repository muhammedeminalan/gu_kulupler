// T-05 · metin girdileri galeri golden'ı
// (`gu_gallery_text_inputs__default__*.png`): GuInput, GuSearchField,
// GuPickerField, GuStepper (+ GuField çerçevesi).
// Referans: `ds_inputs.webp` (boş, dolu + yardım, şifre + göz, arama, hata,
// kilitli, çok satırlı, seçici dolu / hata, odak), `ds_nav.webp` (44 px arama
// çubuğu + temizle), `screens-manage.js:112` (kontenjan adımlayıcı).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/golden_helper.dart';

void _noop() {}

void _noopInt(int _) {}

class _Gallery extends StatefulWidget {
  const _Gallery();

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  static const String _email = 'ayse.demir@ogr.gumushane.edu.tr';

  final _filled = TextEditingController(text: _email);
  final _password = TextEditingController(text: 'Demo1234!');
  final _invalid = TextEditingController(text: 'ayse@gmail.com');
  final _locked = TextEditingController(text: _email);
  final _note = TextEditingController(
    text: 'Doğayı çok seviyorum, katılmak isterim.',
  );
  final _over = TextEditingController(text: 'Toplantı salonu dolu olduğu için');
  final _disabled = TextEditingController(text: 'Doğa Sporları Kulübü');
  final _focus = TextEditingController(text: 'odak durumu');

  @override
  void dispose() {
    for (final c in [
      _filled,
      _password,
      _invalid,
      _locked,
      _note,
      _over,
      _disabled,
      _focus,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: GuSpacing.s12,
    children: [
      // ds_inputs sırası.
      const GuInput(
        label: 'E-posta',
        icon: GuIcons.mail,
        placeholder: 'ad.soyad@ogr.gumushane.edu.tr',
      ),
      GuInput(
        label: 'E-posta',
        icon: GuIcons.mail,
        controller: _filled,
        help: 'Okul e-posta adresinle kayıt ol',
      ),
      GuInput(
        label: 'Şifre',
        icon: GuIcons.keyRound,
        controller: _password,
        obscure: true,
        trailing: const GuIconButton(
          icon: GuIcons.eye,
          size: GuIconButtonSize.sm,
          semanticLabel: 'Şifreyi göster',
          onPressed: _noop,
        ),
      ),
      const GuSearchField(value: '', placeholder: 'Kulüp veya etkinlik ara'),
      GuInput(
        label: 'E-posta',
        icon: GuIcons.mail,
        controller: _invalid,
        errorText: 'Yalnızca üniversite e-postası kullanılabilir',
      ),
      GuInput(
        label: 'E-posta',
        controller: _locked,
        locked: true,
        help: 'Üniversite e-postası değiştirilemez',
      ),
      GuInput(
        label: 'Neden katılmak istiyorsun?',
        controller: _note,
        multiline: true,
        maxLength: 300,
      ),
      const GuPickerField(
        label: 'Bölüm',
        icon: GuIcons.graduationCap,
        value: 'Bilgisayar Mühendisliği',
        onTap: _noop,
      ),
      const GuPickerField(
        label: 'Sınıf',
        icon: GuIcons.calendarDays,
        placeholder: 'Seç',
        errorText: 'Bu alan zorunlu',
        onTap: _noop,
      ),
      // Odak (css:164). Geçiş `GuMotion.fast`; golden tek karede yakalandığı
      // için hareket azaltılır (odak ikinci karede gelir, geçiş anında biter).
      MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: GuInput(
          icon: GuIcons.mail,
          controller: _focus,
          autofocus: true,
        ),
      ),
      // Ek durumlar: sayaç aşımı (css:172), devre dışı (css:165, K-38).
      GuInput(
        label: 'İptal nedeni',
        controller: _over,
        multiline: true,
        rows: 2,
        maxLength: 30,
        showCounter: true,
      ),
      GuInput(label: 'Kulüp adı', controller: _disabled, disabled: true),
      const GuPickerField(
        label: 'Kategori',
        value: 'Spor',
        disabled: true,
        onTap: _noop,
      ),
      // ds_nav: CLB-02 arama çubuğu (min 44 + temizle + "İptal").
      const Row(
        spacing: GuSpacing.s4,
        children: [
          Expanded(
            child: GuSearchField(
              value: 'hackathon',
              compact: true,
              semanticLabel: 'Ara',
              clearSemanticLabel: 'Temizle',
              onClear: _noop,
            ),
          ),
          GuButton(
            label: 'İptal',
            variant: GuButtonVariant.text,
            onPressed: _noop,
          ),
        ],
      ),
      // MGT-05 kontenjan: varsayılan ve alt sınırda (eksi devre dışı).
      const GuStepper(
        value: 40,
        min: 1,
        max: 1000,
        step: 5,
        decreaseSemanticLabel: 'Azalt',
        increaseSemanticLabel: 'Artır',
        onChanged: _noopInt,
      ),
      const GuStepper(
        value: 1,
        min: 1,
        max: 1000,
        step: 5,
        decreaseSemanticLabel: 'Azalt',
        increaseSemanticLabel: 'Artır',
        onChanged: _noopInt,
      ),
    ],
  );
}

void main() {
  testWidgets('T-05 · metin girdileri · galeri golden (açık + koyu)', (
    tester,
  ) async {
    await goldenForWidget(tester, 'gu_gallery_text_inputs', {
      'default': const _Gallery(),
    }, size: const Size(532, 1700));
  });
}
