/// GÜ Kulüpler veri katmanı (`gu_data`).
///
/// Barrel dosyası: `FirebaseResult`, `BaseFields`, `SoftDelete`, modeller,
/// servisler ve repository arayüzleri buradan dışa aktarılır. Uygulama
/// (`lib/`) ve kök testleri yalnızca bu dosyayı içe aktarır; `src/` yolu
/// paket dışından kullanılmaz.
library;

export 'src/constants/anonymization.dart';
export 'src/constants/email_domain_policy.dart';
export 'src/constants/firestore_collections.dart';
export 'src/constants/firestore_fields.dart';
export 'src/constants/firestore_ids.dart';
export 'src/constants/limits.dart';
export 'src/constants/role_codes.dart';
export 'src/constants/static_tables.dart';
export 'src/core/app_clock.dart';
export 'src/core/auth_error.dart';
export 'src/core/base_fields.dart';
export 'src/core/conflict_exception.dart';
export 'src/core/firebase_result.dart';
export 'src/core/firestore_error.dart';
export 'src/core/firestore_failure_detail.dart';
export 'src/core/page_cursor.dart';
export 'src/core/page_request.dart';
export 'src/core/page_result.dart';
export 'src/core/role_policy.dart';
export 'src/core/soft_delete.dart';
export 'src/core/storage_error.dart';
export 'src/models/enums/club_role.dart';
export 'src/models/lookup/category_model.dart';
export 'src/models/lookup/department_model.dart';
export 'src/models/lookup/event_type_model.dart';
export 'src/models/lookup/faculty_model.dart';
export 'src/models/lookup/interest_model.dart';
export 'src/models/lookup/place_model.dart';
export 'src/utils/email_domain_validator.dart';
export 'src/utils/json_converters.dart';
export 'src/utils/ticket_code.dart';
