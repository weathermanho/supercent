# Aviator To Sky — 게임 디자인 문서

원본 C++/OpenGL 프로젝트 `AVIATOR TO SKY`를 Godot 4 (GDScript)로 포팅한 빌드의 현재 동작을 정리한 문서입니다.

---

## 1. 개요

- **장르**: 3D 사이드/백뷰 비행 슈팅
- **목표**: 앞에서 다가오는 벽의 빨간 **타겟**을 미사일로 격추, 벽 충돌은 회피하며 가능한 한 오래 비행
- **기조**: 박스(`BoxMesh`) 합성으로 만든 저폴리 아트, 부드러운 공기역학적 조작감

---

## 2. 좌표계와 카메라

| 항목 | 값 |
|---|---|
| Up 축 | +Y |
| 비행기 진행 방향 | +X (월드의 깊은 쪽으로) |
| 비행기 기본 위치 | `(-100, 100, 0)` |
| 카메라 위치 | `(-450, 200, 0)` |
| 카메라 시선 | `(1000, 100, 0)` |
| 적/벽/구조물 스폰 X | `+4000` (멀리), 사라짐 X `< -1000` |

카메라는 비행기 **뒤쪽 약간 위**에서 비행기가 날아가는 +X 방향을 바라봅니다. 적/빌딩 등은 화면 안쪽(원점 부근/+X 깊은 곳)에서 비행기 쪽(-X)으로 다가오는 것처럼 보입니다.

---

## 3. 조작

| 입력 | 동작 |
|---|---|
| 마우스 X/Y | 비행기 위치(Y/Z) 조종 — 커서 화면 위치로 부드럽게 추종 |
| 마우스 우클릭 | 미사일 발사 (한 번 클릭 = 한 발) |
| `R` | 게임 리셋 |
| `Esc` | 종료 |

### 마우스 → 비행기 매핑

매 프레임 카메라에서 마우스 커서로 레이를 쏘고, 비행기의 X-평면(`x = -100`)과의 교차점을 구해 **그 월드 좌표를 비행기의 목표 위치로 사용**합니다. 결과적으로 화면상 커서 위치와 비행기 위치가 일치합니다.

```gdscript
ray_origin = camera.project_ray_origin(screen_pos)
ray_dir    = camera.project_ray_normal(screen_pos)
t          = (-100 - ray_origin.x) / ray_dir.x
target_pos = ray_origin + ray_dir * t
```

목표 위치로 부드럽게 lerp (`plane_move_sensitivity = 0.005`)되어 원본의 공기역학적 lag 느낌을 유지합니다. 추격 지연(`target - current`)을 그대로 `rotation.z` (roll), `rotation.x` (pitch)에 사용해 비행기가 움직임 방향으로 자연스럽게 기울어집니다.

---

## 4. 게임플레이 요소

### 4.1 비행기 (AirPlane)

- 동체(빨간 cBox), 엔진, 꼬리, 날개, 풍방, 프로펠러(2.87 회전/초 ≈ 18 rad/s), 조종사, 바퀴 4개로 합성
- 조종사는 머리카락 12 큐브가 `cos`로 미세 흔들림
- 마우스로 Y/Z 이동, 회전(roll/pitch)은 추격 지연에서 자동 계산
- 충돌 시 `plane_collision_speed_x/y`가 일시적으로 적용되며 시간에 따라 댐핑

### 4.2 빌딩 / 벽 / 구조물

매 50 distance마다 한 세트가 `x=4000`에서 스폰:

- **좌우 빌딩 2개** (파란색, 1200×rand(300-500)×100): 통로 양옆에 고정 배치
- **벽 1개** (반투명 진청, rand 사이즈): 통로 중앙에 무작위 Y/Z로 배치
- **타겟 1개**: 벽 앞 30 단위에 빨간 저폴리 구체로 부착

매 5 distance마다 **배경 작은 흰 박스(structures)**가 좌우로 흩뿌려져 풍경 효과를 줍니다.

모두 매 프레임 `position.x -= speed * dt_ms * ennemies_speed * 5000`로 -X 방향 스크롤. `x < -1000`이 되면 해제.

### 4.3 타겟과 가이드 오버레이

원본의 `Tester::guideLines()`을 충실히 재현:

1. 매 프레임 비행기 위치에서 **+X 방향으로 12000 길이의 직선** 하나가 그려짐. 카메라가 멀리 있어 먼 끝점이 화면 거의 중앙에 고정된 것처럼 보임.
2. 각 벽에 대해, 이 forward ray와 벽의 `-X 면`의 교차점을 계산.
3. 교차점이 벽 면 안쪽(Y, Z 모두 범위 내)이면 그 위치에 **YZ 평면에 누운 원**을 그림.
4. 그 원과 빨간 타겟의 YZ 거리가 `OVERLAP_TOLERANCE = 18` 이내면 **lock-on 상태**:
   - 색이 **빨강**(`Color(1, 0.25, 0.25)`)으로 바뀜
   - 4 Hz로 **깜박임** (sine wave off-phase에는 그리지 않음)
5. lock-on이 아니면 원은 흰색 + 정적.

### 4.4 미사일

