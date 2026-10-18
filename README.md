# Chess with AI

Game cờ vua chơi với máy trên Android, viết bằng Flutter. Có 4 cấp độ khó
(Dễ / Trung bình / Khó / Rất khó) dựa trên thuật toán minimax + alpha-beta
pruning chạy trong một isolate riêng (không làm giật giao diện). Tích hợp
quảng cáo AdMob (banner + interstitial) để chuẩn bị publish lên Google Play.

## Cấu trúc dự án

```
lib/
  main.dart                 # Khởi tạo AdMob, chạy app
  game/
    chess_ai.dart            # Engine AI: minimax, đánh giá bàn cờ, các cấp độ
    game_controller.dart     # Quản lý luật chơi, lượt đi, trạng thái ván cờ, tính điểm
    score_service.dart       # Công thức tính điểm + đăng nhập/bảng xếp hạng Play Games
  screens/
    home_screen.dart         # Màn hình chọn cấp độ + quân cầm, trạng thái đăng nhập
    game_screen.dart         # Màn hình chơi: bàn cờ, banner ads, kết quả ván + điểm
  services/
    ads_service.dart         # Bọc AdMob banner/interstitial
  widgets/
    chess_board.dart         # Vẽ bàn cờ 8x8, xử lý chọn quân/phong cấp
tool/
  patch_signing.js           # CI: gắn signingConfig release vào build.gradle(.kts)
  proguard-rules-extra.pro   # CI: rule R8 giữ lại class WorkManager cần
  games-ids.xml.template     # CI: sinh games-ids.xml cho Play Games Services
.github/workflows/
  build-apk.yml              # Build APK/AAB tự động trên GitHub Actions (cloud)
```

Thư mục `android/` (và `ios/`, `web/`...) **không** được commit vào git —
xem phần "Vì sao không có thư mục android/" bên dưới.

## Vì sao không có thư mục android/?

Máy hiện tại chưa cài Flutter SDK / Android Studio, nên mình không tự
`flutter create` để sinh ra project native được. Thay vào đó:

- Toàn bộ code Dart/Flutter (phần logic + giao diện) đã viết đầy đủ ở đây.
- File `.github/workflows/build-apk.yml` sẽ, mỗi khi chạy trên GitHub Actions:
  1. Cài Flutter trong máy ảo cloud.
  2. Chạy `flutter create --platforms=android .` để tự sinh khung project
     Android (gradle, AndroidManifest.xml, icon mặc định...).
  3. Vá thêm vào `AndroidManifest.xml`: quyền INTERNET, AdMob App ID (dùng
     ID TEST của Google nếu bạn chưa cấu hình secret thật), và tên app
     hiển thị "Chess with AI".
  4. `flutter pub get`, sinh icon app từ `assets/icon/icon.png` bằng
     `flutter_launcher_icons`, rồi `flutter build apk --release`.
  5. Đăng file APK lên phần **Artifacts** của lần chạy đó để bạn tải về.

Ưu điểm: bạn không cần cài đặt gì nặng trên máy để có file APK dùng thử.
Khi nào bạn muốn tùy biến sâu hơn (icon riêng, cấu hình ký release cố định),
nên cài Flutter + Android Studio và bỏ `/android/` ra khỏi `.gitignore` để
commit hẳn thư mục đó, thay vì sinh lại mỗi lần build.

Lưu ý: plugin `google_mobile_ads` bản mới nhất yêu cầu `minSdk 24` trở lên
(Android 7.0+), nên workflow cũng tự nâng `minSdkVersion`/`compileSdk` của
project lên 24/36 sau bước `flutter create` — máy chạy Android cũ hơn 7.0
sẽ không cài được app, đây là đánh đổi hợp lý vì thị phần Android <7.0 hiện
rất nhỏ.

## Cách lấy file APK

1. Tạo một repo GitHub (private hoặc public đều được) và push toàn bộ thư
   mục này lên (xem lệnh git ở cuối README).
