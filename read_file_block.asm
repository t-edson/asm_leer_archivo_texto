include \masm32\include\masm32rt.inc
.const
    LINE_SIZE = 100         ;Longitud máxima de una línea
.data
    filePath   db "input.tit", 0
    hFile      HANDLE ?     ;Manejador de archivo 
    buffer     db LINE_SIZE dup(?), 0    ;Bolsa de almacenamiento
    bytesRead  dword ?      ;Número de bytes leídos
    f_eof      db 0         ;Bandera de fin de archivo
    p_eol      dword ?      ;Puntero a fin de cadena en "buffer".
    c_eol      db ?         ;Caracter EOL encontrado. 
.code
;Proc. que posiciona "p_eol" al final de la línea que se encuentra 
;actualmente en "buffer". El final de la línea se reconoce por el 
;delimitador 0Ah o 0Dh. Si no se encuentra un delimitador de línea
;sale dejando "p_eol" apuntando al final de buffer + 1.
;Actualiza "c_eol".
search_EOL PROC
    mov edi, offset buffer
    add edi, bytesRead
    mov p_eol, offset buffer ;Inicio de buffer
    .WHILE  p_eol<edi
        mov esi, p_eol
        .IF byte ptr [esi] == 0Ah ;¿Salto de línea LF?
            mov c_eol, 0Ah  ;Guarda caracter
            .BREAK 
        .ENDIF
        .IF byte ptr [esi] == 0Dh ;¿Salto de línea CR?
            mov c_eol, 0Dh  ;Guarda caracter
            .BREAK 
        .ENDIF
        inc p_eol     ;Siguiente byte
    .ENDW
    ;Marca fin de línea para que se muestre solo esa línea.
    mov esi, p_eol
    mov byte ptr [esi], 0h
    ret
search_EOL ENDP
;Proc. para abrir un archivo. Actualiza "hFile" y "f_eof".
open_file PROC  
    invoke CreateFile, addr filePath, GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL
    mov hFile, eax  ; Guardar el identificador de archivo
    mov f_eof, 0      ; Inicializa bandera de fin de archivo
    ;La cadena a leer queda en "buffer"
    ;Inicia "p_eol" para forzar a "read_line" a hacer la primera lectura de disco.
    mov p_eol, offset buffer + LINE_SIZE
    ret
open_file ENDP
;Proc. para leer un bloque de datos del archivo "hfile". Actualiza 
;"f_eof".
read_block PROC
    ;Lectura desde disco
    invoke ReadFile, hFile, addr buffer, LINE_SIZE, addr bytesRead, NULL
    ;Actualiza bandera "f_eof".
    cmp bytesRead, 0
    jne no_file_end
    mov f_eof, 1      ;Marca bandera
  no_file_end:
    ;Escribe caracter nulo al final de la cadena leída
    mov edi, offset buffer
    add edi, bytesRead
    mov byte ptr [edi], 0
    ;Busca el fin de la primera línea (pueden haberse leído varias).
    invoke search_EOL
    ret
read_block ENDP
;Versión de "read_block" que lee en la parte superior de "buffer",
;a partir de la posición "bytesRead".
read_block2 PROC
    mov ebx, LINE_SIZE
    sub ebx, bytesRead
    mov edi, offset buffer
    add edi, bytesRead
    ;Salvamos "bytesRead".
    mov eax, bytesRead    
    mov p_eol, eax
    ;Lectura desde disco
    invoke ReadFile, hFile, edi, ebx, addr bytesRead, NULL
    ;Actualiza bandera "f_eof".
    cmp bytesRead, 0
    jne no_file_end
    mov f_eof, 1      ;Marca bandera
  no_file_end:
    ;Corrige "bytesRead"
    mov eax, bytesRead
    add eax, p_eol
    mov bytesRead, eax
    ;Escribe caracter nulo al final de la cadena leída
    mov edi, offset buffer
    add edi, bytesRead
    mov byte ptr [edi], 0
    ;Busca el fin de la primera línea (pueden haberse leído varias).
    invoke search_EOL   ;Actualiza "p_eol"
    ret
