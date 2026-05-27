# Asia-Pacific + Middle East locales
from __future__ import annotations

_PACK = lambda name, subtitle, desc, kw=None: {
    "name": name,
    "subtitle": subtitle,
    "description": desc,
    **({"keywords": kw} if kw else {}),
}

_JA_DESC = """\
Simple GLPは、週1回のGLP-1注射を最も素早く記録する方法です。治療を表計算にしたくない方のために設計されています。

ワンタップで記録
アプリを開く、ホーム画面ウィジェットをタップする、またはApple Watchを持ち上げるだけ。注射はすぐにタイムスタンプ付きで保存されます。用量、注射部位、メモ、症状は後から追加できます。

あなたの週を理解するスケジュール
薬剤、用量プラン、希望の曜日と時刻を設定。Simple GLPは各注射が早い・時間どおり・遅いかを判断し、次回を前もってお知らせします。

HealthKitコンテキスト（任意）
許可いただければ、Apple Healthの体重、血糖、活動、睡眠、心拍、ワークアウト、水分、カフェイン、カロリー、タンパク質を各記録に添付できます。読み取り専用。書き戻しはしません。

プライバシー設計
アカウント不要。広告なし。分析なし。データ販売なし。履歴は端末内に保持され、アプリ・ウィジェット・Watch間で安全なApp Groupで共有されます。

Simple GLP Pro（任意）
Proはタイミングのずれを早期に検知するプロアクティブなアラートを追加。アプリ内課金。設定からいつでも解約可能。

医療機器ではありません
Simple GLPは医療アドバイス、用量指示、診断、治療推奨を提供しません。常に処方担当者の指示に従ってください。"""

_KO_DESC = """\
Simple GLP는 주간 GLP-1 주사를 가장 빠르게 기록하는 방법입니다. 치료 루틴을 스프레드시트로 만들고 싶지 않은 분을 위해 설계되었습니다.

원탭 기록
앱을 열고, 홈 화면 위젯을 탭하거나 Apple Watch를 들어 올리세요. 주사가 즉시 타임스탬프됩니다. 용량, 주사 부위, 메모, 증상은 나중에 추가할 수 있습니다.

당신의 한 주를 아는 일정
약물, 용량 계획, 선호 요일과 시간을 설정하세요. Simple GLP는 각 주사가 이른지, 정시인지, 늦었는지 파악하고 다음 주사를 미리 알려줍니다.

HealthKit 컨텍스트(선택)
허용 시 Apple Health의 체중, 혈당, 활동, 수면, 심박, 운동, 수분, 카페인, 칼로리, 단백질을 각 기록에 첨부할 수 있습니다. 읽기 전용. 다시 쓰지 않습니다.

프라이버시 우선
계정 없음. 광고 없음. 분석 없음. 데이터 판매 없음. 기록은 기기에만 남으며 앱·위젯·시계가 보안 App Group으로 공유합니다.

Simple GLP Pro(선택)
Pro는 일정 이탈을 조기에 잡는 선제 알림을 추가합니다. 앱 내 구독. 설정에서 언제든 해지.

의료 기기 아님
Simple GLP는 의료 조언, 용량 지침, 진단 또는 치료 권고를 제공하지 않습니다. 항상 처방자의 지침을 따르세요."""

_ZH_HANS_DESC = """\
Simple GLP 是记录每周 GLP-1 注射的最快方式——为只想记下那一刻、不想把治疗变成表格的人而设计。

一键记录
打开 App、点按主屏幕小组件，或抬起 Apple Watch 手腕。注射会立即打上时间戳。剂量、注射部位、备注和症状可稍后添加。

懂您每周计划的日程
设置药物、剂量计划、偏好星期与时间。Simple GLP 会判断每次注射是偏早、准时还是偏晚，并提前提醒下一次。

HealthKit 上下文（可选）
经您允许，Simple GLP 可附加 Apple 健康中的体重、血糖、活动、睡眠、心率、锻炼、饮水、咖啡因、卡路里和蛋白质。只读。不会写回。

隐私设计
无账户。无广告。无分析。不出售数据。记录保存在设备上，通过安全 App Group 在 App、小组件与手表间共享。

Simple GLP Pro（可选）
Pro 增加基于模式的前瞻提醒，及早发现时间偏移。应用内订阅。可随时在设置中取消。

非医疗器械
Simple GLP 不提供医疗建议、剂量说明、诊断或治疗建议。请始终遵循处方者的指导。"""

