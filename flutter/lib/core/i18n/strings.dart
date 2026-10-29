/// Arabic-only app — no toggle, no second language. Every UI string funnels
/// through this class so there's one place to fix wording instead of
/// scattered literals per screen. Mirrors app/.../i18n/Strings.kt.
class Strings {
  Strings._();

  static const appTitle = 'توزيع الخبز';
  static const phoneLabel = 'رقم الهاتف';
  static const pinLabel = 'الرمز السري المكون من 4 أرقام';
  static const loginButton = 'تسجيل الدخول';
  static const loginError = 'رقم الهوية أو الرمز السري غير صحيح';
  static const loginOffline =
      'تعذّر الاتصال بالخادم. تحقق من الاتصال وحاول مرة أخرى.';
  static const loginIdTitle = 'تسجيل الدخول';
  static const loginPinTitle = 'أدخل رمزك السري';
  static const loginOtpTitle = 'أدخل رمز التحقق';
  static const continueButton = 'متابعة';
  static const forgotPin = 'نسيت الرمز السري؟';
  static String loginForId(String id) => 'لحساب رقم $id';
  static const otpLabel = 'رمز التحقق';
  static const verifyOtpButton = 'تأكيد الرمز والدخول';
  static const resendOtp = 'إعادة إرسال الرمز';
  static const otpError = 'رمز التحقق غير صحيح';
  static const nationalIdNotFound = 'رقم الهوية غير مسجل، يرجى إنشاء حساب جديد';
  static String demoOtpBanner(String code) =>
      'رمز تجريبي (لم يتم إرسال رسالة نصية): $code';
  static const demoAccountsTitle = 'حسابات تجريبية';
  static const demoBuyerLabel = 'مشتري';
  static const demoOwnerLabel = 'صاحب المخبز';

  static const personalIdLabel = 'رقم الهوية';
  static const nameLabel = 'الاسم';
  static const registerButton = 'تسجيل حساب جديد';
  static const registerError = 'يرجى تعبئة جميع الحقول';
  static const phoneAlreadyRegistered = 'رقم الهاتف مسجل مسبقاً';
  static const nationalIdAlreadyRegistered = 'رقم الهوية مسجل مسبقاً';
  static const logout = 'تسجيل الخروج';
  static const back = 'رجوع';
  static const createAccountLink = 'إنشاء حساب جديد';

  // Onboarding
  static const onboardingSkip = 'تخطي';
  static const onboardingNext = 'التالي';
  static const onboardingGetStarted = 'إنشاء حساب';
  static const onboardingHaveAccount = 'لدي حساب بالفعل';
  static const onboardingTitle1 = 'خبزك أقرب إلك';
  static const onboardingBody1 =
      'اعرف نقاط توزيع الخبز القريبة منك.';
  static const onboardingTitle2 = 'احجز ربطتك';
  static const onboardingBody2 =
      'اختار نقطة التوزيع واحجز بسهولة.';
  static const onboardingTitle3 = 'استلم بوقتك';
  static const onboardingBody3 =
      'بنبلغك أول ما ييجي دورك.';

  /// "الصفحة 2 من 3" — the counter above the intro, so how many steps are left
  /// is readable without counting dots. Western digits, like the rest of the
  /// app.
  static String onboardingPageOf(int page, int total) =>
      'الصفحة $page من $total';

  // Login — the old screen reused `registerError` ("يرجى تعبئة جميع الحقول")
  // for an empty National ID: it names the wrong problem, and it appeared under
  // the button instead of on the field that was empty.
  static const nationalIdRequired = 'أدخل رقم الهوية';
  static const nationalIdLengthError = 'رقم الهوية 9 أرقام';
  static const nationalIdHelper = '9 أرقام كما في بطاقة الهوية';
  static const pinRequired = 'أدخل الرمز السري';
  static const pinLengthError = 'الرمز السري 4 أرقام';
  static const showPin = 'إظهار الرمز';
  static const hidePin = 'إخفاء الرمز';
  static const otpRequired = 'أدخل رمز التحقق';
  static const otpLengthError = 'رمز التحقق 4 أرقام';

