# Supercent Showpiece Core Loop — Design Spec

**Date:** 2026-05-27
**Status:** Approved (user override of formal review gate)
**Owner:** dreamhighkwon@gmail.com (1인 개발, Godot 4.3, 약 20시간 예산)
**Source-of-truth handoff:** `e:\vive\0_new_supercent\Aviator_To_Sky_핸드오프.md`
**Aesthetic reference:** `e:\vive\0_new_supercent\image.png` (painterly desert + teal sky + giant orb silhouette)

---

## 1. Goal

Supercent 챌린지의 **1차 내부 심사자**가 30초 안에 "이거 광고 컷 잘 나오겠다"고 판단하게 만드는 단일 빌드를 만든다. 시장 CPI/리텐션이 아니라 **심사자가 느끼는 wow factor** 가 success metric.

이 spec의 **결과물**:

- Godot 4.3 프로젝트가 in-place 수정된 상태 (현 소스 위에서 작업, 새 프로젝트 X).
- 60~90초 코어 루프가 "약→강→거인 박살"로 빌드업되고, 화면이 흔들리고 슬로모가 걸리며 파편이 날린다.
- 분위기는 `image.png` — 따뜻한 모래색 지면 + 청록/시안 하늘 + 광활한 fog + 강한 실루엣 + 작은→거대 스케일 대비.
- 광고 SDK 없음. 메타 진행/서버/IAP 없음. 오프라인 완결.

핸드오프 §6.1의 코어 루프가 이 spec의 단위이고, §6.4 (탄도 손맛)는 그 안에 통합된다. 광고 SDK(§7 Day 5)는 **제외**.

## 2. Non-Goals (다시 꺼내지 말 것)

핸드오프 §4.4와 §6.3에 명시된 폐기/연기 항목은 이 spec에서도 OUT:

- 광고 SDK, AdMob, 인터스티셜 — **공모전 1차 제출이 목적, 광고는 무관.**
- 서버/온라인/리더보드, 영구 메타 진행, IAP, 가챠
- 적 AI/보스 패턴 (현 코드의 buildings/targets만으로 충분)
- 3단계 월드/서사
- 깊은 탄도 튜닝(homing 유형 분화, 차지샷, 약점) — 첫 제출 후
- 방어 트리 (핸드오프 부록 C — 공격 안정 후)

## 3. Aesthetic Direction (image.png 매칭)

이미지에서 추출한 톤을 현재 코드의 자산 위에 입힌다.

| 요소 | 이미지의 결정 | 현 코드 상태 | 적용 |
|---|---|---|---|
| 배경 하늘 | teal(상단) → 옅은 cyan/cream(지평선) 그라데이션 | flat `Color(0.92, 0.87, 0.71)` (SAND) | 그라데이션 sky shader 또는 ProceduralSky |
| 지면 | 따뜻한 모래/베이지, 디테일 거의 없음 | `Terrain.gd` 존재하나 씬에 미연결, 푸른 물 | 모래 plane으로 교체(단순 단색 + 옅은 fog) |
| 대기 원근 | 강한 haze — 먼 실루엣이 색에 녹아듦 | 없음 | World fog (depth-based, sand 톤, fade 1500~6000) |
| 실루엣 | 큰 형태로 단순화, 디테일 음영 적음 | 박스 누적 (cubic) | 그대로 유지(스타일과 어울림) + 짙은 음영용 backlight |
| 거대 스케일 | 인물 vs 거대 구체 대비 = 핵심 모티프 | 모든 target이 동일 크기 | **거인 표적**: 화면 절반을 채우는 거대 구체 형태로 |
| 컬러 팔레트 | sand(베이지) + teal + 짙은 brown 실루엣 + 적색 액센트 | `GameColors`에 이미 SAND/BLUE/DARK_BLUE/RED 존재 | 기존 팔레트 재활용, BLUE를 하늘로, SAND를 지면으로 |

**팔레트 재맵 (구체 값):**

- Sky top: 기존 `BLUE` (104,195,192) 또는 약간 더 채도 낮춰 `Color8(118,180,180)`
- Sky horizon: 기존 `SAND` 약간 채도 낮춤 `Color8(228,210,170)`
- Ground: 기존 `SAND` 그대로 또는 약간 더 따뜻하게 `Color8(232,210,165)`
- Fog: ground 톤과 동일, 거리 1500~6000에서 0→1
- Target (red icosahedron): 기존 `RED` 유지 (이미지의 적색 액센트와 맞음)
- Giant target: ground 톤의 짙은 brown(`BROWN`)로 — 이미지의 거대 구체와 같이 silhouette처럼

## 4. Architecture

핸드오프가 이미 도메인을 잘 나눠뒀고, 현 코드도 그 분할을 거의 따른다. 새 컴포넌트는 **얇은 매니저 노드** 4개만 추가하고, 나머지는 기존 노드의 `step()` 안에 끼워 넣는다.

