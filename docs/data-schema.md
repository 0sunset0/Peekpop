# Data Schema — Peekpop

서버/DB 없음(무계정 온디바이스 서비스). 로컬 상태는 `@AppStorage` 2개뿐.

| 키 | 타입 | 용도 |
|---|---|---|
| `hasSeenOnboarding` | Bool | 최초 실행 후 온보딩 스킵 여부 |
| `lastFreeUseDate` | Date? | (다음 버전) "하루 1회 무료" 과금 로직용. MVP 미사용, 필드만 예약 |

- 입력/처리 중 사진은 파이프라인 실행 동안만 메모리(`UIImage`/`CGImage`)에 존재하고 앱이 별도로 저장하지 않는다. 결과 이미지만 `PhotosUI`로 사용자 카메라롤에 저장된다.
- Core Data/SwiftData 등 영속 DB는 없다.
