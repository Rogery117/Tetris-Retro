MODEL small
STACK 100h

DATASEG
    ; Variables de configuración
    OFF_X         dw 120
    OFF_Y         dw 10
    board        db 200 dup(0)
    g_x          dw 4
    g_y          dw 0
    t_count      dw 0
    t_limit      dw 20     
    g_speed      dw 8000h 
    c_shape      dw 0
    ; Tabla de colores para cada pieza (7 piezas)
    piece_colors db 0Ch, 0Eh, 09h, 0Ah, 05h, 0Dh, 0Fh
    ; Rojo, Amarillo, Azul claro, Verde claro, Morado, Rosa claro, Blanco
    GAME_OVER_MSG db "GAME OVER - Presiona Enter para salir$"

    ; Matriz de piezas (7 piezas * 4 bloques * 2 coordenadas)
    shapes       db 0,1, 1,1, 2,1, 3,1  ; I
                 db 1,1, 2,1, 1,2, 2,2  ; O
                 db 1,0, 1,1, 1,2, 2,2  ; L
                 db 1,0, 1,1, 1,2, 0,2  ; J
                 db 1,1, 0,1, 1,0, 2,0  ; S
                 db 1,1, 2,1, 1,0, 0,0  ; Z
                 db 1,1, 0,1, 2,1, 1,0  ; T

CODESEG
inicio:
    mov ax, @data
    mov ds, ax
    mov es, ax

    ; Modo Gráfico 13h
    mov ax, 13h
    int 10h

main_loop:
    call draw_everything
    
    ; Leer teclado
    mov ah, 01h
    int 16h
    jz g_tick_bridge ; Si no hay tecla, saltar a gravedad
    
    mov ah, 00h
    int 16h
    cmp ah, 4Bh ; Izquierda
    je m_left
    cmp ah, 4Dh ; Derecha
    je m_right
    cmp ah, 50h ; Abajo
    je f_drop
    cmp al, 1Bh ; ESC
    je exit_game
    jmp g_tick_bridge

m_left:
    dec g_x
    call check_col
    or al, al
    jz g_tick_bridge
    inc g_x 
    jmp g_tick_bridge

m_right:
    inc g_x
    call check_col
    or al, al
    jz g_tick_bridge
    dec g_x 

g_tick_bridge: ; Puente para evitar el error "Jump out of range"
    jmp gravity_tick

f_drop:
    mov t_count, 20
    jmp gravity_tick

exit_game:
    jmp exit_p

gravity_tick:
    inc t_count
    mov ax, t_count
    cmp ax, t_limit
    jl wait_frame
    
    mov t_count, 0
    inc g_y
    call check_col
    or al, al
    jz wait_frame 
    
    dec g_y
    call lock_p
    call check_lines 
    
    ; Reset pieza
    mov g_x, 4
    mov g_y, 0
    
    ; Nueva pieza aleatoria
    mov ah, 00h
    int 1Ah
    mov ax, dx
    xor dx, dx
    mov bx, 7
    div bx
    mov c_shape, dx
    
    call check_col
    or al, al
    jnz exit_p  ;Si hay colisión, salta a 'exit_p'
    
    jmp main_loop ; Si NO hay colisión, sigue jugando

wait_frame:
    mov cx, 00h
    mov dx, g_speed
    mov ah, 86h
    int 15h
    jmp main_loop

exit_p:
    ; 1. Regresar a modo texto INMEDIATAMENTE
    ; Esto limpia la pantalla gráfica y nos da un fondo negro limpio
    mov ax, 03h
    int 10h

    ; 2. Configurar posición del cursor en el centro
    mov ah, 02h
    mov bh, 00h
    mov dh, 12   ; Fila central
    mov dl, 1    ; Reduje el margen para que el mensaje quepa mejor centrado
    int 10h

    ; 3. Imprimir el mensaje de Game Over
    mov dx, offset GAME_OVER_MSG
    mov ah, 09h
    int 21h

    ; 4. Esperar tecla ENTER para salir (Bucle corregido)
LimpiarYEsperar:
    mov ah, 0Ch          ; Función DOS: Limpiar búfer y ejecutar entrada
    mov al, 08h          ; Sub-función: Leer consola sin eco (espera tecla)
    int 21h              ; Llama a DOS. El ASCII de la tecla queda en AL

    cmp al, 0Dh          ; ¿Es el código ASCII de Enter (13 decimal / 0Dh)?
    jne LimpiarYEsperar  ; Si NO es Enter, vuelve a limpiar y esperar

