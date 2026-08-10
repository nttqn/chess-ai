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
    game_controller.dart     # Quản lý luật chơi, lượt đi, trạng thái ván cờ
  screens/
    home_screen.dart         # Màn hình chọn cấp độ + quân cầm
    game_screen.dart         # Màn hình chơi: bàn cờ, banner ads, kết quả ván
  services/
    ads_service.dart         # Bọc AdMob banner/interstitial (đang dùng TEST ID)
  widgets/
    chess_board.dart         # Vẽ bàn cờ 8x8, xử lý chọn quân/phong cấp
.github/workflows/
  build-apk.yml              # Build APK tự động trên GitHub Actions (cloud)
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
   - Tạo keystore (chạy trên máy có cài JDK, chạy 1 lần, lưu file này thật
     kỹ, mất là không update được app nữa):
     ```
     keytool -genkey -v -keystore chess-release.keystore -alias chess -keyalg RSA -keysize 2048 -validity 10000
     ```
   - Cách đơn giản nhất để CI dùng được keystore này: mã hoá base64 file
     keystore, lưu làm GitHub secret (`KEYSTORE_BASE64`, cùng
     `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`), rồi thêm bước vào
     `build-apk.yml` để giải mã file và trỏ `signingConfig` trong
     `android/app/build.gradle` sang keystore đó trước khi build — hoặc,
     đơn giản hơn, cài Flutter/Android Studio cục bộ, `flutter create`
     một lần, bỏ `/android/` khỏi `.gitignore`, cấu hình signing trực tiếp
     trong `android/app/build.gradle` như hướng dẫn chính thức của Flutter:
     https://docs.flutter.dev/deployment/android#signing-the-app
   - Khi đã ký đúng, nên build file **AAB** thay vì APK để nộp lên Play
     Console: `flutter build appbundle --release`.

4. **Icon ứng dụng**
   - Đã cấu hình sẵn: `assets/icon/icon.png` là icon nguồn, workflow tự
     chạy `dart run flutter_launcher_icons` (cấu hình trong `pubspec.yaml`)
     sau bước `flutter pub get` để sinh icon cho mọi kích thước mipmap.
     Muốn đổi icon, chỉ cần thay file `assets/icon/icon.png` (ảnh vuông,
     nên dùng PNG không có góc bo sẵn để Android tự bo theo từng launcher)
     rồi push lại.

5. **Google Play Console**
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

## Đưa code lên GitHub

```
git init
git add .
git commit -m "Initial commit: chess app with AI + AdMob"
git branch -M main
git remote add origin <URL_REPO_CUA_BAN>
git push -u origin main
```