  /// Countdown while "resend" is on cooldown: the wait is visible instead of a
  /// dead-looking button, and the code can't be requested repeatedly.
  static String resendOtpIn(int seconds) => 'إعادة الإرسال بعد $seconds ثانية';
  static const demoOtpTapToFill = 'اضغط لتعبئة الرمز';
  static String fillDemoAccount(String label) => 'تعبئة بيانات $label';

  // Registration — per-field messages, so a blank form names the field that is
  // missing instead of printing one blanket sentence.
  static const registrationAccountSection = 'بيانات الحساب';
  static const registrationPaymentSection = 'الدخول والدفع';
  static const nameRequired = 'أدخل الاسم';
  static const phoneRequired = 'أدخل رقم الهاتف';
  static const phoneInvalid = 'رقم الهاتف 10 أرقام ويبدأ بـ 05';
  static const confirmPinLabel = 'تأكيد الرمز السري';
  static const pinMismatch = 'الرمزان السريان غير متطابقين';
  static const pinHelper = 'ستحتاجه للدخول في كل مرة — لا يمكن استعادته';
  static const jawwalPayRequired = 'أدخل رقم جوال باي';
  static const jawwalPayInvalid = 'رقم جوال باي 10 أرقام';

  // Registration
  static const registrationTitle = 'إنشاء حساب جديد';
  static const registrationSubtitle =
      'المعلومات التالية مطلوبة للتحقق من هويتك وحجز الخبز';
  static const jawwalPayNumberLabel = 'رقم جوال باي';
  static const jawwalPayNumberHint = 'سيُستخدم للدفع عند الشراء';

  // Identity verification
  static const idPhotoTitle = 'صورة بطاقة الهوية';
  static const idPhotoInstructions =
      'التقط صورة واضحة للوجه الأمامي لبطاقة هويتك. تأكد من وضوح الأرقام والصورة.';
  static const selfiePhotoTitle = 'صورة شخصية';
  static const selfiePhotoInstructions =
      'التقط صورة واضحة لوجهك للتأكد من مطابقتها مع بطاقة الهوية.';
  static const capturePrompt = 'اضغط لالتقاط صورة';
  static const retakePhoto = 'إعادة الالتقاط';
  static const captureError =
      'تعذر فتح الكاميرا — تأكد من منح إذن الكاميرا للتطبيق ثم أعد المحاولة';
  static const continueLabel = 'متابعة';
  static const verifyingTitle = 'جاري التحقق من حسابك';
  static const verifyingBody =
      'يرجى الانتظار بينما نتحقق من بياناتك. هذا قد يستغرق لحظات.';
  static const verifiedTitle = 'تم التحقق من حسابك!';
  static const verifiedBody =
      'يمكنك الآن حجز كيس الخبز اليومي من أي مخبز متاح.';
  static const continueToApp = 'الانتقال إلى التطبيق';

  // Store list
  static const storeListTitle = 'المخابز المتاحة';
  static const todayLabel = 'اليوم';
  static const noStores = 'لا توجد مخابز متاحة حالياً';
  static const available = 'متوفر';
  static const soldOut = 'نفدت الكمية';

  /// Owner account with no store attached to it server-side.
  static const noStoreForOwner =
      'لا يوجد مخبز مرتبط بهذا الحساب. تواصل مع المشرف لربط حسابك بمخبز.';

  /// Shown when a write couldn't reach the backend. Deliberately says the
  /// action did NOT happen: the server owns the bag count, so a failed
  /// write is a non-event, not something queued for later.
  static const offlineWriteFailed =
      'تعذّر الاتصال بالخادم. لم يتم تنفيذ العملية، حاول مرة أخرى.';

  /// A read that could not reach the server. There is no local copy to fall
  /// back on (constitution I), so the screen says so instead of looking empty.
  static const offlineRead = loginOffline;
  static const retryButton = 'إعادة المحاولة';

  /// Short badge form of [storeClosedLabel], for chips beside a store name.
  static const storeClosedBadge = 'مغلق';
  static String bagsRemaining(int remaining, int total) =>
      'المتبقي: $remaining من $total';
  static String purchaseWindowRange(String openTime, String closeTime) =>
      'وقت الشراء: $openTime - $closeTime';

