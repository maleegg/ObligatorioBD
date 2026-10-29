import os
import time
import mysql.connector
from mysql.connector import Error

# Leemos las variables de entorno configuradas en el docker-compose
DB_HOST = os.getenv("DB_HOST", "db")
DB_USER = os.getenv("DB_USER", "root")
DB_PASSWORD = os.getenv("DB_PASSWORD", "rootpassword123")
DB_NAME = os.getenv("DB_NAME", "torneo_interfacultades")
DB_PORT = int(os.getenv("DB_PORT", 3306))

def test_connection():
    print("Intentando conectar a la base de datos MySQL en Docker...")
    
    # Bucle de reintento por si la base de datos demora unos segundos más en arrancar
    while True:
        try:
            connection = mysql.connector.connect(
                host=DB_HOST,
                user=DB_USER,
                password=DB_PASSWORD,
                database=DB_NAME,
                port=DB_PORT
            )
            
            if connection.is_connected():
                db_info = connection.get_server_info()
                print(f" ¡Conexión exitosa a MySQL! Versión del servidor: {db_info}")
                
                cursor = connection.cursor()
                cursor.execute("SELECT DATABASE();")
                record = cursor.fetchone()
                print(f" Conectado a la base de datos: {record[0]}")
                
                cursor.close()
                connection.close()
                break
                
        except Error as e:
            print(f"⏳ La base de datos está iniciando... reintentando en 3 segundos. (Error: {e})")
            time.sleep(3)

if __name__ == "__main__":
    # Dejamos un pequeño margen inicial y probamos la conexión
    time.sleep(2)
    test_connection()
    
    # Aquí más adelante puedes dejar la app corriendo o iniciar tu servidor web
    print("El contenedor está listo para el desarrollo del obligatorio.")