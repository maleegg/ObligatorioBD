FROM python:3.11-slim

WORKDIR /app

# mysql-connector-python esta escrito en Python puro: no hace falta compilar nada
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copiar el codigo de la aplicacion
COPY . .

# Flask escucha en el puerto 5000 dentro del contenedor
EXPOSE 5000
CMD ["python", "main.py"]
