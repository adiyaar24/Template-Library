FROM python:3

ADD requirements.txt /app/requirements.txt
WORKDIR /app

RUN pip3 install -r requirements.txt

ADD app.py /app/app.py

CMD ["python3", "/app/app.py"]