2. Vào tab **Actions** trên GitHub → chọn workflow **Build Android APK** →
   **Run workflow** (hoặc chỉ cần push lên nhánh `main`, workflow tự chạy).
3. Đợi build xong (khoảng 3-5 phút), mở lần chạy đó, kéo xuống phần
   **Artifacts**, tải file `chess-app-release-apk`.
4. Giải nén ra được `app-release.apk`, copy vào điện thoại Android và cài
   (cần bật "Cài từ nguồn không xác định" trong Settings).

File APK build theo cách này **chỉ ký bằng debug key** — cài thử trên điện
thoại thoải mái, nhưng **Google Play sẽ từ chối** vì đó là khóa debug công
khai. Xem phần ký release bên dưới trước khi publish thật.

## Muốn xem giao diện nhanh mà chưa cài Android SDK?

Nếu bạn cài Flutter SDK riêng (không cần Android Studio/SDK), bạn vẫn có
thể xem giao diện chạy trên trình duyệt để thử nghiệm nhanh, không build
ra APK:

```
flutter pub get
flutter run -d chrome
```

## Trước khi publish lên Google Play — checklist

1. **Tài khoản AdMob thật**
   - Đăng ký tại https://admob.google.com, tạo một App mới, tạo 2 Ad unit:
     1 Banner, 1 Interstitial.
   - Lấy "App ID" (dạng `ca-app-pub-xxxxxxxxxxxxxxxx~yyyyyyyyyy`) và thêm
     vào GitHub repo: Settings → Secrets and variables → Actions → New
     repository secret, tên `ADMOB_APP_ID`.
   - Thay 2 hằng số test trong [lib/services/ads_service.dart](lib/services/ads_service.dart)
     (`_testBannerAndroid`, `_testInterstitialAndroid`) bằng Ad unit ID thật
     của bạn.
   - Test ads chỉ để dev thử, **không được** tự bấm quảng cáo của chính
     mình sau khi dùng ID thật — vi phạm chính sách AdMob có thể bị khóa
     tài khoản.

2. **Package name / tên nhà phát triển**
   - Hiện đang dùng org `com.trungchess`, project `chess_app` → applicationId
     `com.trungchess.chess_app`. Muốn đổi thì sửa dòng `--org` trong
     `.github/workflows/build-apk.yml`.

3. **Ký release (bắt buộc để publish)**
   - Workflow đã có sẵn bước "Configure release signing": nếu 4 secret bên
     dưới tồn tại trên GitHub repo, nó tự giải mã keystore, tạo
     `android/key.properties`, và trỏ `signingConfig` của bản release sang
     keystore đó trước khi build — cả file APK lẫn AAB đều được ký thật.
     Thiếu secret thì build vẫn chạy nhưng quay lại ký bằng debug key như
     cũ (chỉ để cài thử, Play Store sẽ từ chối).
   - Vào GitHub repo → **Settings → Secrets and variables → Actions → New
     repository secret**, thêm 4 secret:
     | Secret | Giá trị |
     |---|---|
     | `KEYSTORE_BASE64` | Nội dung file keystore, mã hoá base64 |
     | `KEYSTORE_PASSWORD` | Mật khẩu keystore |
     | `KEY_ALIAS` | Alias của key trong keystore |
     | `KEY_PASSWORD` | Mật khẩu key |
   - **Giữ file keystore thật kỹ** — mất file này (hoặc quên mật khẩu) thì
     không bao giờ update được app đã publish nữa, phải tạo app mới hoàn
     toàn trên Play Console. Đừng commit file keystore hay
     `key.properties` vào git (đã có sẵn trong `.gitignore`).
   - Tự tạo keystore mới (nếu cần, chạy trên máy có cài JDK — `keytool` đi
     kèm sẵn):
     ```
     keytool -genkeypair -v -keystore chess-with-ai-release.jks -alias chesswithai -keyalg RSA -keysize 2048 -validity 10000
     ```
     rồi mã hoá base64 để dán vào secret `KEYSTORE_BASE64` (PowerShell):
     ```powershell
     [Convert]::ToBase64String([IO.File]::ReadAllBytes("chess-with-ai-release.jks")) | Set-Clipboard
     ```
     (giờ đã có sẵn trong clipboard, chỉ cần dán trực tiếp vào ô secret).
   - CI build ra cả **APK** (`chess-app-release-apk`, cài thử trực tiếp
     lên điện thoại) và **AAB** (`chess-app-release-aab`, dùng file này để
     nộp lên Play Console — Play Store bắt buộc định dạng AAB cho app
     mới).

