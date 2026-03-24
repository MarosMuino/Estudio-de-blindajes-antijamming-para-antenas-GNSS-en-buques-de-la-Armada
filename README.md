# Estudio-de-blindajes-antijamming-para-antenas-GNSS-en-buques-de-la-Armada
Código de simulación electromagnética y procesado de datos GNSS para TFG sobre apantallamiento naval.
ç
[![MATLAB](https://img.shields.io/badge/MATLAB-R2023a-blue.svg)](https://www.mathworks.com/products/matlab.html)

Repositorio oficial con el código fuente y las herramientas de simulación desarrolladas para el Trabajo Fin de Grado (TFG) presentado en el Centro Universitario de la Defensa (CUD) - Escuela Naval Militar.

**Autor:** Marcos Muiño Martínez  
**Tutor:** José María Núñez Ortuño  
**Fecha:** Marzo 2026  

Descripción del Proyecto
Este repositorio contiene los *scripts* necesarios para replicar las simulaciones electromagnéticas y el procesado de datos empíricos descritos en la memoria del TFG. El objetivo del código es modelar matemáticamente la atenuación pasiva de una cavidad cilíndrica frente a interferencias intencionadas, estableciendo las dimensiones óptimas de un blindaje compatible con las antenas GNSS de la Armada y evaluar su impacto en la Dilución de Precisión (PDOP) de la constelación GPS.

## Estructura de los Scripts
El código está dividido en los siguientes módulos principales:
ANTENA_DE_PARCHE_1.m donde se diseña una antena genérica de GNSS
DIMENSIONAMIENTO_2.m donde se devuelve un mapa de calor que muestra el valor de la protección en funcion de las dimensiones del cilindro
PDOP_FRENTE_A_MASCARA_3.m devuelve una gráfica para establecer el valor máximo de máscara que se puede permitir el blindaje sin degradar exageradamente la precisión (almanaques YUMA)
RANGO_PDOP_CON_MASCARA_4.m devuelve la variación del rango de pdop a lo largo de un período de tiempo determinado y mascara establecida (almanaques YUMA)
DIAGRAMA_ANTENA_CON_CAVIDAD_5.m obtenemos el valor nuevo diagrama de protección de la antena
COMPARACION_CAVIDAD_MALLA_6.m grafica el diagrama resultante usando cavidad normal o con malla
UBX_A_TABLAS_DE_PRECISION_7.m recupera datos de precisión de posicionamiento a partir de grabaciones de u-center
UBX_A_AZIMUT_CN0_8.m grafica los valores de densidad de señal recibida respecto acimut de los satélites con datos de graabaciones de u-blox

## 🚀 Uso y Reproducibilidad
Para ejecutar las simulaciones, es necesario contar con **MATLAB** y la **Antenna Toolbox**. Se recomienda ejecutar los *scripts* en el orden listado anteriormente. 

> **Aviso:** La simulación de onda completa del cilindro puede requerir un tiempo de computación elevado dependiendo de la memoria RAM disponible. Se ha implementado un mallado adaptativo manual para mitigar este efecto.