```
Main (기존, coordinator)
├── Camera3D (기존) ──── CameraShaker (NEW, 카메라에 노이즈 오프셋 주입)
├── HUD (기존)
├── AirPlane (기존)
├── 동적 spawn:
│   ├── Missle (기존, 호밍 약화 + 속도합산)
│   ├── Building / Target (기존, 거인 변종 추가)
│   ├── Particle / WhiteSphere (기존, 양/속도 강화)
│   └── 추가: ShockwaveRing, FlashOverlay 단발성 이펙트
├── TimeScaler (NEW, hitstop + 거인 슬로모 제어)
├── Atmosphere (NEW, sky+fog+ground 매니지 — Sky.gd/Terrain.gd 대체)
└── ShowpieceDirector (NEW, "약→강→거인" 빌드업 타임라인 진행자)
```

**경계가 명확한 단위 (각 노드/스크립트 1개):**

1. **CameraShaker** — `apply_shake(intensity, duration)` 1개 메서드. Main이 호출. Camera transform 위에 노이즈 오프셋만 추가 (카메라 원본 transform은 건드리지 않음).
2. **TimeScaler** — `request_hitstop(duration)`, `request_slowmo(scale, duration)` 2개 메서드. `Engine.time_scale` 직접 조작은 안 함 (Engine.time_scale은 *전역*이라 HUD/Tween까지 멈춤). 대신 `GameConfig.time_scale` 값을 둬서 각 `step(dt_ms)` 호출 측이 곱한다. (현 코드가 이미 `dt_ms` 패턴이므로 침투 최소.)
3. **Atmosphere** — Main의 `_setup_lighting()`을 흡수 + sky gradient mesh + fog (`Environment.fog_*`) + 큰 sand-plane 지면. `Sky.gd`(구름 링) 파일은 보관만 하고 씬엔 미연결.
4. **ShowpieceDirector** — `_tick_playing` 안에서 `distance`를 보고 단계(0~3)를 결정하고, 단계별 스폰 빈도/크기 매개변수를 `GameConfig`에 주입. 거인 표적 트리거.
5. **Missle (수정)** — 호밍 약화: `LOCK_RADIUS` 축소 + `BOOST_ACCEL` 약화 + 비행기 속도 합산 + drop phase 후 약한 중력 유지.
6. **Main (수정)** — 위 매니저들을 인스턴스화, 파괴 시 ShockwaveRing/FlashOverlay 호출, 거인 표적 식별해 슬로모+풀 juice.

## 5. Subsystems

### 5.1 탄도 손맛 (Missle.gd 수정)

**현재:** `INITIAL_FORWARD_SPEED=120, INITIAL_DROP_SPEED=60, GRAVITY=500(drop only), BOOST_ACCEL=4500, MAX_SPEED=2200` — boost 시 거의 완전 호밍.

**변경:**

- **비행 속도 합산** (§6.4-1): launch 시 `velocity = aim_dir * INITIAL_FORWARD_SPEED + plane.linear_velocity_estimate`. AirPlane은 명시적 velocity가 없으므로 `position - prev_position` 기반 평활화된 추정값을 매 프레임 저장(`AirPlane.estimated_velocity: Vector3`).
- **호밍 약화** (§부록C "완전 유도 금지"): boost phase의 `BOOST_ACCEL`을 `4500 → 800` 수준으로 낮추고 `LOCK_RADIUS` `18 → 8`로. 결과: 살짝만 휘어 들어감, 빗나갈 수 있음 → 스킬천장 발생.
- **중력 낙하 (boost phase에도)** (§6.4-2): drop phase 끝나도 약한 중력 `120` (비행기 중력의 30%)을 계속 적용. 멀수록 낙차 보이게.
- **튜닝 변수 export**: 위 값들을 `GameConfig`에 옮기고 인스펙터/실기기에서 손으로 맞춤.
- **자동 락온 fallback 약화**: locked target이 없으면 자동 nearest 추적 → 비활성화. `_find_missle_target()`은 LOCK_RADIUS 안에 들어와야만 target을 리턴. 없으면 `null` → 미사일은 그냥 직진(중력 받으며).

### 5.2 파괴 juice (Main + CameraShaker + TimeScaler + 신규 이펙트)

**일반 표적 파괴 시:**

- Screen shake: `intensity=8, duration=0.12s`
- Hitstop: `duration=0.05s`
- Particle density 15 → 30, scale 5 → 8, duration 0.3 → 0.5
- Flash overlay: 흰색 0.15 알파, 0.06s fade out
- ShockwaveRing: 표적 자리에 평면 링 메쉬, scale `1 → 8` over `0.4s`, alpha 페이드

**벽(building) 파괴 시 (이미 white sphere 있음):**