4. **Icon ứng dụng**
   - Đã cấu hình sẵn: `assets/icon/icon.png` là icon nguồn, workflow tự
     chạy `dart run flutter_launcher_icons` (cấu hình trong `pubspec.yaml`)
     sau bước `flutter pub get` để sinh icon cho mọi kích thước mipmap.
     Muốn đổi icon, chỉ cần thay file `assets/icon/icon.png` (ảnh vuông,
     nên dùng PNG không có góc bo sẵn để Android tự bo theo từng launcher)
     rồi push lại.

5. **Google Play Games Services (đăng nhập + bảng xếp hạng)**
   - App phải đã tồn tại trên Play Console trước (kể cả ở dạng nháp) thì
     mới link Play Games Services được.
   - Play Console → menu **Play Games Services** → **Setup and management**
     → **Configuration**, làm theo hướng dẫn để tạo project (nếu chưa có
     Google Cloud project liên kết, Play Console sẽ tự tạo giúp) và cấu
     hình màn hình xin quyền OAuth (OAuth consent screen).
   - Vẫn ở **Configuration**, tạo một **Leaderboard** mới (vd tên "Điểm cao
     nhất"), ghi lại **Leaderboard ID** (dạng chuỗi dài, không phải tên
     hiển thị).
   - Vào **Configuration → Credentials**, bấm **Get resources** để tải file
     XML — trong đó có `app_id` (một dãy số). Đây chính là giá trị cần cho
     secret `PLAY_GAMES_APP_ID`.
   - Bấm **Publishing** → **Publish** để Play Games Services có hiệu lực
     (ở trạng thái Draft thì chỉ tài khoản tester dùng được).
   - (Tuỳ chọn) Vẫn ở **Configuration**, tạo thêm 4 **Achievement**: "Chiến
     thắng đầu tiên", "10 ván thắng", "Chuỗi 5 ván thắng", "Thắng ở Rất khó"
     — ghi lại 4 Achievement ID theo đúng thứ tự này.
   - Thêm các secret vào GitHub (Settings → Secrets and variables → Actions):
     | Secret | Giá trị |
     |---|---|
     | `PLAY_GAMES_APP_ID` | `app_id` lấy từ bước Credentials ở trên |
     | `PLAY_GAMES_LEADERBOARD_ID` | Leaderboard ID vừa tạo |
     | `PLAY_GAMES_ACHIEVEMENT_IDS` | (tuỳ chọn) 4 Achievement ID cách nhau bởi dấu phẩy, đúng thứ tự: thắng đầu tiên,10 ván thắng,chuỗi 5 ván,thắng Rất khó |
   - Thiếu secret nào thì build vẫn chạy bình thường, chỉ là tính năng
     tương ứng (đăng nhập/bảng xếp hạng/thành tích) sẽ âm thầm không hoạt
     động (không crash) cho tới khi bạn cấu hình xong — xem
     [lib/game/score_service.dart](lib/game/score_service.dart).
   - Trước khi test đăng nhập trên điện thoại thật: tài khoản Google trên
     máy đó phải được thêm làm **tester** trong Play Console (mục **Testers**
     dưới Play Games Services), nếu không sẽ bị từ chối truy cập vì app
     chưa published rộng rãi.

