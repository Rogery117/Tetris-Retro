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
    c_rotation   dw 0   ; Guarda la rotación actual (0, 1, 2 o 3)
    
    ; Tabla de colores para cada pieza (7 piezas)
    piece_colors db 0Ch, 0Eh, 09h, 0Ah, 05h, 0Dh, 0Fh
    ; Rojo, Amarillo, Azul claro, Verde claro, Morado, Rosa claro, Blanco
    GAME_OVER_MSG db "GAME OVER - Presiona Enter para salir$"

    ; MATRIZ DE PIEZAS (7 piezas * 4 rotaciones * 4 bloques * 2 coordenadas X,Y)
    ; Cada rotación ocupa exactamente 8 bytes. Cada pieza ocupa 32 bytes.
    shapes       label byte
        ; --- 0: PIEZA I (Cian) ---
        db 0,1, 1,1, 2,1, 3,1  ; 0°   (Horizontal)
        db 2,0, 2,1, 2,2, 2,3  ; 90°  (Vertical)
        db 0,2, 1,2, 2,2, 3,2  ; 180° (Horizontal corregida)
        db 1,0, 1,1, 1,2, 1,3  ; 270° (Vertical corregida)

        ; --- 1: PIEZA O (Amarillo) ---
        db 1,1, 2,1, 1,2, 2,2  ; 0°
        db 1,1, 2,1, 1,2, 2,2  ; 90°
        db 1,1, 2,1, 1,2, 2,2  ; 180°
        db 1,1, 2,1, 1,2, 2,2  ; 270°

        ; --- 2: PIEZA L (Azul oscuro) ---
        db 1,0, 1,1, 1,2, 2,2  ; 0°
        db 0,2, 0,1, 1,1, 2,1  ; 90°
        db 0,0, 1,0, 1,1, 1,2  ; 180°
        db 0,1, 1,1, 2,1, 2,0  ; 270°

        ; --- 3: PIEZA J (Naranja) ---
        db 1,0, 1,1, 1,2, 0,2  ; 0°
        db 0,1, 1,1, 2,1, 2,2  ; 90°
        db 2,0, 1,0, 1,1, 1,2  ; 180°
        db 0,0, 0,1, 1,1, 2,1  ; 270°

        ; --- 4: PIEZA S (Verde) ---
        db 1,1, 2,1, 0,2, 1,2  ; 0°
        db 1,0, 1,1, 2,1, 2,2  ; 90°
        db 1,1, 2,1, 0,2, 1,2  ; 180°
        db 1,0, 1,1, 2,1, 2,2  ; 270°

        ; --- 5: PIEZA Z (Rojo) ---
        db 0,1, 1,1, 1,2, 2,2  ; 0°
        db 2,0, 2,1, 1,1, 1,2  ; 90°
        db 0,1, 1,1, 1,2, 2,2  ; 180°
        db 2,0, 2,1, 1,1, 1,2  ; 270°

        ; --- 6: PIEZA T (Morado) ---
        db 1,1, 0,1, 2,1, 1,0  ; 0°
        db 1,1, 1,0, 1,2, 2,1  ; 90°
        db 1,1, 0,1, 2,1, 1,2  ; 180°
        db 1,1, 1,0, 1,2, 0,1  ; 270°

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
    cmp al, 20h ; Tecla Espacio
    je m_rotate
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

g_tick_bridge: 
    jmp gravity_tick

f_drop:
    mov t_count, 20
    jmp gravity_tick

exit_game:
    jmp exit_p

m_rotate:
    mov bx, c_rotation    ; Guardar rotación actual
    inc c_rotation
    cmp c_rotation, 4
    jl test_rotation
    mov c_rotation, 0     ; Ciclar entre 0 y 3
test_rotation:
    call check_col
    or al, al
    jz g_tick_bridge      ; Si no hay colisión, aplicar rotación
    mov c_rotation, bx    ; Si hay colisión, restaurar anterior
    jmp g_tick_bridge

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
    mov c_rotation, 0     ; Nueva pieza empieza en posición base (0°)
    
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
    jnz exit_p  
    
    jmp main_loop 

wait_frame:
    mov cx, 00h
    mov dx, g_speed
    mov ah, 86h
    int 15h
    jmp main_loop

exit_p:
    mov ax, 03h
    int 10h

    mov ah, 02h
    mov bh, 00h
    mov dh, 12   
    mov dl, 1    
    int 10h

    mov dx, offset GAME_OVER_MSG
    mov ah, 09h
    int 21h

LimpiarYEsperar:
    mov ah, 0Ch          
    mov al, 08h          
    int 21h              

    cmp al, 0Dh          
    jne LimpiarYEsperar  

SalirPrograma:
    mov ah, 4Ch          
    int 21h

; --- LÓGICA DE COLISIÓN MODIFICADA ---
check_col proc
    mov cx, 4           
    
    ; Cálculo indexado seguro de la matriz
    push ax
    push dx
    mov ax, c_shape
    mov dx, 32
    mul dx              ; ax = c_shape * 32
    mov si, ax
    mov ax, c_rotation
    mov dx, 8
    mul dx              ; ax = c_rotation * 8
    add si, ax
    pop dx
    pop ax
    
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

; --- FIJAR PIEZA MODIFICADA ---
lock_p proc
    mov cx, 4
    
    push ax
    push dx
    mov ax, c_shape
    mov dx, 32
    mul dx
    mov si, ax
    mov ax, c_rotation
    mov dx, 8
    mul dx
    add si, ax
    pop dx
    pop ax
    
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

; --- GRÁFICOS MODIFICADOS ---
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
    
    push ax
    push dx
    mov ax, c_shape
    mov dx, 32
    mul dx
    mov si, ax
    mov ax, c_rotation
    mov dx, 8
    mul dx
    add si, ax
    pop dx
    pop ax
    
    add si, offset shapes
draw_piece:
    push cx
    xor ax, ax
    mov al, [si+1]      
    add ax, g_y
    xor bx, bx
    mov bl, [si]        
    add bx, g_x
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