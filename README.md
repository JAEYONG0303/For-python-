# 학원수업 (SeSAC)

파이썬 기초부터 딥러닝까지, 수업에서 실습한 노트북을 모아둔 저장소입니다.
노트북 115개, 2025-10-15 ~ 진행 중.

---

## 폴더 구조

| 경로 | 내용 | 노트북 |
|---|---|---:|
| `./251015 ~ 251106 LAB 1~12` | 파이썬 기초 — 변수, 조건문, 반복문, 리스트, 딕셔너리, 함수 | 13 |
| `DATA ANALISIS BASIC/LAB 1` | NumPy — ndarray, 형태 변환, 기초 통계량 | 6 |
| `DATA ANALISIS BASIC/LAB 2` | pandas — Series, DataFrame | 3 |
| `DATA ANALISIS BASIC/LAB 3~4` | 데이터 확인, 전처리, 결측치·이상치 정제 | 6 |
| `DATA ANALISIS BASIC/LAB 5` | 병합, 정렬, 필터링, 그룹 집계 | 4 |
| `DATA ANALISIS BASIC/LAB 6. 데이터 전처리` | 재구조화, 파생변수, 명목형 인코딩 | 4 |
| `DATA ANALISIS BASIC/LAB 7. 시각화` | matplotlib / seaborn, 서브플롯, 지도 시각화 | 12 |
| `DATA ANALISIS BASIC/LAB 8. 통계` | 기술통계 → 가설검정 → T-test / ANOVA → 회귀 → 시계열 | 14 |
| `DATA ANALISIS BASIC/LAB 9. GIS` | QGIS 데이터 활용 | 1 |
| `DATA ANALISIS BASIC/Project File` | 미니 프로젝트 — Apple Quality, Diamonds, Insurance, Semi-Project | 4 |
| `LAB 10. 머신러닝` | 군집 → 차원축소 → 회귀 → 분류 → 부스팅 → 추천 → 시계열 | 39 |
| `LAB 11. 딥러닝` | 인공신경망 — 회귀, 이항분류, 다항분류, 비정형 | 5 |

### 그 밖의 파일

| 파일 | 용도 |
|---|---|
| `코드 무한 연습용.ipynb` | 문법 반복 연습장 (241셀) |
| `오답 노트.ipynb` | 틀린 문제 정리 |
| `프로그래머스 코테 .ipynb` | 코딩테스트 풀이 |
| `파이썬 코드 조각 모음.ipynb` | 자주 쓰는 코드 스니펫 |
| `mylibrary/` | 직접 만든 모듈 (`mymod1~3`, `MyMailer`) |
| `*.ttf` | 한글 그래프용 폰트 (NanumGothic, NotoSansKR, MaruBuri) |

---

## 자동 커밋

수업하며 바뀐 파일은 **하루에 한 번 자동으로 커밋 / 푸시**됩니다.

- **실행 시점**: 매일 22:00, 그리고 로그온 5분 뒤
  (PC를 켜두지 않는 날이 있어서 시점을 두 개 잡았습니다)
- **하루 한 번만**: 그날 이미 커밋이 있으면 — 손으로 한 커밋이라도 — 건너뜁니다.
  커밋은 공개 저장소에 영구히 남기 때문에 하루 여러 줄이 쌓이지 않게 합니다.
- **변경이 없는 날**: 아무것도 하지 않습니다 (빈 커밋을 만들지 않음).

| 파일 | 역할 |
|---|---|
| `tools/daily-commit.ps1` | 변경분을 모아 커밋 메시지를 만들고 push |
| `tools/register-task.ps1` | 위 스크립트를 Windows 작업 스케줄러에 등록 |
| `tools/daily-commit.log` | 실행 기록 (커밋 안 됨) |

### 직접 실행

```powershell
# 무엇을 커밋할지 미리 보기 (실제로 커밋하지 않음)
pwsh -File "tools\daily-commit.ps1" -DryRun

# 지금 바로 커밋 + push
pwsh -File "tools\daily-commit.ps1"
```

### 실행 시각 변경 / 해제

```powershell
pwsh -File "tools\register-task.ps1" -At "07:30"   # 시각 변경
pwsh -File "tools\register-task.ps1" -Remove       # 자동 커밋 끄기
```

---

## 노트북 작성 규칙

셀 제목, 주석, import 순서 등은 [노트북 작성 규칙.md](노트북%20작성%20규칙.md)를 따릅니다.
