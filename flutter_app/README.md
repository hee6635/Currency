# 베트남 환율 (Flutter)

베트남 여행용 동 ↔ 원 환율 계산기. 예전 Kivy 앱(저장소 루트의 `main.py`)을 Flutter로 새로 만든 버전이에요.

## 기능
- **환산**: 화면에 고정된 키패드(갤럭시 계산기 배치: 지우기 키는 맨 위, % 자리에 국기 바꾸기 버튼)로 바로 계산. `00`/`000`, 사칙연산, 붙여넣기(50K 같은 표기도 인식), 결과 눌러 복사
- **말로 입력**: 위쪽 "말로 입력"을 누르고 말하면 바로 계산. 숫자는 남아 있어 이어서 말할 수 있고("오만" → "더하기 삼만"), 더하기 모드(설정)면 숫자만 말해도 더함. "지워"=마지막 하나, "다 지워"/"새로"=전부, "얼마"/"결과"= =. 말한 내용은 3초 동안 크게 표시
- **환산표**: 동 → 원 / 원 → 동, 표 복사
- **지폐 세기**: 지폐 그림을 보며 장수를 세면 합계와 원화 금액 표시 (사진 누르면 앞·뒷면 크게, 1천~50만동)
- **보여주기**: 고수 빼주세요 같은 문장을 그림과 함께 화면 가득 크게
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

## 그림 출처
- 보여주기 카드 그림: [Microsoft Fluent Emoji](https://github.com/microsoft/fluentui-emoji) (MIT, `assets/phrases/LICENSE-fluentui-emoji.txt`)
- 지폐 사진: 저장소 주인이 제공한 베트남 지폐 이미지에서 앞·뒷면을 잘라 사용 (`assets/notes/`)