read_block2 ENDP
;Proc. que elimina de "buffer", por desplzamiento de bytes, la 
;primera línea que está delimitada por "p_eol".
del_line1 PROC
    ;Se supone que "p_eol" apunta al siguiente primer caracter delimitador 
    ;de fin de línea. Pero el delmitador puede ser de dos bytes.
    ;Primero vemos si el delimitador es CR-LF.
    mov esi, p_eol
    inc esi     ;Para verificar siguiente byte.
    .IF c_eol == 0Dh    ;Se encontró el caracter CR
        .IF byte ptr [esi] == 0Ah   ;Sigue un LF. Es un CR-LF.
            inc esi ;Apuntamos a siguiente byte para pasar por alto el LF.
        .ENDIF
    .ENDIF
    ;Calcula en "eax" el número de bytes a eliminar.
    sub esi, offset buffer
    mov eax, esi ; EAX <- p_eol - offset(buffer)
    ;Calcula número de bytes a desplazar en ECX
    mov ecx, bytesRead
    sub ecx, eax
    mov bytesRead, ecx  ;Aprovechamos para actualizar "bytesRead".
    inc ecx     ;Corregimos para considerar el chr(0) también.
    ;Realiza movimiento de bytes
    mov edi, offset buffer  ;Puntero a destino.
    mov esi, edi
    add esi, eax            ;Puntero a byte origen.
    cld         ;Dirección -> incrementando ESI/EDI
    rep movsb   ;Mueve "ecx" veces.
    ret
del_line1 ENDP
;Procedimiento para leer una línea de texto 
read_line PROC
    cmp f_eof, 1      ;¿Es fin de archivo?
    je exit_read
    ;Valida si se necesita leer de disco
    lea esi, buffer
    add esi, bytesRead  ;Ahora "esi" apunta al siguiente byte, 
                        ;despúes del bloque leído.
    .IF p_eol >= esi ;Terminamos de leer
        ;Puede que se trate de la primera lectura o una posterior.
        invoke read_block   ;Leemos bloque de texto.
        ;Si es que no se encuentra delimitador de línea en el bloque
        ;leído, se dejará "p_eol" apuntando al final del bloque+1, de
        ;modo que se considerará que todo el bloque es una línea y se
        ;dejará para la siguiente lectura leer la parte faltante de 
        ;la línea, si que existe.
    .ELSE       ;Aún hay datos que leer de buffer
        ;Eliminamos la primera línea de "buffer".
        invoke del_line1    ;Elimina bytes.
        ;Actualiza "p_eol" al fin de la siguiente línea.
        invoke search_EOL
        ;Verifica la línea identificada, para ver si está completa.
        lea esi, buffer
        add esi, bytesRead  ;Ahora "esi" apunta al siguiente byte, 
                            ;despúes del bloque leído.
 ;       .IF p_eol+1 == esi ;*** Este caso crítico habría que 
 ;                          ;verificarlo porque podría corresponder
 ;                          ;a un CR-LF que quedó entre dos bloques.
 ;       .ELSE
        .IF p_eol == esi    ;No se encontró delimitador en lo que queda del bloque.
            ;Por si hay más bloques por leer.
            invoke read_block2   ;Leemos bloque de texto.
            ;Aquí ya se actualizó "p_eol" y "bytesRead"
        .ENDIF
;        .ENDIF
    .ENDIF
  exit_read:
    ret
read_line ENDP
    ;------------ Programa principal ---------------
start:
    invoke open_file    ;Abrir el archivo
    ; Leer el archivo línea por línea
  read_loop:
    ;Verifica fin de archivo
    cmp f_eof, 1    ;¿Es fin de archivo?
    je close_file
    ;Lee bloque
    invoke read_line   
    ;Muesta por pantalla
    invoke MessageBox, NULL, offset buffer, NULL, NULL
    jmp read_loop   ;Lee otra vez
  close_file:       ;Cerrar el archivo
    invoke CloseHandle, hFile
    invoke ExitProcess, 0
end start