6. **Google Play Console**
   - Đăng ký tài khoản nhà phát triển (phí một lần 25 USD):
     https://play.google.com/console
   - Tạo app mới, điền mô tả, ảnh chụp màn hình, banner.
   - Khai báo **Data Safety** (bắt buộc vì có AdMob — AdMob có thể thu
     thập Advertising ID để cá nhân hoá quảng cáo).
   - Cung cấp **Chính sách quyền riêng tư** (Privacy Policy URL) — bắt
     buộc với app có quảng cáo.
   - Kiểm tra `targetSdkVersion`/`compileSdkVersion` đáp ứng yêu cầu mới
     nhất của Play Store tại thời điểm nộp (Flutter bản stable mới nhất
     thường đã tự set đúng).

## Cấp độ khó hoạt động thế nào

`lib/game/chess_ai.dart` định nghĩa 4 mức, tương ứng độ sâu tìm kiếm
minimax + xác suất đi ngẫu nhiên (để mức Dễ luôn có thể thắng được):

| Cấp độ      | Độ sâu tìm kiếm | Xác suất đi ngẫu nhiên |
|-------------|-----------------|-------------------------|
| Dễ          | 1               | 35%                     |
| Trung bình  | 2               | 15%                     |
| Khó         | 3               | 0%                      |
| Rất khó     | 4               | 0%                      |

Muốn mạnh hơn nữa (ví dụ dùng engine Stockfish thật thay vì minimax tự
viết), có thể thay `chess_ai.dart` bằng plugin `flutter_stockfish`, đổi
lại phức tạp hơn vì cần đóng gói binary theo từng kiến trúc CPU (ARM).

## Cách tính điểm

Chỉ **thắng** (chiếu hết) mới được điểm — thua hoặc hòa thì không. Công
thức trong `lib/game/score_service.dart`:

```
điểm = điểm_gốc_theo_cấp_độ × hệ_số_tốc_độ
hệ_số_tốc_độ = clamp(1.5 − số_phút_chơi/20, 0.5, 1.5)
```

| Cấp độ      | Điểm gốc |
|-------------|----------|
| Dễ          | 100      |
| Trung bình  | 250      |
| Khó         | 500      |
| Rất khó     | 1000     |

Thắng càng nhanh, hệ số càng gần 1.5 (thắng gần như ngay lập tức); thắng
càng lâu (từ 20 phút trở lên), hệ số giảm dần về mức sàn 0.5 chứ không về
0, nên một ván thắng chậm vẫn luôn được điểm. Điểm cao nhất được lưu cục
bộ trên máy (theo từng cấp độ + tổng thể, qua `shared_preferences`) và
đồng thời nộp lên bảng xếp hạng Play Games Services nếu người chơi đã
đăng nhập.

## Các tính năng khác

- **Gợi ý nước đi**: nút bóng đèn trên màn hình chơi, AI tìm nước tốt nhất
  cho người chơi (không tính vào chế độ 2 người chơi).
- **Lưu & tiếp tục ván đang chơi**: tắt app giữa chừng không mất ván, màn
  hình chính sẽ hiện thẻ "Tiếp tục ván đang chơi" khi mở lại.
- **2 người chơi cùng máy**: chọn chế độ "2 người chơi" ở màn hình chính,
  bỏ qua AI — không tính điểm/lịch sử/thành tích cho ván này.
- **Âm thanh & rung**: dùng âm hệ thống + haptic, không cần file âm thanh
  riêng; có thể tắt trong màn hình **Cài đặt**.
- **Đổi màu bàn cờ**: 3 bộ màu (Cổ điển/Rừng xanh/Đại dương) trong **Cài
  đặt**.

## Đưa code lên GitHub

```
git init
git add .
git commit -m "Initial commit: chess app with AI + AdMob"
git branch -M main
git remote add origin <URL_REPO_CUA_BAN>
git push -u origin main
```
