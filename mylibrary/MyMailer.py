# 메일 발송에 필요한 내장 모듈 참조

# -> 경로 정보를 취득하기 위한 모듈
import os
# -> 발송서버와 연동하기 위한 모듈
from smtplib import SMTP
# -> 본문 구성 기능
from email.mime.text import MIMEText
# -> 파일을 Multipart 형식으로 변환
from email.mime.application import MIMEApplication
# -> 파일을 본문에 추가하는 기능 제공
from email.mime.multipart import MIMEMultipart 

#-----------------
# 메일 발송 함수
#-----------------
def sendMail(from_addr, to_addr, subject, content, files=[]):
    # 컨텐츠 형식(plain or html)
    content_type = 'plain'

# 로그인 계정 이름
    user_name = "rnjswodyd1@gmail.com"

# 비밀번호
    password = "scah sksp vcti pfbz "

# 구글 발송 서버 주소와 포트
    smtp = "smtp.gmail.com"
    port = 587

    # 메일 제목, 보내는 사람, 받는 사람, 내용 구성
    # 메일 발송 정보를 저장하기 위한 객체
    msg = MIMEMultipart()

    msg['Subject'] = subject # 메일 제목
    msg['From'] = from_addr  # 보내는 사람
    msg['To'] = to_addr      # 받는 사람

    # 본문 설정
    msg.attach(MIMEText(content, content_type))

    # 리스트 변수의 원소가 하나라도 존재할 경우 True
    if files:
        for file_item in files:
            if os.path.exists(file_item):
                # 바이너리(b) 형식으로 읽기(r)
                with open(file_item, 'rb') as f:
                    # 전체 파일 경로에서 이름만 추출
                    basename = os.path.basename(file_item)
                    # 파일의 내용과 파일이름을 메일에 첨부할 형식으로 변환
                    part = MIMEApplication(f.read(), Name=basename)
                
                    # 파일첨부
                    part['Content-Disposition'] = 'attachment; filename ="%s"' % basename
                    msg.attach(part)

                    print(basename, "가 첨부되었습니다")

# 메일 보내기

    mail = SMTP(smtp)
# 메일 서버 접속
    mail.ehlo()
# 메일 서버 연동 설정
    mail.starttls()
# 메일 서버 로그인
    mail.login(user_name, password)
# 메일 보내기
    mail.sendmail(from_addr, to_addr, msg.as_string())
# 메일 서버 접속 종료
    mail.quit()

#-----------
# 테스트 코드
#-----------
if __name__ =="__main__":
    sendMail("rnjswodyd1@gmail.com", "rnjswodyd1@khu.ac.kr", "메일 발송 테스트", "메일 발송 테스트")