_ZH_HANT_DESC = """\
Simple GLP 是記錄每週 GLP-1 注射的最快方式——為只想記下那一刻、不想把治療變成試算表的人而設計。

一鍵記錄
開啟 App、點按主畫面小工具，或抬起 Apple Watch 手腕。注射會立即打上時間戳。劑量、注射部位、備註和症狀可稍後新增。

懂您每週計畫的日程
設定藥物、劑量計畫、偏好星期與時間。Simple GLP 會判斷每次注射是偏早、準時還是偏晚，並提前提醒下一次。

HealthKit 情境（可選）
經您允許，Simple GLP 可附加 Apple 健康中的體重、血糖、活動、睡眠、心率、锻炼、飲水、咖啡因、卡路里和蛋白質。唯讀。不會寫回。

隱私設計
無帳號。無廣告。無分析。不出售資料。記錄保存在裝置上，透過安全 App Group 在 App、小工具與手錶間共享。

Simple GLP Pro（可選）
Pro 增加基於模式的前瞻提醒，及早發現時間偏移。App 內訂閱。可隨時在設定中取消。

非醫療器材
Simple GLP 不提供醫療建議、劑量說明、診斷或治療建議。請始終遵循處方者的指導。"""

_AR_DESC = """\
Simple GLP هي أسرع طريقة لتسجيل حقنة GLP-1 الأسبوعية — لمن يريدون توثيق اللحظة دون تحويل العلاج إلى جدول بيانات.

نقرة واحدة للتسجيل
افتح التطبيق، المس أداة الشاشة الرئيسية، أو ارفع معصم Apple Watch. تُسجَّل الحقنة فوراً مع الطابع الزمني. أضف الجرعة والموقع والملاحظات والأعراض لاحقاً إن شئت.

جدول يفهم أسبوعك
حدّد الدواء وخطة الجرعة واليوم والوقت المفضّلين. يحدد Simple GLP ما إذا كانت كل حقنة مبكرة أو في الوقت أو متأخرة ويذكّرك بالتالية.

سياق HealthKit (اختياري)
بإذنك، يمكن لـ Simple GLP إرفاق سياق من Apple Health — الوزن، الجلوكوز، النشاط، النوم، معدل القلب، التمارين، الماء، الكافيين، السعرات والبروتين. للقراءة فقط. لا يُكتب شيء بالعودة.

خصوصية بالتصميم
لا حسابات. لا إعلانات. لا تحليلات. لا بيع للبيانات. يبقى السجل على جهازك ويُشارك بين التطبيق والأداة والساعة عبر App Group آمن.

Simple GLP Pro (اختياري)
يضيف Pro تنبيهات استباقية عند انحراف التوقيت. اشتراك داخل التطبيق. إلغاء من الإعدادات في أي وقت.

ليس جهازاً طبياً
لا يقدّم Simple GLP نصائح طبية أو تعليمات جرعات أو تشخيصاً أو توصيات علاج. اتبع دائماً إرشادات وصفتك."""

_TH_DESC = """\
Simple GLP คือวิธีที่เร็วที่สุดในการบันทึกการฉีด GLP-1 รายสัปดาห์ — สำหรับผู้ที่ต้องการจดช่วงเวลาโดยไม่เปลี่ยนการรักษาเป็นสเปรดชีต

แตะครั้งเดียวเพื่อบันทึก
เปิดแอป แตะวิดเจ็ตบนหน้าจอหลัก หรือยกข้อมือ Apple Watch การฉีดจะถูกบันทึกพร้อมเวลาทันที เพิ่มขนาดยา ตำแหน่งฉีด บันทึก และอาการภายหลังได้

ตารางที่เข้าใจสัปดาห์ของคุณ
ตั้งยา แผนขนาด วันและเวลาที่ต้องการ Simple GLP บอกว่าการฉีดแต่ละครั้งเร็ว ตรงเวลา หรือช้า และเตือนก่อนครั้งถัดไป

บริบท HealthKit (ไม่บังคับ)
เมื่อคุณอนุญาต Simple GLP สามารถแนบข้อมูลจาก Apple Health — น้ำหนัก น้ำตาล กิจกรรม การนอน อัตราหัวใจ การออกกำลัง น้ำ คาเฟอีน แคลอรี่ และโปรตีน อ่านอย่างเดียว ไม่เขียนกลับ

ความเป็นส่วนตัว
ไม่มีบัญชี ไม่มีโฆษณา ไม่มีการวิเคราะห์ ไม่ขายข้อมูล ประวัติอยู่บนอุปกรณ์ แชร์ระหว่างแอป วิดเจ็ต และนาฬิกาผ่าน App Group ที่ปลอดภัย

Simple GLP Pro (ไม่บังคับ)
Pro เพิ่มการแจ้งเตือนเชิงรุกเมื่อเวลาเบี่ยงเบน สมัครในแอป ยกเลิกได้ในการตั้งค่า

ไม่ใช่อุปกรณ์ทางการแพทย์
Simple GLP ไม่ให้คำแนะนำทางการแพทย์ คำแนะนำขนาดยา การวินิจฉัย หรือการรักษา ปฏิบัติตามแพทย์ผู้สั่งยาเสมอ"""