- Sphere 수 7~27 → 20~50, scale 2~5 → 3~8, duration 0.9 → 1.4
- + screen shake/hitstop/flash 동일 적용
- + ShockwaveRing 추가

### 5.3 거인 피니시 (ShowpieceDirector + 거대 Target 변종)

- `ShowpieceDirector`가 distance 임계(예: 800m, 1600m, 2400m)마다 **giant_target**을 1번 스폰. 일반 wall + target 자리에 거대 변형 1개로 대체.
- Giant target 사양: 일반(반경 15) → **반경 120**, 어두운 brown 톤(silhouette), 일반 wall 대신 단독으로 배치.
- 피격 1번에 부서지지 않게 `hp = 3` (미사일 3발 누적).
- **마지막 미사일이 hp=0으로 만들면:**
  - `TimeScaler.request_slowmo(0.25, 1.5s)` — 0.25배속 1.5초.
  - Camera shake intensity 30, duration 0.6.
  - White sphere 80~120개, 큰 scale (10~18).
  - 풀 화면 flash 0.4 알파.
  - ShockwaveRing scale `1 → 40`, duration 0.8.
  - 거인 메쉬는 *조각으로 분리되지 않고* 부서지는 큐브 dust(WhiteSphere)로 덮인 채 alpha-fade 0.6s 후 `queue_free`.

### 5.4 무기 1→2→3 단계 (런 내 진화)

핸드오프 §6.1 "무기 1→2→3단계 진화(런 중 픽업)" — 단순 구현:

- `GameConfig.weapon_stage: int (1~3)` 추가.
- `_fire_missle()`에서 stage에 따라 미사일 수/크기 결정:
  - 1단계: 1발, SCALE=0.4 (현재값)
  - 2단계: 2발 (좌우 살짝 퍼짐), SCALE=0.55
  - 3단계: 3발 (부채꼴), SCALE=0.7
- 업그레이드 트리거: ShowpieceDirector가 distance 임계(400m, 1200m)마다 stage 증가. 픽업 코인 노드는 first cut에서 생략 (현 코드 `Coin.gd`는 있으나 미사용).

### 5.5 분위기 (Atmosphere)

- **Sky**: 화면 전체를 덮는 큰 quad 또는 `WorldEnvironment.Sky` + ProceduralSkyMaterial. Top color = teal, horizon = sand-tone.
- **Fog**: `Environment.fog_enabled = true`, `fog_light_color = SAND`, density 0.0008, depth-fade `1500~6000`. 멀리 있는 빌딩 실루엣이 sand 톤에 녹아듦.
- **Ground**: 거대 plane (`PlaneMesh` 10000x10000), y = -120 부근, SAND 톤. shader 없이 단색 + DirectionalLight로 옅은 명암.
- **Lighting**: 현 DirectionalLight 유지, light_color를 약간 따뜻하게 (`Color(1.0, 0.93, 0.82)`), 그림자 부드럽게.

### 5.6 리트라이 & 로컬 베스트

- `GameConfig.best_distance` + `user://best.save` 파일 IO. 사망 시 `distance`가 best보다 크면 저장.
- HUD에 "Best: NNN" 한 줄 추가.
- 사망 시 status_label에 "BEST! Press R to fly again" (베스트일 때) 또는 "Press R to fly again".

## 6. Data Flow

```
mouse →  Main._get_world_cursor() → AirPlane.set_world_target()
                                          ↓
                                    AirPlane.estimated_velocity (NEW)
                                          ↓
mouse click → Main._fire_missle() ─→ Missle.velocity = aim*F + plane.velocity (NEW)
                                          ↓
                                   Missle.step() — gravity always, weak homing
                                          ↓
                                   Main._fly_missles() — hit check
                                          ↓
                       (일반 표적)               (벽)               (거인 표적)
                          ↓                       ↓                    ↓
                CameraShaker.apply           +white_spheres++       TimeScaler.slowmo
                TimeScaler.hitstop          ShockwaveRing(big)     full juice combo
                ShockwaveRing                                       fade giant mesh
                FlashOverlay
                particles++
```

`ShowpieceDirector._tick(distance)` 는 위와 병렬로 매 프레임 돌며 다음 스폰의 종류/크기를 `GameConfig`에 주입한다.

## 7. Error / Edge Cases

