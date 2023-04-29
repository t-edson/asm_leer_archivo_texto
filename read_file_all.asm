;Lectura de archivo de texto, línea por línea en ensamblador (MASM32), 
;volcando primero todo el archivo a memoria dinámica.
;Trabaja sobre Windows y reconoce diversos delimitadores de línea.
;                                       Por Tito Hinostroza 28/04/2023

include \masm32\include\masm32rt.inc

.data
    filePath    db "input.tit",0
    hFile       dd ?    ;Manejador de archivo.
    bytesRead   dd ?    ;Tamaño del archivo leído.
    buffer      dd ?    ;Puntero a la memoria dinámica
    p_line      dd ?    ;Puntero a inicio de línea en "buffer".
    p_eol       dword ? ;Puntero a fin de línea en "buffer".
    c_eol       db ?    ;Caracter EOL encontrado. 
.code
;Proc. para abrir un archivo. Actualiza "hFile" y "f_eof".
open_file PROC  
    ; Abrir el archivo para lectura
    invoke CreateFile, addr filePath, GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL
    mov hFile, eax ; Guardar el handle del archivo en la variable "hFile".
    ; Obtener el tamaño del archivo
    invoke GetFileSize, hFile, NULL
    inc eax         ; Pedimos un byte más para el delimitador.
    mov bytesRead, eax ; Guardar el tamaño del archivo en la variable bytesRead
    ; Reservar memoria para el buffer que contendrá el contenido del archivo
    invoke GlobalAlloc, GMEM_FIXED, bytesRead
    mov buffer, eax ; Guardar el puntero al buffer en la variable "buffer".
    ; Leer el contenido del archivo en "buffer".
    invoke ReadFile, hFile, buffer, bytesRead, addr bytesRead, NULL
    ;Escribe caracter nulo al final de la cadena leída
    mov edi, buffer
    add edi, bytesRead
    mov byte ptr [edi], 0
    ;Inicializamos puntero "p_line"
    mov edi, buffer
    mov p_line, edi ;Para que funcione bien read_eof().
    ;Preparamos para la primera lectura con search_EOL().
    dec edi             
    mov p_eol, edi  ;Deja apuntando al byte anterior.
    mov al, 0Ah    ;LF
    mov c_eol, al  ;Para que search_EOL() no intente buscar LF.
    ret
open_file ENDP
;Proc. para cerrar el archivo y liberar el espacio de memoria ocupado.
close_file PROC
    ; Cerrar el archivo
    invoke CloseHandle, hFile
    ; Liberar la memoria del buffer
    invoke GlobalFree, buffer
    ret
close_file ENDP
;Devuelve EAX=1 si se ha llegado al fin del archivo, de lo contrario 
;devuelve EAX=0.
read_eof PROC
    mov edi, buffer
    add edi, bytesRead
    .IF p_eol >= edi
        mov eax, 1
    .ELSE
        mov eax, 0
    .ENDIF
    ret
read_eof ENDP
;Pone delimitador \0 a línea apuntada por "p_line".
search_EOL PROC
    ;Validación.
    invoke read_eof
    .IF eax==1
        ret
    .ENDIF
    ;Prepara la lectura de la siguiente línea, a partir de "p_eol"
    mov esi, p_eol
    inc esi
    .IF c_eol == 0Dh    ;Se encontró el caracter CR
        .IF byte ptr [esi] == 0Ah   ;Sigue un LF. Es un CR-LF.
            inc esi ;Apuntamos a siguiente byte para pasar por alto el LF.
        .ENDIF
    .ENDIF
    mov p_line, esi     ;Aquí debería empezar la siguiente línea
    ;Posiciona "p_eol" al final de la línea.
    mov edi, buffer
    add edi, bytesRead  ; EDI <-buffer + bytesRead
    mov eax, p_line     
    mov p_eol, eax      ; p_eol <- p_line
    ;Validación.
    invoke read_eof
    .IF eax==1
        ret
    .ENDIF
    ;Busca delimitador
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

    ;------------ Programa principal ---------------
start:
    invoke open_file
    invoke read_eof
    .WHILE eax==0 
        invoke search_EOL
        ; Mostramos el contenido completo del archivo
        invoke MessageBox, NULL, p_line, NULL, NULL

        invoke read_eof
    .ENDW

    invoke close_file
    invoke ExitProcess, 0
end start