_VI_DESC = """\
Simple GLP là cách nhanh nhất để ghi lại mũi tiêm GLP-1 hàng tuần — dành cho người chỉ muốn lưu khoảnh khắc mà không biến điều trị thành bảng tính.

Một chạm để ghi
Mở app, chạm widget Màn hình chính, hoặc nhấc cổ tay Apple Watch. Mũi tiêm được đóng dấu thời gian ngay. Thêm liều, vị trí tiêm, ghi chú và triệu chứng sau nếu muốn.

Lịch hiểu tuần của bạn
Đặt thuốc, kế hoạch liều, ngày và giờ ưa thích. Simple GLP biết mỗi mũi sớm, đúng giờ hay trễ và nhắc mũi tiếp theo.

Ngữ cảnh HealthKit (tùy chọn)
Khi bạn cho phép, Simple GLP có thể đính kèm ngữ cảnh từ Apple Health — cân nặng, glucose, hoạt động, giấc ngủ, nhịp tim, tập luyện, nước, caffeine, calo và protein. Chỉ đọc. Không ghi ngược.

Riêng tư
Không tài khoản. Không quảng cáo. Không phân tích. Không bán dữ liệu. Lịch sử ở trên thiết bị, chia sẻ giữa app, widget và đồng hồ qua App Group an toàn.

Simple GLP Pro (tùy chọn)
Pro thêm cảnh báo chủ động khi lệch giờ. Đăng ký trong app. Hủy trong Cài đặt bất cứ lúc nào.

Không phải thiết bị y tế
Simple GLP không cung cấp tư vấn y khoa, hướng dẫn liều, chẩn đoán hay khuyến nghị điều trị. Luôn theo chỉ dẫn người kê đơn."""

_ID_DESC = """\
Simple GLP adalah cara tercepat mencatat suntikan GLP-1 mingguan — untuk yang ingin mencatat momen tanpa mengubah perawatan menjadi spreadsheet.

SATU KETUK UNTUK CATAT
Buka app, ketuk widget Layar Utama, atau angkat pergelangan Apple Watch. Suntikan langsung berstempel waktu. Tambahkan dosis, lokasi suntik, catatan, dan gejala nanti jika mau.

JADWAL YANG PAHAM MINGGU ANDA
Atur obat, rencana dosis, hari dan waktu pilihan. Simple GLP tahu setiap suntikan lebih awal, tepat waktu, atau terlambat dan mengingatkan yang berikutnya.

KONTEKS HEALTHKIT (OPSIONAL)
Dengan izin Anda, Simple GLP dapat melampirkan konteks Apple Health — berat, glukosa, aktivitas, tidur, detak jantung, latihan, air, kafein, kalori, dan protein. Hanya baca. Tidak menulis balik.

PRIVASI
Tanpa akun. Tanpa iklan. Tanpa analitik. Tanpa penjualan data. Riwayat tetap di perangkat, dibagikan antara app, widget, dan jam tangan lewat App Group aman.

SIMPLE GLP PRO (OPSIONAL)
Pro menambah peringatan proaktif saat waktu menyimpang. Berlangganan di app. Batalkan kapan saja di Pengaturan.

BUKAN PERANGKAT MEDIS
Simple GLP tidak memberikan saran medis, instruksi dosis, diagnosis, atau rekomendasi perawatan. Selalu ikuti petunjuk peresep Anda."""

_MS_DESC = _ID_DESC.replace("Layar Utama", "Skrin Utama").replace("Pengaturan", "Tetapan").replace("app", "aplikasi")