  // Store list — search, area filter, pinning, buyer context
  static const storeSearchHint = 'ابحث باسم المخبز أو المنطقة';
  static const areaAllLabel = 'كل المناطق';
  static const noMatchingStores = 'لا يوجد مخبز مطابق';
  static const pinStore = 'تثبيت في الأعلى';
  static const unpinStore = 'إلغاء التثبيت';
  static const myStoreBadge = 'مخبزي';
  static const orderWaiting = 'بانتظار دورك';
  static const orderReady = 'جاهز للاستلام';
  static const orderCollected = 'تم الاستلام';
  static const paidBadge = 'مدفوع';
  static String lastPurchaseFrom(String when) => 'آخر شراء: $when';

  // Store details
  static const storeDetailsTitle = 'تفاصيل المخبز';
  static const myOrderTodayTitle = 'طلبي اليوم';
  static const showReceiptButton = 'اعرض وصل الاستلام';
  static const reserveBagButton = 'احجز كيس خبز';
  static const storeClosedLabel = 'المخبز مغلق حالياً';

  // Purchase
  static const purchaseTitle = 'الشراء';
  static const priceLabel = 'السعر';
  static const priceValue = '3 شيكل';
  static const dailyLimitReached = 'لقد قمت بالحجز من هذا المخبز اليوم';
  static String dailyLimitReachedOtherStore(String storeName) {
    final name = storeName.trim();
    if (name.isEmpty) {
      return 'لقد قمت بالحجز من مخبز آخر اليوم بالفعل';
    }
    final prefix = name.startsWith('مخبز') ? '' : 'مخبز ';
    return 'لقد قمت بالحجز من $prefix$name اليوم بالفعل';
  }

  static const viewOrder = 'عرض الطلب';
  static const payButton = 'ادفع 3 شيكل';

  // Confirmation
  static const confirmationTitle = 'تأكيد الحجز';
  static const queuePosition = 'الترتيب في الطابور';
  static String batchLabel(int batch) => 'الدفعة رقم $batch';
  static const statusWaiting = 'بانتظار الدور';
  static const waitingReassurance = 'سيتم إشعارك عندما يحين دورك';
  static const estimatedTime = 'الوقت التقديري للجاهزية';
  static const statusNotified = 'خبزك جاهز!';
  static const batchReadyNotificationBody =
      'حان دورك، توجه إلى المخبز لاستلام طلبك';
  static const returnToStores = 'العودة إلى المخابز';
  static const receiptQrTitle = 'رمز استلام الطلب';
  static const receiptQrSubtitle =
      'أظهر هذا الرمز لصاحب المخبز لتأكيد الاستلام';
  static const shareQrButton = 'مشاركة رمز الاستلام';
  static const saveQrButton = 'حفظ في المعرض';
  static const shareQrText = 'رمز استلام الخبز';
  static const qrSavedSuccess = 'تم حفظ رمز الاستلام في المعرض';
  static const qrSaveFailed = 'تعذر حفظ رمز الاستلام في المعرض';
  static const receiptPurchaseIdLabel = 'رقم الطلب';
  static const receiptDateLabel = 'التاريخ';
  static const receiptBatchLabel = 'الدفعة';
  static const receiptNameLabel = 'الاسم';

  // Owner history
  static const historyTitle = 'سجل المبيعات';
  static const historyButton = 'سجل المبيعات';
  static const historyEmpty = 'لا يوجد سجل بعد';
  static String historyDayTitle(String date) => 'مبيعات $date';
  static String historySold(int count) => 'المبيعات: $count';
  static String historyCollected(int count) => 'مستلم: $count';
  static String historyNotCollected(int count) => 'لم يستلم: $count';

