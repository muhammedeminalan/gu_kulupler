// PLAN §10.4 repository tablolarını testler için okur: arayüzlerin üye adları
// ve imzaları bu tablolarla birebir olmalıdır; PLAN değişirse parite testleri
// kırılır.
import 'plan_service_table.dart';
import 'repo_sources.dart';

/// PLAN §10.4 tablosunun bir satırı: üye hücresi (düz metin) ve tam imza.
typedef PlanRepositoryMember = ({String member, String note, String signature});

/// PLAN §10.4'te `#### <repository>` başlığı altındaki tablonun üyeleri,
/// tablo sırasıyla. `note`, üye hücresinde kod parçasından sonra kalan
/// metindir (ör. sonraki task'a ait satırda `(T-25, CD-38)`).
List<PlanRepositoryMember> readPlanRepositoryMembers(String repository) => [
  for (final row in markdownTable(
    readRepoFile('docs/PLAN.md'),
    heading: '#### $repository ',
  ).rows)
    (
      member: codeSpans(row[0]).first,
      note: row[0].replaceFirst('`${codeSpans(row[0]).first}`', '').trim(),
      signature: codeSpans(row[1]).first,
    ),
];

/// [relative] kaynağındaki `abstract interface class <name>` gövdesinin üye
/// bildirimleri (yorumlar atılmış, boşluksuz; her biri `;` ile biten bir
/// imza).
List<String> interfaceMembers(String relative, String name) {
  final source = normalizeDartSource(readRepoFile(relative));
  final start = source.indexOf('abstractinterfaceclass$name{');
  if (start < 0) throw StateError('$relative içinde arayüz $name yok.');
  final body = source.substring(
    start + 'abstractinterfaceclass$name{'.length,
    source.lastIndexOf('}'),
  );
  return [
    for (final member in body.split(';'))
      if (member.isNotEmpty) member,
  ];
}