_HE_DESC = """\
Simple GLP היא הדרך המהירה ביותר לתעד זריקת GLP-1 שבועית — למי שרוצים לרשום את הרגע בלי להפוך את הטיפול לגיליון.

הקשה אחת לתיעוד
פתחו את האפליקציה, הקישו על הווידג'ט במסך הבית, או הרימו את פרק כף היד עם Apple Watch. הזריקה נחתמת בזמן מיד. אפשר להוסיף מינון, אתר, הערות ותסמינים אחר כך.

לוח שמכיר את השבוע שלכם
הגדירו תרופה, תוכנית מינון, יום ושעה מועדפים. Simple GLP יודעת אם כל זריקה מוקדמת, בזמן או מאוחרת ומזכירה לפני הבאה.

הקשר HealthKit (אופציונלי)
באישורכם, Simple GLP יכולה לצרף הקשר מ-Apple Health — משקל, גלוקוז, פעילות, שינה, דופק, אימונים, מים, קפאין, קלוריות וחלבון. קריאה בלבד. ללא כתיבה חזרה.

פרטיות
ללא חשבונות. ללא פרסומות. ללא אנליטיקה. ללא מכירת נתונים. ההיסטוריה נשארת במכשיר, משותפת בין האפליקציה, הווידג'ט והשעון ב-App Group מאובטח.

Simple GLP Pro (אופציונלי)
Pro מוסיפה התראות יזומות כשהזמנים סוטים. מנוי באפליקציה. ביטול בהגדרות בכל עת.

לא מכשיר רפואי
Simple GLP אינה מספקת ייעוץ רפואי, הוראות מינון, אבחון או המלצות טיפול. עקבו תמיד אחרי הרופא המטפל."""

PACKS: dict = {
    "ja": _PACK(
        "Easy GLP - GLP-1注射記録",
        "ウィジェット・Watch一括記録",
        _JA_DESC,
        "オゼンピック,ウゴービ,マンジャロ,ゼップバウンド,セマグルチド,チルゼパチド,ペプチド,リマインダー,プライベート,用量,週次",
    ),
    "ko": _PACK(
        "Easy GLP - GLP-1 주사 기록",
        "위젯·워치 원탭 기록",
        _KO_DESC,
        "오젬픽,위고비,마운자로,젭바운드,세마글루타이드,티르제파타이드,펩타이드,알림,프라이빗,용량,주간",
    ),
    "zh-Hans": _PACK(
        "Easy GLP - GLP-1注射记录",
        "小组件与手表一键记录",
        _ZH_HANS_DESC,
        "司美格鲁肽,替尔泊肽,奥泽匹克,维戈维,玛仕度肽,泽普肽,肽,提醒,私密,剂量,每周",
    ),
    "zh-Hant": _PACK(
        "Easy GLP - GLP-1注射記錄",
        "小組件與手錶一鍵記錄",
        _ZH_HANT_DESC,
        "司美格魯肽,替爾泊肽,奧澤匹克,維戈維,瑪仕度肽,澤普肽,肽,提醒,私密,劑量,每週",
    ),
    "ar-SA": _PACK(
        "Easy GLP - متتبع GLP-1",
        "أداة وساعة · نقرة واحدة",
        _AR_DESC,
        "ozempic,wegovy,mounjaro,zepbound,semaglutide,tirzepatide,ببتيد,تذكير,حقن,خاص,جرعة,أسبوعي",
    ),
    "he": _PACK(
        "Easy GLP - יומן GLP-1",
        "ווידג'ט ושעון · הקשה",
        _HE_DESC,
        "ozempic,wegovy,mounjaro,zepbound,semaglutide,tirzepatide,פפטיד,תזכורת,זריקה,פרטי,מינון,שבועי",
    ),
    "th": _PACK(
        "Easy GLP - บันทึก GLP-1",
        "วิดเจ็ต·นาฬิกา แตะครั้ง",
        _TH_DESC,
        "ozempic,wegovy,mounjaro,zepbound,semaglutide,tirzepatide,เปปไทด์,เตือน,ฉีด,ส่วนตัว,ขนาด,รายสัปดาห์",
    ),
    "vi": _PACK(
        "Easy GLP - Nhật ký GLP-1",
        "Widget·Watch một chạm",
        _VI_DESC,
        "ozempic,wegovy,mounjaro,zepbound,semaglutide,tirzepatide,peptide,nhắc,tiêm,riêng,liều,hàngtuần",
    ),
    "id": _PACK(
        "Easy GLP - Log GLP-1",
        "Widget & Watch · Ketuk",
        _ID_DESC,
        "ozempic,wegovy,mounjaro,zepbound,semaglutide,tirzepatide,peptida,pengingat,suntik,privat,dosis,mingguan",
    ),
    "ms": _PACK(
        "Easy GLP - Log GLP-1",
        "Widget & Watch · Ketuk",
        _MS_DESC,
        "ozempic,wegovy,mounjaro,zepbound,semaglutide,tirzepatide,peptida,peringatan,suntikan,peribadi,dos,mingguan",
    ),
}