  // Owner dashboard
  static const ownerDashboardTitle = 'لوحة صاحب المخبز';
  static const remainingLabel = 'المتبقي';
  static const purchaseWindowTimesLabel = 'أوقات الشراء';
  static const openTimeLabel = 'وقت البدء';
  static const closeTimeLabel = 'وقت الانتهاء';
  static const notSetLabel = 'غير محدد';
  static const allocationLabel = 'الكمية اليومية';
  static const batchSizeLabel = 'حجم الدفعة';
  static const decreaseValue = 'إنقاص';
  static const increaseValue = 'زيادة';
  static const saveBatchSize = 'حفظ حجم الدفعة';
  static const goToQueue = 'عرض طابور المشترين';

  // Owner dashboard — settings card, open/close gate, hero status line
  static const todaySettingsTitle = 'إعدادات اليوم';

  /// Saves the daily allocation *and* the purchase window together, so the
  /// label names both instead of only the quantity.
  static const saveTodaySettings = 'حفظ إعدادات اليوم';
  static const unsavedSettingsNote = 'لديك تغييرات غير محفوظة.';
  static const savedSettingsNote = 'الكمية والأوقات محفوظة.';
  static const savedSettingsSnack = 'تم حفظ إعدادات اليوم';
  static const purchaseWindowHint = 'وقت الشراء المعلن للزبائن:';
  static const windowOrderError = 'وقت الانتهاء يجب أن يكون بعد وقت البدء.';
  static const storeOpenSwitchLabel = 'المخبز مفتوح للبيع الآن';
  static const storeOpenOnHelper = 'الزبائن يستطيعون حجز كيس واحد اليوم.';
  static const storeOpenOffHelper =
      'الحجز متوقف — لن يتمكن الزبائن من الحجز حتى تعيد التشغيل.';

  /// Replaces the low-stock warning once the last bag is gone: selling is
  /// stopped, and the fix is a different one (raise today's allocation).
  static const outOfStockNotice = 'نفدت الكمية — حدّث الكمية اليومية بالأسفل.';

  /// The hero counter's value. Deliberately the Arabic word, not "X / Y": a
  /// slash between two numbers is resolved by the bidi algorithm against the
  /// RTL paragraph and renders as "300 / 14" (the limit first), which reads as
  /// the opposite of what it means. "14 من 300" is unambiguous in both
  /// directions.
  static String remainingValue(int remaining, int total) =>
      '$remaining من $total';

  // Owner queue
  static const buyerQueueTitle = 'طابور المشترين';
  static const queueEmpty = 'لا يوجد مشترون بعد اليوم';
  static String notifyNextBatch(int batch) => 'إشعار الدفعة رقم $batch';
  static const statusWaitingShort = 'قيد الانتظار';
  static const statusNotifiedShort = 'تم الإشعار';
  static const statusCollectedShort = 'تم الاستلام';
  static const markReceived = 'تأكيد الاستلام';
  static const undoReceived = 'تراجع عن الاستلام';

  // Owner queue — pickup (search + QR redemption)
  static const idShortLabel = 'الهوية';
  static const phoneShortLabel = 'الهاتف';
  static const searchBuyerHint = 'ابحث برقم الهوية أو الهاتف';
  static const buyerSearchNoResults = 'لا يوجد مشترٍ مطابق';
  static const scanQrTitle = 'مسح رمز الاستلام';
  static const scanCameraHint =
      'وجّه الكاميرا نحو رمز الاستلام على هاتف الزبون';
  static const scanCameraError =
      'تعذر تشغيل الكاميرا — تأكد من منح إذن الكاميرا للتطبيق ثم أعد المحاولة';
  static const scanInvalidCode = 'الرمز غير صالح، حاول مرة أخرى';
  static const scanNotFoundTitle = 'الطلب غير موجود على هذا الجهاز';
  static const scanNotFoundBody =
      'قد يكون هذا الرمز صادراً من جهاز آخر — لا توجد مزامنة بين الأجهزة في النسخة التجريبية';
  static const scanWrongStoreTitle = 'هذا الرمز من مخبز آخر';
  static String scanWrongStoreBody(String storeName) =>
      'هذا الرمز صادر من $storeName وليس من مخبزك';
  static const scanCheckedInTitle = 'تم تأكيد الاستلام';
  static const scanCheckedInBody = 'تم تسليم الكيس وتسجيل وصول الزبون';
  static const scanAlreadyCollected = 'تم استلام هذا الطلب مسبقاً';
  static String scanBatchNotCalledYet(int batch) =>
      'لم يحن دور الدفعة رقم $batch بعد';
  static const scanAgain = 'مسح رمز آخر';
  static const scanTorchOn = 'تشغيل الإضاءة';
  static const scanTorchOff = 'إطفاء الإضاءة';