- **Engine.time_scale 회피**: `GameConfig.time_scale`을 두고 각 노드의 `step(dt_ms)`에서 곱한다. HUD/입력은 영향 안 받음. (현 코드가 이미 dt_ms 패턴이라 침투 적음.)
- **Hitstop 누적 방지**: `TimeScaler.request_hitstop()`은 이미 hitstop 진행 중이면 *남은 시간을 max로 갱신* — 누적되지 않게.
- **호밍 약화 후 절대 못 맞추는 경우**: 자동 nearest fallback을 끄면 멀리 있는 표적은 직진 미사일론 못 맞을 수 있음. 의도된 디자인 — 락온 원 안에 들어가도록 가까이 조준해야 한다. 잔여 약한 호밍(`BOOST_ACCEL=800`)이 락온된 경우의 *조준 보조* 역할.
- **거인 hp 카운팅**: 미사일 3발에 부서지므로 `Target.hp`와 `take_damage(amt)` 추가. 거인 외 일반 표적은 `hp=1`로 동일 처리(분기 단순화).
- **거인 fade 중 충돌**: 거인 메쉬는 부서지는 순간 `hit_layer = NONE`으로 변경, 추가 충돌 방지.
- **로컬 저장 실패 (권한/저장공간)**: 조용히 무시 (베스트만 영향, 게임 진행 영향 없음).

## 8. Testing & Acceptance

### 8.1 Manual smoke (개발자)

- 빌드 실행 → 60초 동안 게임이 멈추지 않고 fps 안정 (목표 60).
- 거인 표적이 distance 800/1600/2400에서 정확히 1번씩 출현.
- 마지막 미사일이 거인을 부수면 슬로모 + 풀 juice가 발동.
- R 키로 즉시 리트라이.
- Best 값이 다음 실행에서도 유지됨.

### 8.2 Supercent Evaluator subagent (자동)

`supercent-evaluator` 역할의 subagent를 *각 구현 마일스톤*마다 1회 띄운다. 평가자는 다음을 *모르고 시작*하며 (cold) 빌드 산출물(스크린샷 시퀀스 또는 짧은 영상 파일)만 받아 평가한다:

평가 항목 (각 0~5점):

1. **첫 3초 훅** — 첫 3초에 "응?" 하고 시선 잡히는가?
2. **약→강 빌드업** — 무기/표적 escalation이 30초 안에 한눈에 보이는가?
3. **거인 피니시** — 마지막 컷이 광고 썸네일로 쓰일 만큼 강한가?
4. **컬러/분위기** — `image.png`의 톤과 같은 결인가?
5. **임팩트 강도** — 파괴가 묵직하게 느껴지는가? (juice의 종합)

**합격선**: 항목별 ≥ 3점, 총점 ≥ 18/25. 미달이면 구체 피드백을 받아 다음 사이클에 반영.

평가자 subagent는 **이 spec을 보지 않고** image.png + 빌드 산출물만 받음 — 정직한 콜드 리뷰가 되도록.

### 8.3 No automated unit tests

게임 코드 + 비주얼 튜닝이라 unit test ROI가 낮음. Manual smoke + evaluator subagent로 대신함.

## 9. Out of Scope (이 spec에서 빼는 명확한 라인)

- 광고 SDK / 보상형 광고
- 사운드 (현 프로젝트에 사운드 파이프라인 없음 — first cut에선 무음. 다음 spec)
- 무기 세대 진화 (기관총→미사일→레이저) — 이번 spec은 미사일 stage 1~3만
- 픽업 코인으로 무기 업그레이드 — distance 기반으로 단순화
- 깊은 보스 패턴, 약점, 차지샷
- 방어 진화 트리 (적이 쏘는 주체로의 전환)
- iOS 빌드 — Android APK만

## 10. Risks

1. **호밍 약화 후 사격이 너무 어려워짐** — 평가자가 첫 미사일을 못 맞추면 "약→강" 빌드업 자체가 안 보임. 완화: `LOCK_RADIUS=8` 부드러운 조준 보조 + 약한 잔여 호밍(`BOOST_ACCEL=800`)로 *어색하지 않은* 보정.
2. **fog/sky 변경 시 기존 sand-color clear color와 충돌** — clear color는 sky 그라데이션의 horizon 색과 정확히 맞춰야 봉합선이 안 보임.
3. **20시간 예산 초과** — 분위기(Atmosphere) 작업이 블랙홀이 될 수 있음. 합격선 통과시 추가 폴리시는 자제 (핸드오프 §9 원칙 3).
4. **거인 피니시가 한 번 보고 나면 흥미 떨어짐** — 평가자는 짧은 클립만 보므로 first-time wow만 살리면 됨. 리텐션 문제는 다음 spec.

## 11. Out-of-band Decisions (이 spec에서 결정한 새 사실들)

- 분위기는 `image.png`를 1차 reference로 잡음 (handoff에 없던 결정).
- 광고 SDK는 이 spec에서 빠짐 (handoff §7 Day 5와 다름, 사용자 결정).
- 평가자 subagent를 자동 QA로 도입 (handoff에 없던 메커니즘).
- 무기 진화 트리거는 픽업이 아니라 distance 기반으로 단순화.
- 자동 nearest-fallback 락온 제거 (handoff가 명시한 "완전 유도 금지" 원칙 적용).