- 발사 위치: `airplane.position + Vector3(40, 0, 0)` — 비행기 위치와 동일한 Y/Z (록온 원과 정렬)
- 운동: 매 프레임 `velocity += 1.9`, `position.x += velocity * 0.25 + 0.156` (원본 그대로)
- 명중 판정: **X 스윕(swept)** 방식
  ```gdscript
  if prev_x <= t_pos.x and t_pos.x <= curr_x:
      if YZ_distance < HIT_RADIUS_YZ (= 25):  # 타겟 명중
  ```
  - 큰 step size에서도 미사일이 타겟을 그냥 통과해버리지 않음
  - 벽 충돌도 같은 swept 방식으로 처리되며, 명중 시 **흰 구 폭발(`WhiteSphere`)** 7~27개 생성

### 4.5 파티클

- 타겟 명중 시: 빨간 prism 15개 폭발 (`Particle.color_index = 1`, `scale = 7`)
- 사용 안 됨(코인 제거됨): 청록 prism (`color_index = 2`)
- 매 프레임 위치/스케일/회전 갱신, `duration = 0.3s` 후 자동 해제

---

## 5. 진행/상태 시스템

| 변수 | 초기 | 동작 |
|---|---|---|
| `distance` | 0 | 매 프레임 `speed * dt_ms * ratio_speed_distance(50)`만큼 누적 |
| `level` | 1 | distance가 `distance_for_level_update(1000)` 단위로 +1, `target_base_speed` 미세 상승 |
| `energy` | 70 | 매 프레임 `speed * dt_ms * ratio_speed_energy(3)`만큼 감소, 0이 되면 GAME OVER |
| `status` | `PLAYING(1)` | 0이 되면 비행기가 z축 회전하며 추락하고 모든 입력 무시 |
| `speed` | 0 → 점진 상승 | `base_speed * plane_speed`, 매 프레임 `base_speed`가 `target_base_speed`로 lerp |

### 속도 동작 (중요)

원본 C++의 `int planeSpeed` 타입 버그를 그대로 재현해 `plane_speed = 1.0` 고정. 즉 마우스 X로는 속도가 변하지 않고, **레벨업으로만 점진적으로 빨라짐** (레벨당 +0.86% 가량).

### GAME OVER

`energy < 1`이 되면 `status = STATUS_GAME_OVER`. AirPlane._update_falling이 실행되어:
- `speed *= 0.99` (감속)
- 비행기 roll이 PI/2로 수렴
- pitch 점진 증가
- Y 하강 (`plane_fall_speed *= 1.05`)
- 모든 파티클 즉시 제거

`R`로 씬 리로드.

---

## 6. 주요 튜닝 파라미터

[GameConfig.gd](scripts/GameConfig.gd)에 모두 모여 있습니다.

| 파라미터 | 값 | 의미 |
|---|---|---|
| `init_speed` | 0.00035 | 초기 base_speed |
| `increment_speed_by_level` | 0.000003 | 레벨업당 속도 증가 |
| `distance_for_level_update` | 1000 | 레벨업 간격 |
| `distance_for_ennemies_spawn` | 50 | 벽+타겟 스폰 간격 |
| `ennemy_distance_tolerance` | 10 | 비행기-벽 충돌 반경 |
| `plane_move_sensitivity` | 0.005 | 비행기 Y/Z lerp 속도 (낮을수록 끈끈함) |
| `plane_default_height` | 100 | 비행기 휴식 Y |
| `plane_amp_height` | 100 | Y 진폭(위아래로 ±100까지) |

[GuideOverlay.gd](scripts/GuideOverlay.gd):

| 파라미터 | 값 | 의미 |
|---|---|---|
| `CIRCLE_RADIUS` | 15 | 록온 원 반지름 |
| `OVERLAP_TOLERANCE` | 18 | 원-타겟 lock 판정 거리 |
| `FORWARD_LENGTH` | 12000 | 가이드 라인 길이 |
| `BLINK_HZ` | 4 | lock-on 깜박임 주파수 |

[Main.gd](scripts/Main.gd) 내부 상수:

| 파라미터 | 값 | 의미 |
|---|---|---|
| `HIT_RADIUS_YZ` | 25 | 미사일-타겟 YZ 명중 반경 |

---

## 7. HUD

화면 좌상단에 표시:
- `Distance: <누적 거리>   Level: <레벨>`
- 에너지 ProgressBar (0~100)
- GAME OVER 메시지 (게임 종료 시)

---

## 8. 원본 대비 변경사항

| 원본 (C++) | 현재 빌드 | 이유 |
|---|---|---|
| `int planeSpeed` truncate 버그 | `plane_speed = 1.0` 고정 | 원본 실효 거동을 재현 |
| `glRotatef(pAngle)` (degrees) | `rotation.x` (radians) | 단위 변환 |
| `timeGetTime()` (ms) | `delta * 1000` (ms) | 동일 시간 단위 |
| 수동 shadow-map 패스 | `DirectionalLight3D` + shadow | Godot 빌트인 |
| icosahedron 적 (Ennemy) | **제거됨** | 사용자 요청 |
| tetrahedron 코인 | **제거됨** | 사용자 요청 |
| 구름 링 (Sky) | **제거됨** | 사용자 요청 |
| 파도 지형 (Terrain) | **제거됨** | 사용자 요청 |
| 미사일 타겟 추적 | **제거됨** (단순 +X 직선 비행) | 록온 원과 정렬을 우선 |
| 즉시 거리 hit 판정 | swept X-crossing 판정 | 큰 step에서도 안정적 명중 |

남아 있는 미사용 파일: `Coin.gd/tscn`, `Ennemy.gd/tscn`, `Sky.gd`, `Terrain.gd` — 디스크에 있지만 어디서도 참조되지 않습니다.