  // Payment (Jawwal Pay mock)
  static const paymentTitle = 'الدفع عبر جوال باي';
  static const confirmJawwalPayNumber = 'تأكيد رقم جوال باي';
  static const jawwalPayPrompt = 'سيتم خصم 3 شيكل من محفظة جوال باي الخاصة بك.';
  static const proceedToOtp = 'إرسال رمز التأكيد';
  static const paymentOtpTitle = 'رمز تأكيد الدفع';
  static const paymentOtpInstructions =
      'أدخل رمز التأكيد المكون من 4 أرقام لتأكيد عملية الدفع.';
  static String demoOtpNotification(String code) =>
      'رمز التحقق (رسالة تجريبية): $code';
  static const paymentOtpLabel = 'رمز التأكيد (OTP)';
  static const confirmPaymentButton = 'تأكيد الدفع';
  static const resendCodeButton = 'إعادة إرسال الرمز';
  static const wrongOtpError = 'رمز التأكيد غير صحيح، يرجى المحاولة مرة أخرى';
  static const paymentSuccessTitle = 'تم الدفع بنجاح';
  static const paymentSuccessMessage =
      'تمت عملية الدفع بنجاح بقيمة 3 شيكل عبر جوال باي.';
  static const completeReservationButton = 'إتمام الحجز';

  // Owner customers
  static const customersTitle = 'سجل الزبائن';
  static const customersButton = 'عرض سجل الزبائن';
  static const customersEmpty = 'لا يوجد زبائن مسجلون بعد';
  static String totalPurchasesCount(int count) => 'إجمالي المشتريات: $count';
  static String lastPurchaseDate(String date) => 'آخر شراء: $date';

  // Buyer home ("my current order")
  static const buyerHomeTitle = 'طلبي';
  static const buyerHomeNoOrder = 'لا يوجد طلب اليوم';
  static const buyerHomeNoOrderHint =
      'احجز كيس خبز من المخابز المتاحة، وسيظهر هنا حتى تستلمه.';
  static const browseStoresButton = 'تصفح المخابز';
  static String buyerHomeBatch(int batch) => 'الدفعة رقم $batch';

  // Owner queue & dashboard polish (walkthrough P1)
  static String batchSummary(int picked, int awaiting, int waiting) =>
      'تم الاستلام: $picked · بانتظار الاستلام: $awaiting · لم يُنادَ: $waiting';
  static const notifyConfirmTitle = 'تأكيد إشعار الدفعة';
  static String notifyConfirmBody(int batch) =>
      'سيتم إشعار جميع المترقّبين في الدفعة رقم $batch بأن خبزهم جاهز.';
  static const notifyConfirmAction = 'إشعار الدفعة';
  static const cancelLabel = 'إلغاء';
  static const logoutConfirmTitle = 'تسجيل الخروج؟';
  static const logoutConfirmBody =
      'ستحتاج إلى رقم الهوية والرمز السري للدخول مرة أخرى.';
  static const closeStoreConfirmTitle = 'إغلاق المخبز؟';
  static const closeStoreConfirmBody =
      'لن يتمكن الزبائن من حجز أي كيس حتى تفتح المخبز مرة أخرى.';
  static const closeStoreConfirmAction = 'إغلاق المخبز';
  static String notifyOutstandingWarning(int count) =>
      'تنبيه: $count ممن نودي عليهم في دفعات سابقة لم يستلموا بعد.';
  static String lowStockWarning(int remaining) =>
      'الكمية على وشك النفاد — المتبقي $remaining كيس فقط.';
  static const pendingPickupLabel = 'بانتظار الاستلام';
}
