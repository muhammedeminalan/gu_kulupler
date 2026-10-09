/* ===== SEED ===== deterministic demo data (all fictional). Dates are relative to "today" so the demo always looks current. */
(function () {
  const { rngFor, at, DAY, dayKey, slug, ticketCode, SEED_VERSION } = GU;

  const CATEGORIES = [
    { id: 'k01', icon: 'cpu' }, { id: 'k02', icon: 'flask-conical' }, { id: 'k03', icon: 'mountain' }, { id: 'k04', icon: 'palette' },
    { id: 'k05', icon: 'heart-handshake' }, { id: 'k06', icon: 'briefcase' }, { id: 'k07', icon: 'gamepad-2' }, { id: 'k08', icon: 'newspaper' },
  ];
  const INTERESTS = [
    { id: 'i01', cat: 'k01' }, { id: 'i02', cat: 'k01' }, { id: 'i03', cat: 'k06' }, { id: 'i04', cat: 'k03' }, { id: 'i05', cat: 'k03' }, { id: 'i06', cat: 'k08' }, { id: 'i07', cat: 'k08' }, { id: 'i08', cat: 'k04' },
    { id: 'i09', cat: 'k04' }, { id: 'i10', cat: 'k04' }, { id: 'i11', cat: 'k07' }, { id: 'i12', cat: 'k07' }, { id: 'i13', cat: 'k05' }, { id: 'i14', cat: 'k04' }, { id: 'i15', cat: 'k01' }, { id: 'i16', cat: 'k06' },
  ];
  const FACULTIES = ['f1', 'f2', 'f3', 'f4', 'f5', 'f6'];
  const DEPARTMENTS = [
    ['d01', 'f1'], ['d02', 'f1'], ['d03', 'f1'], ['d04', 'f1'], ['d05', 'f1'], ['d06', 'f1'], ['d07', 'f1'], ['d08', 'f2'], ['d09', 'f2'], ['d10', 'f3'], ['d11', 'f3'], ['d12', 'f3'],
    ['d13', 'f3'], ['d14', 'f3'], ['d15', 'f3'], ['d16', 'f4'], ['d17', 'f4'], ['d18', 'f4'], ['d19', 'f5'], ['d20', 'f5'], ['d21', 'f6'], ['d22', 'f6'], ['d23', 'f6'], ['d24', 'f6'],
  ].map(([id, faculty]) => ({ id, faculty }));
  const YEARS = ['prep', '1', '2', '3', '4', '5plus', 'master', 'phd'];
  const PLACES = ['pl01', 'pl02', 'pl03', 'pl04', 'pl05', 'pl06', 'pl07', 'pl08', 'pl09', 'pl10'];
  const EVENT_TYPES = ['egitim', 'sosyal', 'gezi', 'yarisma', 'konferans'];
  const POPULAR_SEARCHES = ['Hackathon', 'Doğa yürüyüşü', 'Tiyatro', 'E-spor', 'Fotoğraf', 'Satranç'];

  const FIRST = ['Ahmet', 'Zeynep', 'Mustafa', 'Elif', 'Yusuf', 'Defne', 'Emirhan', 'İrem', 'Kerem', 'Ayça', 'Berk', 'Özge', 'Deniz', 'Melis', 'Can', 'Büşra', 'Eren', 'Sude', 'Umut', 'Nisa', 'Furkan', 'Ebru', 'Alp', 'Gizem', 'Onur', 'Merve', 'Bora', 'Esra', 'Tuna', 'Pelin', 'Efe', 'Zehra', 'Barış', 'Hilal', 'Mert', 'Rabia', 'Ozan', 'Dilara', 'Beren', 'Yiğit', 'Doruk', 'Aslı', 'Serkan', 'Nazlı', 'Taha', 'Ceyda', 'Burcu', 'Emre', 'Gökhan', 'Sena'];
  const LAST = ['Yılmaz', 'Kaya', 'Demir', 'Şahin', 'Çelik', 'Yıldız', 'Yıldırım', 'Öztürk', 'Aydın', 'Özdemir', 'Arslan', 'Doğan', 'Kılıç', 'Aslan', 'Çetin', 'Kara', 'Koç', 'Kurt', 'Özkan', 'Şimşek', 'Polat', 'Korkmaz', 'Çakır', 'Erdoğan', 'Aktaş', 'Güneş', 'Bulut', 'Keskin', 'Yavuz', 'Turan', 'Ateş', 'Avcı', 'Taş', 'Sarı', 'Ünal', 'Acar', 'Aksoy', 'Tekin', 'Karaca', 'Uslu'];

  const CLUB_TABLE = [
    ['c01', 'Yazılım ve Yapay Zekâ Topluluğu', 'k01', 'code-xml', 'red', 186, true, true, 'Baran Çelik', 'Zeynep Arslan', 2015, 'Kodlayan, üreten ve paylaşan bir topluluk.', 'Yazılım geliştirme, yapay zekâ ve veri bilimi alanlarında atölyeler, hackathonlar ve söyleşiler düzenliyoruz. Sıfırdan başlayanlar için mentor destekli öğrenme grupları, deneyimliler için proje ekipleri var. Her dönem en az bir kampüs içi hackathon düzenliyoruz.', ['Aktif öğrenci olmak', 'Haftalık buluşmaların en az yarısına katılmak', 'Dönem başı tanışma toplantısına gelmek'], 'guk_yazilim'],
    ['c02', 'Girişimcilik ve İnovasyon Kulübü', 'k06', 'lightbulb', 'slate', 142, true, true, 'Selin Aksoy', 'Zeynep Arslan', 2018, 'Fikirden ürüne giden yolda birlikte öğreniyoruz.', 'Girişimcilik ekosistemini kampüse taşıyoruz: konuk girişimci sohbetleri, fikir yarışmaları ve iş modeli atölyeleri. Fikri olan herkesi ekip kurmaya ve denemeye teşvik ediyoruz.', ['Aktif öğrenci olmak', 'Dönemde en az bir atölyeye katılmak', 'Fikir yarışmasında ekip ya da izleyici olarak yer almak'], 'guk_girisim'],
    ['c03', 'Doğa Sporları ve Dağcılık Kulübü', 'k03', 'mountain', 'bordeaux', 231, true, true, 'Burak Şahin', 'Doç. Dr. Hakan Yalçın', 2010, "Zigana'dan Kaçkarlar'a, doğayı güvenle keşfediyoruz.", 'Doğa yürüyüşleri, kamp, temel dağcılık ve ilk yardım eğitimleriyle doğayı güvenli ve sürdürülebilir biçimde deneyimliyoruz. Her seviyeye uygun rotalar planlıyor, ekipman paylaşım havuzu işletiyoruz. Güvenlik kurallarına uymak herkes için zorunludur.', ['Sağlık beyanı formunu doldurmak', 'Temel ekipmana (bot, mont) sahip olmak ya da havuzdan ödünç almak', 'Güvenlik eğitimine katılmak', '18 yaşını doldurmuş olmak'], 'guk_doga'],
    ['c04', 'Maden ve Yer Bilimleri Topluluğu', 'k02', 'pickaxe', 'slate', 98, true, true, 'Emre Doğan', 'Prof. Dr. Nurten Kılıç', 2008, 'Yerin altını anlamak, üstünü korumak.', 'Maden, jeoloji ve harita mühendisliği öğrencilerini bir araya getiriyoruz. Teknik geziler, müze ziyaretleri ve sektör söyleşileriyle sahayı kampüse taşıyoruz.', ['Mühendislik fakültesi öğrencisi olmak', 'Teknik gezilerde güvenlik kurallarına uymak', 'Dönemde bir seminere katılmak'], 'guk_yerbilim'],
    ['c05', 'Tiyatro Kulübü', 'k04', 'drama', 'red', 74, true, false, 'Ceren Uslu', 'Dr. Öğr. Üyesi Gül Erten', 2012, 'Sahne herkesin.', 'Her dönem bir oyun sahneliyoruz; oyunculuk, sahne tasarımı, ışık ve kostüm ekiplerinde herkese yer var. Yeni dönem seçmeleri Kasım ayında yapılacak; o zamana kadar başvurular kapalı.', ['Seçme gününe katılmak', 'Haftada iki prova için zaman ayırmak', 'Sahne arkası görevlerine açık olmak'], 'guk_tiyatro'],
    ['c06', 'Müzik ve Sahne Sanatları Kulübü', 'k04', 'music', 'bordeaux', 120, true, true, 'Kaan Erdem', 'Öğr. Gör. Sinan Bulut', 2014, 'Kampüsün sesi.', 'Açık mikrofon geceleri, jam seansları ve dönem sonu konseriyle müziği kampüsün her köşesine taşıyoruz. Enstrüman çalmak şart değil; dinleyici ve organizasyon ekibi de kulübün parçası.', ['Haftalık provaya düzenli katılmak', 'Ortak kullanılan ekipmana özen göstermek', 'Dönem sonu konserinde görev almak'], 'guk_muzik'],
    ['c07', 'Fotoğraf ve Sinema Kulübü', 'k08', 'camera', 'slate', 88, false, true, 'Yağmur Tan', 'Dr. Öğr. Üyesi Pınar Aydemir', 2016, 'Kadrajı birlikte kuruyoruz.', 'Fotoğraf yürüyüşleri, portre atölyeleri ve kısa film gösterimleri düzenliyoruz. Telefonla çekenler de kulübe aynı derecede hoş geldi; önemli olan bakış.', ['Çekimlerde izin kurallarına uymak', 'Kulüp albümüne dönemde en az bir fotoğraf eklemek'], 'guk_fotograf'],
    ['c08', 'Havacılık ve Uzay Teknolojileri Kulübü', 'k01', 'rocket', 'red', 112, true, true, 'Oğuz Karaca', 'Doç. Dr. Ali Rıza Tuna', 2019, 'Gökyüzü sınır değil.', 'Model roket, insansız hava aracı ve uydu projeleri geliştiriyoruz. Ekipler mekanik, elektronik ve yazılım alt gruplarına ayrılır; her dönem bir fırlatma günü yapılır.', ['Güvenlik brifingine katılmak', 'Bir alt grupta görev almak', 'Atölye kurallarına uymak'], 'guk_havacilik'],
    ['c09', 'Satranç ve Zekâ Oyunları Kulübü', 'k07', 'puzzle', 'bordeaux', 65, false, true, 'Mina Özer', 'Öğr. Gör. Cem Başaran', 2011, 'Her hamle bir ders.', 'Haftalık blitz akşamları, dönemlik turnuvalar ve zekâ oyunları atölyeleri düzenliyoruz. Başlangıç seviyesinden ustaya herkese açığız.', ['Fair-play kurallarına uymak', 'Turnuva kayıtlarına zamanında gelmek'], 'guk_satranc'],
    ['c10', 'E-Spor Kulübü', 'k07', 'gamepad-2', 'slate', 204, true, true, 'Arda Polat', 'Dr. Öğr. Üyesi Tuba Yaman', 2020, 'Takım ol, yarış, eğlen.', 'Kampüs ligi, izleme partileri ve takım antrenmanlarıyla rekabetçi ve eğlenceli bir e-spor topluluğu kuruyoruz. Oyuncu olmayanlar yayın ve organizasyon ekibinde yer alabilir.', ['Takım disiplinine uymak', 'Lig haftalarında antrenmanlara katılmak', 'Topluluk kurallarını kabul etmek'], 'guk_espor'],
    ['c11', 'Gönüllülük ve Sosyal Sorumluluk Kulübü', 'k05', 'heart-handshake', 'red', 157, true, true, 'Nehir Koç', 'Doç. Dr. Elvan Sönmez', 2013, 'Küçük adımlar, büyük etki.', 'Barınak ziyaretleri, köy okulu kütüphane projeleri ve bağış kampanyalarıyla kampüsün sosyal sorumluluk gücünü bir araya getiriyoruz. Herkesin ayırabileceği bir saati değerli buluyoruz.', ['Dönemde en az bir etkinlikte görev almak', 'Gönüllülük ilkelerini kabul etmek'], 'guk_gonullu'],
    ['c12', 'Kitap ve Edebiyat Kulübü', 'k04', 'book-open', 'bordeaux', 59, false, true, 'Ece Sezer', 'Prof. Dr. Mehmet Ali Özkan', 2017, 'Birlikte okuyor, birlikte yazıyoruz.', 'Aylık okuma buluşmaları, hikâye atölyeleri ve yazar söyleşileri düzenliyoruz. Okumayı sevmek yeterli; yazmak isteyenlere atölyelerde yer var.', ['Aylık buluşma kitabını okumaya çalışmak', 'Tartışmalarda saygılı bir dil kullanmak'], 'guk_kitap'],
    ['c13', 'Yerel Kültür ve Halk Oyunları Kulübü', 'k04', 'users-round', 'slate', 133, true, true, 'Tolga Gündüz', 'Öğr. Gör. Fatma Çiçek', 2009, 'Karadeniz ritmi kampüste.', 'Horon başta olmak üzere yöresel halk oyunlarını öğreniyor, bahar şenliği ve il dışı festivallerde sahne alıyoruz. Deneyim şart değil; ritim duygusu provada gelişir.', ['Haftalık provalara düzenli katılmak', 'Gösteri ekibi için seçmelere girmek (isteğe bağlı)', 'Kostümlere özen göstermek'], 'guk_halkoyun'],
    ['c14', 'Kariyer ve Mezunlar Kulübü', 'k06', 'briefcase', 'red', 91, true, true, 'Hande Tekin', 'Dr. Öğr. Üyesi Okan Yurt', 2021, 'Mezunlarla köprü kuruyoruz.', 'Mezun buluşmaları, CV atölyeleri ve staj günleri düzenliyoruz. Kulüp, kampüs yönetimi tarafından geçici olarak askıya alınmıştır.', ['Aktif öğrenci olmak', 'Mezun ağı kurallarına uymak'], 'guk_kariyer'],
  ];

  const EVENT_TABLE = [
    // id, clubId, title, type, dayOff, hh, mm, durH, placeId, capacity, registered, visibility, status, extra
    ['e01', 'c01', 'Yapay Zekâya Giriş Atölyesi', 'egitim', 1, 18, 0, 2, 'pl04', 40, 36, 'public', 'published', {}, 'Makine öğrenmesinin temel kavramlarını uygulamalı olarak ele alıyoruz. Bilgisayarınızı getirin; kurulum adımlarını birlikte yapacağız. Önceden kodlama bilgisi gerekmez.'],
    ['e02', 'c01', 'Hackathon Hazırlık Buluşması', 'sosyal', 3, 19, 0, 2, 'pl06', 60, 22, 'members', 'published', {}, 'Güz Hackathon’u için ekip kurma ve fikir eşleştirme buluşması. Mentorlar da orada olacak; ekipsiz gelenleri eşleştireceğiz.'],
    ['e03', 'c03', 'Zigana Yolu Doğa Yürüyüşü', 'gezi', 5, 8, 0, 8, 'pl09', 30, 30, 'public', 'published', { waitlist: 4 }, 'Orta zorlukta, yaklaşık 12 km’lik rota. Su, mevsimlik mont ve yürüyüş ayakkabısı şart. Öğle yemeği için kumanya getirin; dönüş 16:00 civarı.'],
    ['e04', 'c02', 'Girişimci Sohbetleri: İlk Müşteri', 'konferans', 2, 17, 30, 1.5, 'pl02', 120, 74, 'public', 'published', {}, 'Konuğumuz ilk müşterisini nasıl bulduğunu ve ilk yılında neleri yanlış yaptığını anlatacak. Sonunda soru-cevap bölümü var.'],
    ['e05', 'c04', 'Maden Müzesi Teknik Gezisi', 'gezi', 9, 9, 0, 6, 'pl09', 45, 40, 'members', 'published', {}, 'Servisle gidip döneceğiz. Müze turu ve ardından bölge jeolojisi üzerine kısa bir saha anlatımı yapılacak. Öğle yemeği dahil değildir.'],
    ['e06', 'c06', 'Açık Mikrofon Gecesi', 'sosyal', 4, 20, 0, 3, 'pl05', 150, 61, 'public', 'published', {}, 'Sahne herkese açık: şarkı, enstrümantal, şiir ya da stand-up. Sahne sırası için kayıt sırasında “performans” kutusunu işaretleyin.'],
    ['e07', 'c07', 'Karadeniz Fotoğraf Yürüyüşü', 'gezi', 6, 10, 0, 3, 'pl10', 25, 14, 'public', 'published', {}, 'Sisli sabah ışığında şehir ve doğa fotoğrafçılığı. Telefonla katılım serbest; rota yaklaşık 5 km.'],
    ['e08', 'c09', 'Satranç Turnuvası: Güz Kupası', 'yarisma', 7, 13, 0, 5, 'pl07', 32, 28, 'public', 'published', {}, 'İsviçre sistemi, 5 tur, 15+10 tempo. Kontenjan 32 kişi; ilk üçe kupa ve kitap hediyesi.'],
    ['e09', 'c10', 'E-Spor Kampüs Ligi — Eleme', 'yarisma', 8, 18, 0, 4, 'pl04', 64, 64, 'public', 'published', { waitlist: 0 }, 'Lig elemeleri 64 oyuncuyla başlıyor. Takım kaptanları 17:30’da kayıt masasında olsun.'],
    ['e10', 'c11', 'Gönüllülük Günü: Barınak Ziyareti', 'sosyal', 10, 11, 0, 4, 'pl09', 35, 20, 'public', 'published', {}, 'Barınakta temizlik, besleme ve yürüyüş desteği vereceğiz. Eski kıyafet ve kapalı ayakkabıyla gelin.'],
    ['e11', 'c12', 'Edebiyat Kafe: Hikâye Atölyesi', 'egitim', 11, 16, 0, 2, 'pl06', 20, 9, 'members', 'published', {}, 'Karakter kurma ve diyalog yazımı üzerine iki oturumluk atölye. Ön okuma listesi kulüp sürücüsünde.'],
    ['e12', 'c13', 'Horon Çalıştayı', 'egitim', 12, 17, 0, 2, 'pl08', 80, 52, 'public', 'published', {}, 'Temel horon adımlarını öğreniyoruz. Deneyim gerekmez; rahat ayakkabı yeterli.'],
    ['e13', 'c08', 'Model Roket Fırlatma Günü', 'sosyal', 14, 14, 0, 3, 'pl05', 50, 31, 'public', 'published', {}, 'Dönem boyunca üretilen model roketler fırlatılıyor. Güvenlik brifingi etkinlikten bir saat önce; brifinge katılmayan fırlatma alanına giremez.'],
    ['e14', 'c05', 'Tiyatro Oyunu: Kapalı Gişe', 'sosyal', 16, 20, 0, 2, 'pl01', 200, 188, 'public', 'published', {}, 'Kulübümüzün dönem oyunu. Kapılar 19:30’da açılır; oyun başladıktan sonra salona giriş yapılamaz.'],
    ['e15', 'c02', 'Kariyer Günleri Söyleşisi', 'konferans', 18, 10, 0, 3, 'pl01', 100, 40, 'public', 'published', {}, 'Mezun konuklar kendi sektörlerindeki ilk yıllarını anlatıyor. Söyleşi sonrası kısa networking molası.'],
    ['e16', 'c03', 'Dağcılık Temel Eğitimi', 'egitim', 20, 9, 0, 6, 'pl08', 25, 11, 'members', 'published', {}, 'Düğümler, emniyet sistemleri ve ekipman bilgisi. Sağlık beyanı formu zorunlu; ekipmanı olmayanlar havuzdan ödünç alabilir.'],
    ['e17', 'c01', 'Veri Bilimi Söyleşisi', 'konferans', 0, 19, 30, 1.5, 'pl03', 80, 52, 'public', 'published', {}, 'Bir e-ticaret şirketinin veri ekibinden konuğumuzla veri bilimi kariyeri üzerine sohbet. Soru-cevap için zaman ayırdık.'],
    ['e18', 'c01', 'Açılış Tanışma Toplantısı', 'sosyal', -6, 18, 0, 2, 'pl03', 70, 64, 'members', 'published', {}, 'Dönemin ilk buluşması: kulüp tanıtımı, ekipler ve yıllık takvim.'],
    ['e19', 'c03', 'Sonbahar Kampı', 'gezi', -12, 9, 0, 30, 'pl09', 40, 38, 'public', 'published', {}, 'İki gecelik kamp. Çadır ve uyku tulumu havuzdan temin edilebilir.'],
    ['e20', 'c07', 'Portre Fotoğrafçılığı Atölyesi', 'egitim', -4, 15, 0, 3, 'pl06', 20, 18, 'public', 'published', {}, 'Doğal ışıkta portre çekimi ve basit düzenleme.'],
    ['e21', 'c07', 'Açık Hava Sinema Gecesi', 'sosyal', 5, 21, 0, 2.5, 'pl10', 100, 47, 'public', 'cancelled', { cancelReason: 'weather' }, 'Meydanda açık hava film gösterimi. Battaniyenizi getirin.'],
    ['e22', 'c03', 'Kış Kampı Planlama', 'sosyal', 25, 10, 0, 2, null, null, 0, 'members', 'draft', {}, 'Kış kampı tarih ve rota planlaması için açık toplantı.'],
  ];

  const POST_TABLE = [
    // id, clubId, type, dayOff(negative), hourOff, title, text, images, pinned, pollInfo
    ['p01', 'c01', 'announcement', -12, 10, 'Güz Hackathon’u için ekip kurma haftası başlıyor', 'Bu hafta içinde 4 kişilik ekibini kur. Perşembe günkü hazırlık buluşmasına gelmen yeterli; yeni başlayanlar için mentor desteği olacak.', 0, true],
    ['p02', 'c01', 'post', -9, 20, null, 'Dünkü Yapay Zekâya Giriş atölyesinden kareler! Katılan herkese teşekkürler. Bir sonrakinde birlikte model eğiteceğiz.', 2, false],
    ['p03', 'c01', 'post', 0, -5, null, 'Veri Bilimi Söyleşisi bu akşam 19.30’da Amfi-1’de. Konuğumuz bir e-ticaret şirketinin veri ekibinden; soru-cevap için zaman ayırdık.', 0, false],
    ['p04', 'c01', 'poll', -1, 14, null, 'Hackathon teması ne olsun?', 0, false, { options: ['Kampüs hayatı', 'Sürdürülebilirlik', 'Sağlık', 'Eğitim teknolojileri'], days: 3, votes: 41 }],
    ['p05', 'c01', 'post', -3, 11, null, 'Mentor listesi güncellendi. Python, Flutter ve veri tarafında toplam 9 mentorumuz var; ilk buluşmada eşleştirme yapacağız.', 0, false],
    ['p06', 'c01', 'post', -15, 16, null, 'Kulüp odasındaki ekipman dolabı yeniden düzenlendi. Raspberry Pi ve sensör kitleri ödünç alınabilir; defteri doldurmayı unutmayın.', 1, false],
    ['p07', 'c01', 'post', -2, 9, null, 'Hackathon kayıt formu açıldı.', 0, false],
    ['p08', 'c03', 'announcement', -2, 18, 'Zigana yürüyüşü toplanma bilgisi', 'Cumartesi Zigana yürüyüşü için toplanma saati 08:00, ana girişte. Su, mevsimlik mont ve yürüyüş ayakkabısı şart. Kontenjan dolduğu için bekleme listesi açıldı.', 0, true],
    ['p09', 'c03', 'poll', -1, 12, null, 'Kış kampı için hangi tarih uygun?', 0, false, { options: ['6–7 Aralık', '13–14 Aralık', '20–21 Aralık'], days: 3, votes: 74 }],
    ['p10', 'c03', 'post', -11, 19, null, 'Sonbahar kampından kareler. 38 kişi, iki gece, sıfır sorun. Emeği geçen herkese teşekkürler.', 3, false],
    ['p11', 'c03', 'post', -4, 13, null, 'Dağcılık Temel Eğitimi için kayıtlar açıldı. Eğitim iki hafta sonu sürecek: ilk hafta sonu düğümler, emniyet ve ekipman bilgisi; ikinci hafta sonu kampüs yakınındaki kaya bahçesinde uygulama. Katılım için sağlık beyanı formu zorunlu. Ekipmanı olmayanlar kulüp havuzundan ödünç alabilir; sayı sınırlı olduğu için kayıt sırasına göre dağıtılacak. Sorularınız için yorumlara yazabilirsiniz.', 0, false],
    ['p12', 'c03', 'post', -6, 10, null, 'Bu hafta ekipman bakım günü. Cuma 16:00, kulüp odası.', 0, false],
    ['p13', 'c03', 'post', -20, 15, null, 'Yürüyüş fotoğraflarını paylaşmak isteyenler kulüp e-postasına gönderebilir; en iyileri kulüp panosunda sergilenecek.', 1, false],
    ['p14', 'c02', 'post', -1, 9, null, 'Bu haftaki konuğumuz ilk müşterisini nasıl bulduğunu anlatacak. Sorularını yorumlara bırak, sunum sırasında yanıtlayalım.', 0, false],
    ['p15', 'c02', 'announcement', -5, 11, 'Kariyer Günleri Söyleşisi için kayıt başladı', 'Söyleşi Kongre Merkezi Salon A’da. Mezun konuklarımız kendi sektörlerinden deneyimlerini aktaracak; sonrasında kısa bir networking molası var.', 0, true],
    ['p16', 'c02', 'post', -8, 14, null, 'Fikir yarışması başvuruları için son 10 gün. Ekip olmak zorunda değilsiniz; tek kişilik başvurular da kabul ediliyor.', 0, false],
    ['p17', 'c02', 'post', -12, 17, null, 'Geçen haftaki iş modeli atölyesinin sunumu kulüp sürücüsünde.', 0, false],
    ['p18', 'c06', 'poll', -9, 18, null, 'Açık mikrofon gecesinde en çok hangi türü görmek istersin?', 0, false, { options: ['Pop', 'Rock', 'Halk müziği', 'Enstrümantal'], days: 7, votes: 58, ended: true }],
    ['p19', 'c06', 'announcement', -3, 12, 'Açık Mikrofon Gecesi sahne sırası', 'Kayıt yaptıranlara sahne sırası e-posta ile gönderildi. Prova için Çarşamba 18:00’de Açık Hava Sahnesi’ndeyiz; enstrümanını getirmeyi unutma.', 0, true],
    ['p20', 'c06', 'post', -14, 20, null, 'Yeni prova odamız hazır. Perşembe akşamları 19:00–21:00 arası herkese açık jam seansı.', 1, false],
    ['p21', 'c07', 'post', -5, 8, null, 'Karadeniz sisinde sabah yürüyüşü. Haftaya aynı rotada fotoğraf yürüyüşü yapıyoruz.', 3, false],
    ['p22', 'c07', 'announcement', -1, 16, 'Açık Hava Sinema Gecesi iptal edildi', 'Hava koşulları nedeniyle Açık Hava Sinema Gecesi iptal edildi. Yeni tarih belirlenince duyuracağız; kayıtlılara bildirim gitti.', 0, true],
    ['p23', 'c07', 'post', -3, 15, null, 'Portre atölyesinde çekilen fotoğraflar kulüp albümüne eklendi. Modellik yapan arkadaşlara teşekkürler!', 2, false],
    ['p24', 'c07', 'post', -10, 19, null, 'Cuma akşamı kısa film gösterimi, kulüp odası.', 0, false],
    ['p25', 'c09', 'announcement', -4, 10, 'Güz Kupası kayıtları açıldı!', '32 kişilik kontenjan, İsviçre sistemi, 5 tur.', 0, true],
    ['p26', 'c09', 'post', -7, 17, null, 'Haftalık blitz akşamı bu Salı 18:00’de kütüphane çalışma salonunda. Saat ve tahta getirmenize gerek yok.', 0, false],
    ['p27', 'c11', 'post', -2, 12, null, 'Barınak ziyaretimiz için ihtiyaç listesi: mama, battaniye, temizlik malzemesi. Getirebilenler Cuma gününe kadar kulüp odasına bıraksın.', 0, false],
    ['p28', 'c11', 'announcement', -6, 9, 'Kan bağışı günü', 'Bağış ekibi Perşembe 10:00–16:00 arasında Kongre Merkezi önünde olacak. Bağış öncesi kahvaltı yapmayı unutmayın.', 0, true],
    ['p29', 'c11', 'post', -13, 14, null, 'Köy okulu kütüphane projesinde 400 kitap topladık. Hedefimiz 1000; bağış kutuları fakülte girişlerinde.', 1, false],
    ['p30', 'c13', 'post', -3, 18, null, 'Horon çalıştayında temel adımları öğreneceğiz. Kıyafet şartı yok, rahat bir ayakkabı yeterli.', 0, false],
    ['p31', 'c13', 'announcement', -9, 11, 'Bahar şenliği gösteri ekibi', 'Gösteri ekibi seçmeleri iki hafta sonra. Düzenli prova katılımı şart; ayrıntılar provada.', 0, true],
    ['p32', 'c04', 'post', -2, 16, null, 'Maden Müzesi gezisi için servis listesi kesinleşti; kayıt yaptıranlar e-postalarını kontrol etsin.', 0, false],
    ['p33', 'c05', 'post', -4, 21, null, 'Kapalı Gişe provalarından bir kare. Prömiyere iki hafta kaldı, biletler hızla tükeniyor.', 1, false],
    ['p34', 'c08', 'announcement', -3, 13, 'Model Roket Fırlatma Günü güvenlik brifingi', 'Fırlatma günü katılacak herkes için güvenlik brifingi zorunlu. Brifing, etkinlikten bir saat önce Açık Hava Sahnesi’nde.', 0, false],
    ['p35', 'c10', 'poll', -2, 19, null, 'Kampüs Ligi’nde hangi oyun ana branş olsun?', 0, false, { options: ['Taktik nişancı', 'MOBA', 'Spor simülasyonu'], days: 7, votes: 112 }],
    ['p36', 'c12', 'post', -6, 15, null, 'Hikâye Atölyesi için ön okuma listesi: üç kısa öykü ve bir deneme. Metinler kulüp sürücüsünde; atölyeye gelmeden önce en az ikisini okumuş olmanız tartışmayı zenginleştirir. İlk oturumda karakter kurma üzerine konuşacağız, ikinci oturumda kendi metinlerinizi masaya yatıracağız.', 0, false],
  ];

  const COMMENT_TABLE = [
    ['p01', 'm', 'Ekip arayan var mı? Flutter tarafına bakabilirim.', 30], ['p01', 'm', 'Yeni başlayanlar için mentor desteği olması çok iyi, teşekkürler.', 26], ['p01', 'b', 'Perşembe buluşmasında ekipsiz gelenleri eşleştireceğiz, merak etmeyin.', 20],
    ['p02', 'm', 'Harika olmuş, teşekkürler!', 18], ['p02', 'm', 'Bir sonraki atölye ne zaman?', 16], ['p02', 'b', 'Takvime eklendi; yarın akşam Bilgisayar Lab-2’de.', 12],
    ['p03', 'm', 'Kontenjan dolmadan kayıt olabilir miyiz?', 3], ['p03', 'b', 'Evet, Etkinlikler sekmesinden kayıt olabilirsiniz; şu an yer var.', 2],
    ['p08', 'm', 'Yürüyüş ayakkabım yok, spor ayakkabıyla olur mu?', 40], ['p08', 'b', 'Zigana rotasının son kısmı taşlık ve ıslak olabiliyor; spor ayakkabı bileği korumaz. Kulüp havuzunda 38–44 numara arası birkaç bot var, Cuma 16:00’da kulüp odasına uğrarsanız ölçüp verebiliriz. Mümkünse yanınıza bir yedek çorap da alın.', 36],
    ['p09', 'm', '13–14 Aralık sınav haftasına denk geliyor galiba.', 20], ['p09', 'm', 'Bence 6–7 Aralık, kar henüz yoğun değil.', 15],
    ['p11', 'm', 'Sağlık formunu nereden bulabiliriz?', 80], ['p11', 'b', 'Kulüp odasında basılı hali var, ayrıca e-posta ile de gönderebiliriz.', 70],
    ['p14', 'm', 'Konuğumuz ilk yılında kaç müşteriye ulaşmış, bunu sormak istiyorum.', 10], ['p14', 'm', 'Fiyatlandırmayı nasıl belirlediğini merak ediyorum.', 6],
    ['p19', 'm', 'Prova saati biraz erken değil mi? Dersim 18:30’da bitiyor.', 60], ['p19', 'b', 'Geç gelenler için 19:15’te ikinci tur var.', 50],
    ['p21', 'm', 'Sis fotoğrafları çok iyi çıkmış.', 100], ['p21', 'm', 'Haftaya ben de geliyorum, lens tavsiyesi var mı?', 90], ['p21', 'b', '35 mm gibi geniş bir odak sisli sabahlar için ideal; telefon da yeterli.', 80],
    ['p25', 'm', 'İsviçre sistemi nedir, ilk kez katılacağım.', 70], ['p25', 'b', 'Her turda puanı eşit olanlar eşleşir; kimse elenmez, 5 tur oynarsınız.', 60], ['p25', 'x', 'Bu kadar basit bir soruyu sormadan önce aramayı dene.', 55],
    ['p27', 'm', 'Battaniye getirebilirim, nereye bırakayım?', 30], ['p27', 'b', 'Kulüp odası, Kulüpler Binası 2. kat; Cuma 17:00’ye kadar.', 24],
    ['p30', 'm', 'Daha önce hiç oynamadım, sorun olur mu?', 50], ['p30', 'b', 'Temel adımlardan başlıyoruz, hiç sorun değil.', 44],
    ['p32', 'm', 'Servis saat kaçta kalkıyor?', 20], ['p32', 'b', '08:45’te ana girişten.', 14],
    ['p33', 'm', 'Biletler nereden alınıyor?', 60], ['p33', 'b', 'Etkinlik sayfasından kayıt yeterli, ücretsiz.', 50],
    ['p34', 'm', 'Brifing kaç dakika sürüyor?', 40], ['p34', 'b', 'Yaklaşık 20 dakika.', 30],
    ['p35', 'm', 'Spor simülasyonuna oy verdim, turnuva formatı nasıl olacak?', 30], ['p35', 'b', 'Eleme sonrası çift eleme formatı planlıyoruz.', 20],
    ['p36', 'm', 'Okuma listesindeki deneme hangi yazara ait?', 90], ['p36', 'b', 'Kulübümüzden bir arkadaşın yazdığı kurgusal bir metin; sürücüde.', 80],
    ['p10', 'm', 'Bir dahaki kampta ben de varım.', 200], ['p06', 'm', 'Sensör kitlerinden kaç tane var?', 300], ['p06', 'b', 'Üç kit var; defterde görebilirsiniz.', 290],
  ];

  const APPLICATION_NOTES_LONG = [
    'Birinci sınıf öğrencisiyim ve lise yıllarımda okul dağcılık takımındaydım. Üniversitede de doğa sporlarına devam etmek, özellikle kış kamplarında deneyim kazanmak istiyorum. Temel ekipmanım var; ilk yardım sertifikam da bulunuyor. Kulübün ekipman havuzuna gönüllü bakım desteği de verebilirim.',
    'Jeoloji okuyorum ve arazi çalışmalarını çok seviyorum. Uzun yürüyüşlere alışkınım, grup disiplinine önem veririm. Kulüpte fotoğraf çekmeyi de severim; sosyal medya ekibine yardımcı olabilirim. Hafta sonları tamamen müsaitim.',
    'Bilgisayar mühendisliği ikinci sınıftayım. İki yıldır Python ile uğraşıyorum, geçen yaz bir stajda veri analizi yaptım. Hackathon ekibinde yer almak ve yeni başlayanlara mentorluk yapmak isterim.',
  ];
  const APPLICATION_NOTES_SHORT = ['Doğayı çok seviyorum, katılmak isterim.', 'Arkadaşım üye, çok memnun; ben de katılmak istiyorum.', 'Hafta sonu yürüyüşlerine katılmak istiyorum.', 'Yeni başlıyorum, öğrenmeye açığım.', 'Kamp deneyimim var, ekipmanım tam.', 'Yazılıma ilgim var, projelerde yer almak isterim.', 'Veri bilimi alanında kendimi geliştirmek istiyorum.', 'Hackathon’a katılmak için başvuruyorum.', 'Girişimcilik fikrim var, ekip arıyorum.', 'Takım oyunlarında iyiyim, lige katılmak istiyorum.'];

  function seed() {
    const rng = rngFor('gu-kulupler-seed-v' + SEED_VERSION);
    const pick = (arr) => arr[Math.floor(rng() * arr.length)];
    const shuffle = (arr) => { const a = arr.slice(); for (let i = a.length - 1; i > 0; i--) { const j = Math.floor(rng() * (i + 1)); [a[i], a[j]] = [a[j], a[i]]; } return a; };
    const rint = (a, b) => a + Math.floor(rng() * (b - a + 1));
    const now = Date.now();

    /* users */
    const users = {}; const usedEmails = new Set();
    const mkEmail = (name, domain = 'ogr.gumushane.edu.tr') => { const base = slug(name).replace(/-/g, '.'); let e = `${base}@${domain}`; let i = 2; while (usedEmails.has(e)) { e = `${base}${i++}@${domain}`; } usedEmails.add(e); return e; };
    const addUser = (id, name, o = {}) => { users[id] = { id, name, email: o.email || mkEmail(name, o.domain), department: o.department || pick(DEPARTMENTS).id, year: o.year || pick(YEARS.slice(1, 5)), interests: o.interests || shuffle(INTERESTS).slice(0, rint(1, 4)).map((i) => i.id), avatarSeed: id, blocked: [], status: o.status || 'active', emailVerified: o.emailVerified !== false, profileComplete: o.profileComplete !== false, bio: o.bio || '', staff: !!o.staff, global: o.global || null, createdAt: now - rint(10, 700) * DAY }; return users[id]; };
    addUser('u_ayse', 'Ayşe Demir', { department: 'd01', year: '1', interests: ['i01', 'i02', 'i03', 'i04', 'i06'], bio: 'Yeni başlayan bir bilgisayarcı. Doğa ve kahve.' });
    addUser('u_mehmet', 'Mehmet Kaya', { department: 'd02', year: '3', interests: ['i01', 'i06', 'i07', 'i11'], bio: 'Yazılım ve fotoğraf. Satranca yeni başladım.' });
    addUser('u_elif', 'Elif Yıldız', { department: 'd01', year: '4', interests: ['i01', 'i02', 'i03'], bio: 'Yazılım kulübü yönetim kurulu. Flutter ve kahve.' });
    addUser('u_burak', 'Burak Şahin', { department: 'd05', year: '4', interests: ['i04', 'i05', 'i01'], bio: 'Doğa Sporları Kulübü başkanı. Rotalar, kamplar, güvenlik.' });
    addUser('u_zeynep', 'Dr. Öğr. Üyesi Zeynep Arslan', { domain: 'gumushane.edu.tr', email: 'zeynep.arslan@gumushane.edu.tr', department: 'd01', year: 'phd', interests: ['i01', 'i02', 'i03'], staff: true, bio: 'Bilgisayar Mühendisliği öğretim üyesi; iki kulübün danışmanı.' });
    addUser('u_admin', 'Kampüs Yönetimi', { domain: 'gumushane.edu.tr', email: 'admin@gumushane.edu.tr', department: 'd16', year: 'master', interests: [], staff: true, global: 'superadmin', bio: 'Sağlık, Kültür ve Spor Daire Başkanlığı — öğrenci kulüpleri birimi.' });
    addUser('u_unverified', 'Deneme Kullanıcı', { email: 'unverified@ogr.gumushane.edu.tr', department: 'd10', year: '1', emailVerified: false, profileComplete: false });
    addUser('u_suspended', 'Askıdaki Kullanıcı', { email: 'suspended@ogr.gumushane.edu.tr', department: 'd17', year: '2', status: 'suspended' });
    addUser('u_cem', 'Cem Aydın', { department: 'd03', year: '2', interests: ['i04', 'i05'] });
    addUser('u_long', 'Muhammed Burak Yıldırım Arslanoğlu', { department: 'd05', year: '1', interests: ['i04', 'i05', 'i13'] });
    addUser('u_deniz', 'Deniz', { department: 'd23', year: '2', interests: ['i06', 'i07'] });
    const PRESIDENT_IDS = {}; const ADVISOR_IDS = {};
    CLUB_TABLE.forEach(([cid, , , , , , , , pres, adv]) => {
      if (pres === 'Burak Şahin') PRESIDENT_IDS[cid] = 'u_burak';
      else { const id = 'u_p_' + cid; addUser(id, pres, { year: pick(['3', '4']) }); PRESIDENT_IDS[cid] = id; }
      if (adv === 'Zeynep Arslan') ADVISOR_IDS[cid] = 'u_zeynep';
      else { const id = 'u_a_' + cid; addUser(id, adv, { domain: 'gumushane.edu.tr', year: 'phd', staff: true }); ADVISOR_IDS[cid] = id; }
    });
    const pool = [];
    for (let i = 1; i <= 190; i++) { const id = 'u' + String(i).padStart(3, '0'); addUser(id, `${pick(FIRST)} ${pick(LAST)}`); pool.push(id); }
    users.u007.status = 'suspended'; // resolved report → suspended user
    users.u_mehmet.blocked = ['u042'];

    /* clubs */
    const clubs = {};
    CLUB_TABLE.forEach(([id, name, categoryId, iconName, palette, memberCount, approvalRequired, applicationsOpen, , , founded, summary, about, conditions, ig], idx) => {
      clubs[id] = { id, name, categoryId, iconName, coverSeed: 'club-' + id, palette, pattern: GU.PATTERNS[idx % 4], memberCount, approvalRequired, applicationsOpen, requireNote: id === 'c03' || id === 'c01', founded, summary, about, conditions, social: { email: `${ig.replace('guk_', '')}@gumushane.edu.tr`, instagram: '@' + ig, web: `https://kulupler.gumushane.edu.tr/${ig.replace('guk_', '')}` }, presidentId: PRESIDENT_IDS[id], advisorId: ADVISOR_IDS[id], status: id === 'c14' ? 'suspended' : 'active', suspendReason: id === 'c14' ? 'Dönem raporu teslim edilmedi; evrak tamamlanınca yeniden etkinleştirilecek.' : null, createdAt: now - rint(60, 900) * DAY };
    });

    /* memberships */
    const memberships = {}; const mkey = (c, u) => `${c}_${u}`;
    const addM = (clubId, userId, status, role, extra = {}) => { memberships[mkey(clubId, userId)] = { clubId, userId, status, role, note: '', appliedAt: null, decidedAt: null, decidedBy: null, retryAfter: null, rejectReason: null, stale: false, priorCount: 0, ...extra }; };
    const MEMBER_TARGET = { c01: 70, c02: 30, c03: 14, c04: 45, c05: 20, c06: 25, c07: 22, c08: 20, c09: 15, c10: 40, c11: 28, c12: 12, c13: 24, c14: 10 };
    const BOARD = {}; const MEMBERS = {};
    Object.keys(clubs).forEach((cid) => {
      const club = clubs[cid]; const shuffled = shuffle(pool.filter((u) => users[u].status === 'active'));
      const boardN = rint(4, 6); const board = shuffled.slice(0, boardN); const members = shuffled.slice(boardN, boardN + MEMBER_TARGET[cid]);
      BOARD[cid] = board; MEMBERS[cid] = members;
      const joined = (daysAgo) => ({ appliedAt: now - (daysAgo + 2) * DAY, decidedAt: now - daysAgo * DAY, decidedBy: club.presidentId });
      addM(cid, club.presidentId, 'active', 'president', joined(rint(200, 600)));
      addM(cid, club.advisorId, 'active', 'advisor', joined(rint(200, 600)));
      board.forEach((u) => addM(cid, u, 'active', 'board', joined(rint(60, 400))));
      members.forEach((u) => addM(cid, u, 'active', 'member', joined(rint(1, 240))));
    });
    // named accounts
    const joinedAgo = (cid, d, by) => ({ appliedAt: now - (d + 2) * DAY, decidedAt: now - d * DAY, decidedBy: by || clubs[cid].presidentId });
    addM('c01', 'u_mehmet', 'active', 'member', joinedAgo('c01', 140)); addM('c07', 'u_mehmet', 'active', 'member', joinedAgo('c07', 60));
    addM('c06', 'u_mehmet', 'pending', 'member', { appliedAt: now - 2 * DAY, note: 'Gitar çalıyorum, jam seanslarına katılmak istiyorum.' });
    addM('c05', 'u_mehmet', 'rejected', 'member', { appliedAt: now - 9 * DAY, decidedAt: now - 4 * DAY, decidedBy: clubs.c05.presidentId, retryAfter: now + 3 * DAY, rejectReason: 'quota', note: 'Sahne arkasında görev almak isterim.' });
    addM('c01', 'u_elif', 'active', 'board', joinedAgo('c01', 400)); addM('c02', 'u_elif', 'active', 'member', joinedAgo('c02', 90));
    addM('c01', 'u_burak', 'active', 'member', joinedAgo('c01', 300));
    addM('c07', 'u_deniz', 'active', 'member', joinedAgo('c07', 30));
    addM('c01', 'u_zeynep', 'active', 'advisor', joinedAgo('c01', 500)); addM('c02', 'u_zeynep', 'active', 'advisor', joinedAgo('c02', 500));
    delete memberships[mkey('c03', 'u_ayse')];
    // pending applications
    const freeFor = (cid) => shuffle(pool.filter((u) => !memberships[mkey(cid, u)] && users[u].status === 'active'));
    const pend = (cid, uid, hoursAgo, note, extra = {}) => addM(cid, uid, 'pending', 'member', { appliedAt: now - hoursAgo * 36e5, note: note || '', ...extra });
    const c03free = freeFor('c03');
    pend('c03', 'u_cem', 30, 'Yürüyüş ve kamp deneyimim var; ekipmanım tam.', { stale: true });
    pend('c03', 'u_long', 50, APPLICATION_NOTES_LONG[0], { priorCount: 1 });
    pend('c03', c03free[0], 3, APPLICATION_NOTES_LONG[1]);
    pend('c03', c03free[1], 8, APPLICATION_NOTES_SHORT[0]); pend('c03', c03free[2], 20, APPLICATION_NOTES_SHORT[1], { priorCount: 1 }); pend('c03', c03free[3], 44, APPLICATION_NOTES_SHORT[2]);
    pend('c03', c03free[4], 70, ''); pend('c03', c03free[5], 96, ''); pend('c03', c03free[6], 130, '');
    const c01free = freeFor('c01');
    [2, 9, 26, 40, 60, 100].forEach((hrs, i) => pend('c01', c01free[i], hrs, i === 0 ? APPLICATION_NOTES_LONG[2] : APPLICATION_NOTES_SHORT[5 + (i % 3)]));
    const c02free = freeFor('c02'); pend('c02', c02free[0], 12, APPLICATION_NOTES_SHORT[8]); pend('c02', c02free[1], 50, '');
    const c06free = freeFor('c06'); pend('c06', c06free[0], 30, 'Davul çalıyorum.');
    const c10free = freeFor('c10'); pend('c10', c10free[0], 5, APPLICATION_NOTES_SHORT[9]); pend('c10', c10free[1], 28, ''); pend('c10', c10free[2], 55, APPLICATION_NOTES_SHORT[9]);
    const c08free = freeFor('c08'); pend('c08', c08free[0], 16, 'Elektronik alt grubunda çalışmak isterim.');
    const c13free = freeFor('c13'); pend('c13', c13free[0], 9, ''); pend('c13', c13free[1], 72, 'Lise yıllarında halk oyunları ekibindeydim.');
    // rejected (c03: 4)
    const REJ = ['quota', 'criteria', 'missing', 'other'];
    [[7, 18], [8, 12], [9, 25], [10, 5]].forEach(([i, daysAgo], k) => { const u = c03free[i]; addM('c03', u, 'rejected', 'member', { appliedAt: now - (daysAgo + 3) * DAY, decidedAt: now - daysAgo * DAY, decidedBy: 'u_burak', retryAfter: now - daysAgo * DAY + 7 * DAY, rejectReason: REJ[k], rejectNote: k === 3 ? 'Sağlık beyanı formu eksikti.' : '', note: APPLICATION_NOTES_SHORT[k] }); });
    // removed example (c01)
    addM('c01', c01free[7], 'removed', 'member', { appliedAt: now - 120 * DAY, decidedAt: now - 2 * DAY, decidedBy: 'u_elif', retryAfter: now + 5 * DAY, rejectReason: 'other', rejectNote: 'Topluluk kurallarına aykırı paylaşım.' });

    /* events + rsvps */
    const events = {}; const rsvps = {}; const rkey = (e, u) => `${e}_${u}`;
    const activeMembers = (cid) => Object.values(memberships).filter((m) => m.clubId === cid && m.status === 'active').map((m) => m.userId);
    const addR = (eventId, userId, status, extra = {}) => { rsvps[rkey(eventId, userId)] = { eventId, userId, status, reminder: '1h', createdAt: now - rint(1, 10) * DAY, scannedAt: null, ticketCode: ticketCode(eventId + ':' + userId), ...extra }; };
    EVENT_TABLE.forEach(([id, clubId, title, type, dayOff, hh, mm, durH, placeId, capacity, registered, visibility, status, extra, desc], idx) => {
      const startsAt = at(dayOff, hh, mm); const endsAt = startsAt + durH * 36e5;
      events[id] = { id, clubId, title, desc, type, startsAt, endsAt, placeId, placeText: null, capacity, visibility, status, coverSeed: 'event-' + id, coverPalette: clubs[clubId].palette, coverPattern: GU.PATTERNS[(idx + 1) % 4], cancelReason: extra.cancelReason || null, registrationOpen: true, autoReminder: true, createdAt: startsAt - rint(10, 25) * DAY, createdBy: clubs[clubId].presidentId };
      if (status === 'draft') return;
      const picks = new Set();
      // named rsvps
      const named = { e01: [['u_mehmet', 'going']], e08: [['u_mehmet', 'waitlist']], e18: [['u_mehmet', 'attended']], e20: [['u_mehmet', 'going']], e17: [['u_elif', 'going'], ['u_burak', 'going']], e02: [['u_elif', 'going']] }[id] || [];
      named.forEach(([u, st]) => { addR(id, u, st, st === 'attended' ? { scannedAt: startsAt + 10 * 6e4 } : {}); if (st !== 'waitlist') picks.add(u); });
      const candidates = shuffle((visibility === 'members' ? activeMembers(clubId) : pool.concat(Object.keys(users).filter((u) => u.startsWith('u_p_')))).filter((u) => !picks.has(u) && u !== 'u_mehmet' && u !== 'u_ayse' && users[u].status === 'active'));
      const isPast = endsAt < now; let attendedTarget = id === 'e17' ? 5 : id === 'e18' ? 50 : id === 'e19' ? 34 : id === 'e20' ? 15 : 0;
      let i = 0;
      while (picks.size < registered && i < candidates.length) { const u = candidates[i++]; let st = 'going'; if ((isPast || id === 'e17') && attendedTarget > 0) { st = 'attended'; attendedTarget--; } addR(id, u, st, st === 'attended' ? { scannedAt: startsAt + rint(0, 40) * 6e4 } : {}); picks.add(u); }
      if (extra.waitlist) { for (let w = 0; w < extra.waitlist; w++) { const u = candidates[i++]; addR(id, u, 'waitlist', { waitlistAt: now - (extra.waitlist - w) * 36e5 }); } }
    });

    /* posts, comments */
    const posts = {}; const comments = {};
    const authorOf = (cid, k) => (k === 0 ? clubs[cid].presidentId : BOARD[cid][k % BOARD[cid].length]);
    POST_TABLE.forEach(([id, clubId, type, dayOff, hourOff, title, text, imgCount, pinned, pollInfo], idx) => {
      const createdAt = at(dayOff, 12, 0) + hourOff * 36e5 - (dayOff === 0 ? 12 * 36e5 : 0);
      const audience = shuffle(activeMembers(clubId).concat(pool.slice(0, 60)));
      const likeN = Math.min(audience.length, rint(0, type === 'announcement' ? 180 : 90)); const likes = audience.slice(0, likeN);
      let poll = null;
      if (pollInfo) { const voters = shuffle(audience.filter((u) => u !== 'u_ayse' && u !== 'u_mehmet')).slice(0, pollInfo.votes); const opts = pollInfo.options.map((t, i) => ({ id: 'o' + (i + 1), text: t, votes: [] })); const weights = pollInfo.options.map(() => 0.4 + rng()); voters.forEach((v) => { let r = rng() * weights.reduce((a, b) => a + b, 0); let k = 0; while (r > weights[k] && k < weights.length - 1) { r -= weights[k]; k++; } opts[k].votes.push(v); }); poll = { options: opts, endsAt: pollInfo.ended ? now - 2 * DAY : createdAt + pollInfo.days * DAY, showResultsAfterVote: true }; }
      posts[id] = { id, clubId, authorId: authorOf(clubId, idx), type, title: title || null, text, images: Array.from({ length: imgCount }, (_, i) => `${id}-img${i + 1}`), poll, pinned, createdAt, likes, commentIds: [], pushSent: type === 'announcement', hidden: false, deleted: false, editedAt: null };
    });
    let cmN = 0;
    COMMENT_TABLE.forEach(([postId, who, text, minutesAfterish]) => {
      const p = posts[postId]; const id = 'cm' + String(++cmN).padStart(2, '0'); const members = activeMembers(p.clubId).filter((u) => !['president', 'board', 'advisor'].includes(memberships[mkey(p.clubId, u)].role));
      const authorId = who === 'b' ? authorOf(p.clubId, 1) : who === 'x' ? 'u077' : members.length ? members[(cmN * 7) % members.length] : pool[cmN];
      comments[id] = { id, postId, authorId, text, createdAt: p.createdAt + minutesAfterish * 6e4 * 3, deleted: false, hidden: false }; p.commentIds.push(id);
    });

    /* notifications */
    const notifications = {}; let nN = 0;
    const addN = (userId, type, refs, hoursAgo, read) => { const id = 'n' + String(++nN).padStart(3, '0'); notifications[id] = { id, userId, type, refs, createdAt: now - hoursAgo * 36e5, read }; return id; };
    addN('u_ayse', 'system', { textKey: 'welcome' }, 240, true); addN('u_ayse', 'event_new', { eventId: 'e01', clubId: 'c01' }, 26, false); addN('u_ayse', 'event_new', { eventId: 'e04', clubId: 'c02' }, 6, false);
    addN('u_mehmet', 'announcement', { postId: 'p01', clubId: 'c01' }, 290, true); addN('u_mehmet', 'announcement', { postId: 'p22', clubId: 'c07' }, 20, false); addN('u_mehmet', 'event_new', { eventId: 'e02', clubId: 'c01' }, 190, true);
    addN('u_mehmet', 'event_new', { eventId: 'e07', clubId: 'c07' }, 50, false); addN('u_mehmet', 'application_rejected', { clubId: 'c05' }, 96, true); addN('u_mehmet', 'event_reminder', { eventId: 'e01', clubId: 'c01' }, 2, false);
    addN('u_mehmet', 'event_new', { eventId: 'e17', clubId: 'c01' }, 120, true); addN('u_mehmet', 'event_cancelled', { eventId: 'e21', clubId: 'c07' }, 22, false); addN('u_mehmet', 'system', { textKey: 'welcome' }, 480, true);
    addN('u_elif', 'application_received', { clubId: 'c01', applicantId: c01free[0] }, 2, false); addN('u_elif', 'application_received', { clubId: 'c01', applicantId: c01free[1] }, 9, false);
    addN('u_elif', 'announcement', { postId: 'p15', clubId: 'c02' }, 120, true); addN('u_elif', 'event_new', { eventId: 'e04', clubId: 'c02' }, 150, true); addN('u_elif', 'system', { textKey: 'welcome' }, 700, true);
    addN('u_burak', 'application_received', { clubId: 'c03', applicantId: c03free[0] }, 3, false); addN('u_burak', 'application_received', { clubId: 'c03', applicantId: c03free[1] }, 8, false); addN('u_burak', 'application_received', { clubId: 'c03', applicantId: 'u_cem' }, 30, false);
    addN('u_burak', 'event_reminder', { eventId: 'e17', clubId: 'c01' }, 3, true); addN('u_burak', 'announcement', { postId: 'p01', clubId: 'c01' }, 290, true); addN('u_burak', 'system', { textKey: 'welcome' }, 900, true);
    addN('u_zeynep', 'announcement', { postId: 'p01', clubId: 'c01' }, 290, true); addN('u_zeynep', 'event_new', { eventId: 'e02', clubId: 'c01' }, 190, true); addN('u_zeynep', 'system', { textKey: 'welcome' }, 600, true);

    /* reports */
    const reports = {};
    const addRep = (id, targetType, targetId, status, reporters, extra = {}) => { reports[id] = { id, targetType, targetId, status, reasons: reporters.map(([reporterId, reason, note, hrs]) => ({ reporterId, reason, note, createdAt: now - hrs * 36e5 })), action: null, resolvedAt: null, ...extra }; };
    addRep('r01', 'post', 'p17', 'open', [['u051', 'spam', 'Aynı bağlantı üç kez paylaşıldı.', 30], ['u052', 'spam', '', 28], ['u053', 'spam', 'Reklam gibi duruyor.', 20]]);
    addRep('r02', 'post', 'p24', 'open', [['u060', 'inappropriate', 'Görselde uygunsuz içerik var.', 14]]);
    addRep('r03', 'comment', 'cm24', 'open', [['u061', 'harassment', 'Aşağılayıcı bir dil kullanılmış.', 10]]);
    addRep('r04', 'user', 'u077', 'open', [['u062', 'other', 'Sahte profil olduğunu düşünüyorum; fotoğraf ve ad uyuşmuyor.', 48]]);
    addRep('r05', 'club', 'c10', 'open', [['u063', 'misinformation', 'Lig tarihleri yanlış duyuruldu.', 72]]);
    addRep('r06', 'post', 'p13', 'resolved', [['u064', 'inappropriate', '', 200]], { action: 'dismissed', resolvedAt: now - 150 * 36e5 });
    addRep('r07', 'comment', 'cm12', 'resolved', [['u065', 'harassment', '', 260]], { action: 'dismissed', resolvedAt: now - 240 * 36e5 });
    addRep('r08', 'user', 'u007', 'resolved', [['u066', 'other', 'Sahte hesap.', 400], ['u067', 'spam', '', 380]], { action: 'suspended', resolvedAt: now - 300 * 36e5 });
    addN('u_admin', 'new_report', { reportId: 'r01' }, 20, false); addN('u_admin', 'new_report', { reportId: 'r02' }, 14, false); addN('u_admin', 'new_report', { reportId: 'r03' }, 10, false); addN('u_admin', 'system', { textKey: 'welcome' }, 1000, true);

    /* activity */
    const activity = []; let aN = 0;
    const addA = (clubId, actorId, kind, createdAt, refs = {}) => activity.push({ id: 'a' + String(++aN).padStart(3, '0'), clubId, actorId, kind, createdAt, refs });
    Object.values(memberships).forEach((m) => { if (m.decidedAt && m.decidedAt > now - 30 * DAY && m.role === 'member') { if (m.status === 'active') addA(m.clubId, m.decidedBy || clubs[m.clubId].presidentId, 'application_approved', m.decidedAt, { userId: m.userId }); if (m.status === 'rejected') addA(m.clubId, m.decidedBy, 'application_rejected', m.decidedAt, { userId: m.userId }); if (m.status === 'removed') addA(m.clubId, m.decidedBy, 'member_removed', m.decidedAt, { userId: m.userId }); } });
    Object.values(posts).forEach((p) => addA(p.clubId, p.authorId, p.type === 'announcement' ? 'announcement' : p.type === 'poll' ? 'poll' : 'post_created', p.createdAt, { postId: p.id }));
    Object.values(events).forEach((e) => { if (e.status !== 'draft') addA(e.clubId, e.createdBy, e.status === 'cancelled' ? 'event_cancelled' : 'event_published', e.status === 'cancelled' ? now - 22 * 36e5 : e.createdAt, { eventId: e.id }); });
    Object.keys(clubs).forEach((cid) => { const count = activity.filter((a) => a.clubId === cid && a.createdAt > now - 30 * DAY).length; for (let i = count; i < 15; i++) { const kinds = ['member_joined', 'settings_changed', 'role_changed', 'member_left']; const kind = kinds[i % kinds.length]; const u = MEMBERS[cid][i % MEMBERS[cid].length]; addA(cid, kind === 'settings_changed' || kind === 'role_changed' ? clubs[cid].presidentId : u, kind, now - rint(1, 29) * DAY - rint(0, 23) * 36e5, { userId: u }); } });
    activity.sort((a, b) => b.createdAt - a.createdAt);

    /* settings */
    const settings = {};
    Object.keys(users).forEach((u) => { settings[u] = { announcements: true, eventReminders: true, newEvents: true, applicationResults: true, management: true, system: true, reminderTime: '1h', quiet: false, quietFrom: '22:00', quietTo: '08:00', clubs: {} }; });
    settings.u_mehmet.clubs.c07 = { announcements: true, events: true, posts: false, muted: false };

    const today = dayKey(now);
    return {
      seedVersion: SEED_VERSION, seedDay: today, seededAt: now,
      session: { userId: null, locale: 'tr', theme: 'system', textScale: 1, onboardingDone: false, notifPermission: 'default', notifAskedAt: null, cameraPermission: 'default', galleryPermission: 'default', failedAttempts: 0, lockedUntil: null, firstLogin: {}, verified: {}, lastLoginAt: null },
      ui: { network: 'online', dataMode: 'normal', frame: true, loadingUntil: 0, viewMode: 'list', recentSearches: ['hackathon', 'doğa yürüyüşü', 'satranç'], dismissedNotifBanner: false, searchTab: 'clubs', eventView: 'list', drafts: {}, clubFilters: null, eventFilters: null },
      users, clubs, memberships, posts, comments, events, rsvps, notifications, reports, activity, settings,
      saved: { u_mehmet: ['p01', 'p21'] },
      dailyAnnouncementCount: { [`c01_${today}`]: 1 },
      supportTickets: [],
    };
  }

  const DEMO_ACCOUNTS = [
    { id: 'u_ayse', roleKey: 'role.student', descKey: 'panel.acc.ayse' }, { id: 'u_mehmet', roleKey: 'role.member', descKey: 'panel.acc.mehmet' }, { id: 'u_elif', roleKey: 'role.board', descKey: 'panel.acc.elif' },
    { id: 'u_burak', roleKey: 'role.president', descKey: 'panel.acc.burak' }, { id: 'u_zeynep', roleKey: 'role.advisor', descKey: 'panel.acc.zeynep' }, { id: 'u_admin', roleKey: 'role.superadmin', descKey: 'panel.acc.admin' },
  ];
  Object.assign(GU, { seed, CATEGORIES, INTERESTS, FACULTIES, DEPARTMENTS, YEARS, PLACES, EVENT_TYPES, POPULAR_SEARCHES, DEMO_ACCOUNTS, CLUB_TABLE, EVENT_TABLE });
})();
