# docker 이해하기

학습일: 2026-11-04
강의: [Apache Airflow 설치 완전 정복: 설치 전 필수 개념부터 실습까지]
      [영상 링크:https://www.youtube.com/watch?v=LmQhHcueJs0]
실습 상태: 개념 학습 중, 아직 실행예정

## 1. 오늘 배운 내용

- **사용목적**
    - worker, db, scheduler 등 여러 서비스를 컨테이너 환경에서 구성할 수 있도록 함
    - 들여쓰기로 계층 속성을 정의하는 YAML 포맷 사용
    - docker_compost.yaml 에서 docker_compose up -d 실행


- **구성**
    ■ x-airflow-common
        - 공통 설정들 정의 구간
        - &airflow-common로 정의 후, <<: *airflow-common으로 재사용
        - airflow.cfg 내용 오버라이딩 
    ■ services
        - 컨테이너화 된 서비스 정의하는 구간
    ■ volumes
        - DB와 연결될 Docker Volume을 정의하는 구간

- **컨테이너 구성**
    ■ ## Airflow 2.10.5 서비스 구성

> 필수 여부는 강의의 CeleryExecutor 구성 기준이다.

| 서비스 | 역할 | 필수 여부 |
|---|---|:---:|
| `postgres` | Airflow의 메타데이터, 작업 상태, 변수 등을 저장·관리 | ✅ |
| `redis` | CeleryExecutor의 작업 메시지를 전달하는 브로커 | ✅ |
| `airflow-webserver` | Airflow 웹 인터페이스(UI) 제공 | ✅ |
| `airflow-scheduler` | DAG의 일정과 작업 의존성을 확인하여 실행할 작업을 예약 | ✅ |
| `airflow-worker` | DAG에 정의된 실제 Task를 실행하고 결과 처리 | ✅ |
| `airflow-triggerer` | 지연 실행된 Task의 비동기 대기 처리 담당 | ✅ |
| `airflow-init` | Airflow 초기 설정 및 메타데이터 DB 초기화 수행 | ✅ |
| `airflow-cli` | Airflow 명령어를 실행하기 위한 임시 컨테이너 | ❌ |
| `flower` | Celery 워커 상태를 모니터링하는 웹 UI 서비스 | ❌ |
 
> `airflow-init`은 초기화 후 종료된다.
> Redis와 Celery 워커는 Executor 선택에 따라 필요성이 달라진다.
> Triggerer는 지연 실행 기능을 사용하는 경우 필요하다.