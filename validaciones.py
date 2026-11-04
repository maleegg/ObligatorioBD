"""Validacion de campos en el backend (la segunda de las tres capas).

1) Front-end: los formularios HTML tienen required, min, max, maxlength, pattern...
2) Back-end (este archivo): se vuelve a revisar todo, porque el navegador se puede saltear.
3) Base de datos: tipos, NOT NULL, UNIQUE, CHECK, claves foraneas y triggers.

Uso:
    v = Validador(request.form)
    v.texto("nombre", "Nombre", 20)
    v.entero("ci", "Cedula", minimo=1)
    if not v.ok: ...mostrar v.errores...
    v.datos["nombre"]
"""
import re
from datetime import date

PATRON_EMAIL = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")


class Validador:
    def __init__(self, formulario):
        self.formulario = formulario
        self.errores = []
        self.datos = {}

    @property
    def ok(self):
        return not self.errores

    def _crudo(self, campo):
        return (self.formulario.get(campo) or "").strip()

    def texto(self, campo, etiqueta, largo_max, requerido=True):
        valor = self._crudo(campo)
        if not valor:
            if requerido:
                self.errores.append(f"{etiqueta} es obligatorio.")
            self.datos[campo] = None
            return None
        if len(valor) > largo_max:
            self.errores.append(f"{etiqueta} no puede tener mas de {largo_max} caracteres.")
        self.datos[campo] = valor
        return valor

    def email(self, campo, etiqueta, largo_max=100):
        valor = self.texto(campo, etiqueta, largo_max)
        if valor and not PATRON_EMAIL.match(valor):
            self.errores.append(f"{etiqueta} no tiene formato de correo valido.")
        return valor

    def entero(self, campo, etiqueta, minimo=None, maximo=None, requerido=True):
        crudo = self._crudo(campo)
        if not crudo:
            if requerido:
                self.errores.append(f"{etiqueta} es obligatorio.")
            self.datos[campo] = None
            return None
        try:
            valor = int(crudo)
        except ValueError:
            self.errores.append(f"{etiqueta} debe ser un numero entero.")
            self.datos[campo] = None
            return None
        if minimo is not None and valor < minimo:
            self.errores.append(f"{etiqueta} debe ser mayor o igual a {minimo}.")
        if maximo is not None and valor > maximo:
            self.errores.append(f"{etiqueta} debe ser menor o igual a {maximo}.")
        self.datos[campo] = valor
        return valor

    def fecha(self, campo, etiqueta, maxima=None):
        crudo = self._crudo(campo)
        if not crudo:
            self.errores.append(f"{etiqueta} es obligatoria.")
            self.datos[campo] = None
            return None
        try:
            valor = date.fromisoformat(crudo)
        except ValueError:
            self.errores.append(f"{etiqueta} no es una fecha valida (AAAA-MM-DD).")
            self.datos[campo] = None
            return None
        if maxima is not None and valor > maxima:
            self.errores.append(f"{etiqueta} no puede ser posterior a {maxima.isoformat()}.")
        self.datos[campo] = valor
        return valor

    def opcion(self, campo, etiqueta, opciones):
        valor = self._crudo(campo)
        if valor not in opciones:
            self.errores.append(f"{etiqueta}: debe elegir una opcion valida.")
            self.datos[campo] = None
            return None
        self.datos[campo] = valor
        return valor

    def booleano(self, campo):
        valor = self.formulario.get(campo) in ("1", "on", "true", "si")
        self.datos[campo] = valor
        return valor

    def agregar_error(self, mensaje):
        self.errores.append(mensaje)
