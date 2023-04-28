# asm_leer_archivo_texto
Programas en ensamblador del MASM32 para leer un archivo de texto línea por línea.

Se incluyen dos versiones del programa. Ambos leen  el contenido de un archivo de texto, usando la API de Windows "ReadFile".

* read_file_block.asm -> Hace la lectura usando un bloque de memoria de tamaño fijo y varias lecturas para leer todas las líneas. Para más información sobre este código revisar el artículo: http://blogdetito.com/2023/04/26/leyendo-archivo-linea-por-linea-en-ensamblador-masm32-parte-1/
* read_file_all.asm -> Vuelva primero todo el contenido del archivo a memoria dinámica, antes de hacer la lectura línea por línea. Para más información sobre este código revisar el artículo:

