# 베트남 환율 (Flutter)

베트남 여행용 동 ↔ 원 환율 계산기. 예전 Kivy 앱(저장소 루트의 `main.py`)을 Flutter로 새로 만든 버전이에요.

## 기능
- **환산**: 화면에 고정된 키패드로 바로 계산. `K`(000 붙이기), `00`/`000`, 사칙연산, 붙여넣기, 결과 눌러 복사
- **환산표**: 동 → 원 / 원 → 동, 표 복사
- **지폐 세기**: 지폐별 장수를 세면 합계와 원화 금액 표시
- **보여주기**: 고수 빼주세요 같은 문장을 화면 가득 크게
- **메모**: 자동 저장
- 환율: [ExchangeRate-API](https://www.exchangerate-api.com) 무료 공개 주소 (하루 1번 갱신), 직접 입력, 환전 수수료 보정
- 다크 모드 자동 지원

## APK 받기
GitHub → Actions → **Flutter APK** → 최신 실행 → 아래 Artifacts에서 다운로드.

## 직접 실행
```bash
cd flutter_app
flutter pub get
flutter test      # 테스트
flutter run       # 폰 연결 후 실행
```

## 구조
```
lib/
  core/money.dart         숫자 서식, 한국식 단위, 키패드 수식 (화면과 분리, 테스트 있음)
  core/rate_service.dart  환율 API
  state/app_state.dart    앱 상태 + 저장
  ui/                     화면
```
