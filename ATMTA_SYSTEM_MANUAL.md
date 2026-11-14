# دليل إعدادات وتشغيل منصة Chatwoot المخصصة (Atmta Automation Service)
**تاريخ آخر تحديث:** 14 نوفمبر 2026  
**الإصدار الحالي:** Chatwoot v4.19.1 (Custom Build: `chatwoot/chatwoot:latest` / `chatwoot-custom:4.19.1-atmta`)  
**رابط المنصة الأساسي:** [https://chat.automationservice.cloud](https://chat.automationservice.cloud)  
**لوحة السوبر آدمن:** [https://chat.automationservice.cloud/super_admin](https://chat.automationservice.cloud/super_admin)  
**صفحة الدعاية والتسويق:** [https://chat.automationservice.cloud/landing.html](https://chat.automationservice.cloud/landing.html)  
**مستودع GitHub الرسمي:** [https://github.com/salah3bkrino/chatwoot](https://github.com/salah3bkrino/chatwoot)  
**الفرع المعتمد:** `develop`

---

## 1. البنية التحتية ومسارات السيرفر (Server Infrastructure)

| المكون | المسار على السيرفر (VPS) | الوظيفة والوصف |
| :--- | :--- | :--- |
| **مستودع الكود** | `/opt/chatwoot-source` (أو `/opt/chatwoot`) | كود Ruby on Rails و Vue.js الكامل مع كافة التعديلات |
| **بيئة التشغيل** | `/opt/chatwoot` | ملفات Docker Compose وملف المتغيرات `.env` |
| **حاويات النظام** | `chatwoot-rails-1`, `chatwoot-sidekiq-1`, `chatwoot-postgres-1`, `chatwoot-redis-1` | الحاويات الأساسية المشغلة للخدمات وقواعد البيانات |
| **البروكسي العكسي** | `traefik-xi6t-traefik-1` (Traefik) | إدارة شهادات Let's Encrypt SSL وتوجيه الترافيك لمنفذ 3000 |

---

## 2. الميزات المخصصة في النظام (Atmta Custom Features)

### أ. مسارات العمل المرئية والأتمتة الذكية (Visual Workflows Builder)
* **المسار في الواجهة:** القائمة الجانبية ← الإعدادات ← مسارات العمل (`Settings → Workflows`).
* **التقنية:** مبني بمكتبة `@vue-flow/core` على شاشة كاملة دون تشويش.
* **المشغلات (Triggers):**
  * `message_created` (استقبال أو إرسال رسالة).
  * `conversation_created` / `conversation_opened` / `conversation_resolved`.
* **الشروط (Conditions):**
  * `has_flow_response`: التحقق من إرسال العميل لاستمارة Meta Flow.
  * `flow_field:<key>`: قراءة قيمة حقل معين تم تعبئته داخل استمارة الفلو (مثل الاسم، التقييم، أو نوع الخدمة).
  * `interactive_reply_id`: فحص معرف الزر أو القائمة التفاعلية التي نقر عليها العميل.
  * `has_ad_referral`: فحص هل جاء العميل عبر إعلان Click-to-WhatsApp من Facebook/Instagram.
  * `content` / `status`: فحص نص الرسالة أو حالة المحادثة.
* **الإجراءات (Actions):**
  * `send_message`: إرسال رسائل نصية أو تفاعلية (أزرار، قوائم، استمارات فلو، أو طلب موقع).
  * `trigger_webhook`: إطلاق Webhook فوري لربطه بسيناريوهات n8n أو أنظمة خارجية.
  * `add_label`: إضافة وسوم تصنيف تلقائية للمحادثة.
  * `assign_team`: تحويل المحادثة آلياً لفريق متخصص.
  * `resolve_conversation`: إغلاق المحادثة عند انتهاء الخدمة.

---

### ب. واتساب السحابي الرسمي من Meta (Official WhatsApp Cloud API)
> **ملاحظة هامة:** تم تنظيف النظام وحذف أي أكواد أو مكتبات غير رسمية (مثل Evolution API / QR Code) لتكون المنصة رسمية وموثقة بنسبة 100% متوافقة مع متطلبات Meta.

#### 1. ملحن الرسائل التفاعلية (Interactive Composer ⚡)
* **المسار:** داخل أي محادثة واتساب ← أسفل صندوق الرد ← الضغط على زر الصاعقة ⚡ بجوار زر القوالب.
* **الأنماط المتاحة:**
  1. **Buttons (أزرار الرد السريع):** حتى 3 أزرار بنصوص مخصصة ومعرفات فريدة.
  2. **Menu List (القوائم التفاعلية):** قائمة خيارات حتى 10 بنود مع عنوان ووصف فرعي لكل بند.
  3. **Location Request (طلب الموقع):** رسالة رسمية تتيح للعميل مشاركة إحداثيات موقعه الجغرافي بنقرة واحدة.
  4. **CTA URL (زر الرابط):** زر ينقل العميل لموقعك الخارجي أو صفحة الدفع.
  5. **WhatsApp Flows (استمارات فلو):** مزامنة وجلب استماراتك المنشورة من Meta تلقائياً وإرسالها للعميل بضغطة زر.
  6. **Single Product (منتج الكتالوج):** إرسال منتج محدد من كتالوج Meta التجاري.

#### 2. بطاقات عرض الردود والطلبات الذكية (Message Bubbles)
* **WhatsappFlowResponseBubble:** عند إرسال العميل لاستمارة Meta Flow، يقوم النظام بفك تشفير الـ JSON تلقائياً وعرض الإجابات كجدول أنيق منظم داخل المحادثة.
* **WhatsappOrderBubble:** عند قيام العميل بالطلب عبر كتالوج واتساب، يتم تجميع سلة المشتريات وعرض أسماء المنتجات والكميات والسعر الإجمالي مباشرة.

---

### ج. حملات واتساب الآمنة المانعة للحظر (Anti-Ban Campaign Engine)
* **المسار:** الحملات ← حملات واتساب ← إنشاء حملة (`Campaigns → WhatsApp Campaigns`).
* **الميزات الأمنية:**
  * **Batch Pacing:** تقسيم الجمهور لدفعات صغيرة بدلاً من الإرسال الدفعي المفاجئ.
  * **Micro-Jitter Sleep:** تأخير عشوائي مجهري بين كل رسالة وأخرى لمحاكاة السلوك البشري.
  * **Random Batch Delays:** فترات راحة متغيرة (15-45 ثانية) بين كل دفعة والأخرى.
  * **Auto-Pause on Health Drop:** إيقاف الحملة مؤقتاً وبشكل تلقائي فور هبوط تقييم جودة الرقم في Meta (Quality Rating) للون الأصفر أو الأحمر لحماية الخط من الحظر.

---

### د. نظام الفوترة والاشتراكات المحلي (Atmta Billing System)
* **دفع محلي يدوي (No Stripe Required):** يدعم الدفع عبر فودافون كاش وإنستاباي.
* **إدارة الخطط (`/super_admin/subscription_plans`):** التحكم في عدد الوكلاء، وصناديق البريد، وميزات الذكاء الاصطناعي وواتساب لكل خطة.
* **إدارة المدفوعات اليدوية (`/super_admin/manual_payments`):** اعتماد أو رفض طلبات التحويل مع تفعيل وتمديد الاشتراكات آلياً.
* **ربط الحسابات بالخطط (`/super_admin/accounts`):** تعيين نوع الخطة، وتاريخ البدء والانتهاء، وتفعيل الفترات التجريبية (Trial).

---

### هـ. ميزات الذكاء الاصطناعي المدمجة (AI Features)
تم دمج وتوسيع خصائص الذكاء الاصطناعي تحت أعلام `feature_flags_ext_1`:
1. `auto_qa`: التقييم والتدقيق الآلي لجودة محادثات خدمة العملاء.
2. `sentiment_analysis`: تحليل مشاعر العملاء التلقائي على الرسائل.
3. `ai_resolution_tracking`: قياس وتقييم نسبة حل المشكلات بواسطة الذكاء الاصطناعي.
4. `ai_analytics`: تقارير ورؤى الذكاء الاصطناعي في القائمة الجانبية.
5. `auto_categorization`: التصنيف الآلي لموضوعات المحادثات.

---

## 3. الأوامر التشغيلية وإجراءات الصيانة (Operational Runbook)

### أ. التحديث الشامل وتطبيق المايجريشن (Full Update & Migrate)
يُنفذ على السيرفر لتحديث الكود وقاعدة البيانات معاً:
```bash
cd /opt/chatwoot

# 1) سحب أحدث كود من فرع develop
git fetch origin develop
git reset --hard origin/develop

# 2) تشغيل مايجريشن قاعدة البيانات (إنشاء جدول workflows والجداول الجديدة)
docker exec -it chatwoot-rails-1 bundle exec rails db:migrate

# 3) إعادة تشغيل الحاويات
docker compose restart rails sidekiq
```

---

### ب. بناء صورة Docker بالكامل وتحديث الواجهة (Full Image Rebuild)
عند تعديل ملفات Vue أو إضافة مكتبات جديدة بالـ Frontend:
```bash
cd /opt/chatwoot

# 1) التأكد من استخدام ملف الإنتاج
cp docker-compose.production.yaml docker-compose.yaml

# 2) بناء الصورة مع تجميع الـ Assets تلقائياً
docker build -t chatwoot/chatwoot:latest -f docker/Dockerfile .

# 3) تشغيل الحاويات وتطبيق المايجريشن
docker compose up -d
docker exec -it chatwoot-rails-1 bundle exec rails db:migrate
```

---

### ج. أخذ نسخة احتياطية من قاعدة البيانات (Backup Database)
```bash
docker exec -t chatwoot-postgres-1 pg_dump -U postgres chatwoot > /opt/chatwoot_backup_$(date +%F_%T).sql
```

---

### د. استرجاع توجيه Traefik في حال ظهور خطأ 404 (Traefik Fix)
في حال ظهرت صفحة `404 page not found` من Traefik:
```bash
cd /opt/chatwoot

# ربط حاوية rails بشبكة Traefik تلقائياً
for cid in $(docker ps -q --filter "name=traefik" --filter "name=proxy"); do
  for net in $(docker inspect $cid --format '{{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}'); do
    docker network connect $net chatwoot-rails-1 2>/dev/null || true
  done
done

# فحص عمل الدومين
curl -I https://chat.automationservice.cloud
```

---

## 4. جدول استكشاف الأخطاء السريع (Troubleshooting)

| العَرَض | السبب التقني | الحل الفوري |
| :--- | :--- | :--- |
| **الورك فلو لا يحفظ أو القائمة فارغة** | عدم تشغيل مايجريشن جدول `workflows` | تنفيذ: `docker exec -it chatwoot-rails-1 bundle exec rails db:migrate` |
| **الورك فلو تالف وتنسيقاته متداخلة** | عدم تحميل ملف CSS الخاص بـ VueFlow | تم دمجه في `dashboard.js`؛ اضغط `Ctrl + F5` في المتصفح |
| **زر ⚡ غير ظاهر في المحادثة** | فتح محادثة قديمة انتهت نافذة الـ 24 ساعة | تم فك ارتباط الزر بالنافذة؛ حدّث الكود واضغط `Ctrl + F5` |
| **404 page not found** | عدم ربط Traefik بمنفذ الحاوية 3000 | مراجعة وسوم Traefik في `docker-compose.yaml` وتشغيل أمر ربط الشبكة |
| **خطأ عند الرفع لـ GitHub (Husky)** | قيود الفحص المحلي قبل الرفع | الرفع باستخدام العلم: `git push origin develop --no-verify` |