SalirPrograma:
    mov ah, 4Ch          ; Terminar proceso y regresar al sistema
    int 21h

; --- LÓGICA DE COLISIÓN ---
check_col proc
    mov cx, 4           
    mov si, c_shape
    shl si, 3           
    add si, offset shapes
col_loop:
    push cx
    xor ax, ax
    mov al, [si]        
    add ax, g_x      
    xor bx, bx
    mov bl, [si+1]      
    add bx, g_y      
    
    cmp ax, 0
    jl is_col
    cmp ax, 9
    jg is_col
    cmp bx, 19
    jg is_col
    cmp bx, 0
    jl next_bl
    
    push ax
    mov ax, bx
    mov dl, 10
    mul dl
    pop dx
    add ax, dx          
    mov di, ax
    cmp board[di], 1
    je is_col
next_bl:
    add si, 2           
    pop cx
    loop col_loop
    mov al, 0
    ret
is_col:
    pop cx
    mov al, 1
    ret
check_col endp

; --- FIJAR PIEZA ---
lock_p proc
    mov cx, 4
    mov si, c_shape
    shl si, 3
    add si, offset shapes
lock_loop:
    xor ax, ax
    mov al, [si]
    add ax, g_x      
    xor bx, bx
    mov bl, [si+1]
    add bx, g_y      
    cmp bx, 0
    jl skip_lock
    push ax
    mov ax, bx
    mov dl, 10
    mul dl
    pop dx
    add ax, dx
    mov di, ax
    mov board[di], 1
skip_lock:
    add si, 2
    loop lock_loop
    ret
lock_p endp

; --- BORRAR LÍNEAS ---
check_lines proc
    mov si, 190 
    mov dx, 20  
row_scan:
    push si
    mov cx, 10
    xor al, al
cell_scan:
    cmp board[si], 1
    jne line_not_full
    inc al
    inc si
    loop cell_scan
    cmp al, 10
    je delete_line
line_not_full:
    pop si
    sub si, 10
    dec dx
    jnz row_scan
    ret
delete_line:
    pop di      
    mov si, di
    sub si, 10  
move_rows_down:
    cmp si, 0
    jl clear_top_row
    mov cx, 10
copy_line_loop:
    mov al, board[si]
    mov board[di], al
    inc si
    inc di
    loop copy_line_loop
    sub si, 20
    sub di, 20
    jmp move_rows_down
clear_top_row:
    mov cx, 10
    mov si, 0
clear_top_loop:
    mov board[si], 0
    inc si
    loop clear_top_loop
    ret
check_lines endp

; --- GRÁFICOS ---
draw_everything proc
    mov ax, 0A000h
    mov es, ax
    xor di, di
    mov cx, 32000
    xor ax, ax
    rep stosw
    
    xor si, si
    mov dx, 0
y_loop: 
    mov bx, 0
x_loop: 
    cmp board[si], 1
    jne next_block
    push dx
    push bx
    mov ax, dx
    mov cl, 07h 
    call draw_sq
    pop bx
    pop dx
next_block: 
    inc si
    inc bx
    cmp bx, 10
    jl x_loop
    inc dx
    cmp dx, 20
    jl y_loop
    
    mov cx, 4
    mov si, c_shape
    shl si, 3
    add si, offset shapes
draw_piece:
    push cx
    xor ax, ax
    mov al, [si+1]      
    add ax, g_y
    xor bx, bx
    mov bl, [si]        
    add bx, g_x
       ; Obtener color según c_shape
    push bx
    mov bx, c_shape
    mov cl, piece_colors[bx]
    pop bx
    call draw_sq
    add si, 2
    pop cx
    loop draw_piece
    ret
draw_everything endp

draw_sq proc
    push ax
    push bx
    shl ax, 3 
    add ax, OFF_Y
    shl bx, 3 
    add bx, OFF_X
    mov dx, 320
    mul dx
    add ax, bx
    mov di, ax
    mov al, cl
    mov cx, 8
row_draw: 
    push cx
    mov cx, 8
    rep stosb
    add di, 320-8
    pop cx
    loop row_draw
    pop bx
    pop ax
    ret
draw_sq endp

end inicio