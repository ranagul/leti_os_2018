ASSUME CS:CODE, DS:DATA, SS:ASTACK

ASTACK SEGMENT STACK 
	DW 64 DUP(?)
ASTACK ENDS

CODE SEGMENT
;----------------------------
OUTPUT_PROC PROC NEAR ;Вывод на экран сообщения
		push ax
		mov  ah, 09h
	    int  21h
	    pop	 ax
	    ret
OUTPUT_PROC ENDP
;----------------------------
INTERRUPTION PROC FAR
	jmp begin
	ADDR_PSP1   dw ? ;offset 3
	ADDR_PSP2   dw ? ;offset 5
	KEEP_IP 	dw ? ;offset 7
	KEEP_CS 	dw ? ;offset 9
	INTER_SET 	dw 0ABCDh ;offset 11
	REQ_KEY_6	db 07h
	REQ_KEY_7	db 08h
	REQ_KEY_8	db 09h
	REQ_KEY_9	db 0Ah
	REQ_KEY_0	db 0Bh

begin:
	in al,60h ;Cчитать ключ
	
	cmp al, REQ_KEY_6
	je 	key6 
		
	cmp al, REQ_KEY_7 
	je 	key7

	cmp al, REQ_KEY_8
	je 	key8
	
	cmp al, REQ_KEY_9
	je 	key9
	
	cmp al, REQ_KEY_0
	je 	key0
	
	jmp dword ptr cs:[KEEP_IP] ;переходим на стандартный обработчик

	key6:
		mov cl, 'A'
		jmp do_req
	key7:
		mov cl, 'B'
		jmp do_req
	key8:
		mov cl, 'C'
		jmp do_req
	key9:
		mov cl, 'D'
		jmp do_req
	key0:
		mov cl, 'E'

	do_req:
		in al,61h	;Взять значение порта управления клавиатурой
		mov ah,al	;Сохранить его
		or al,80h	;Установить бит разрешения для клавиатуры
		out 61h,al	;И вывести его в управляющий порт
		xchg ah, al	;Извлечь исходное значение порта
		out 61h,al	;И записать его обратно
		mov al,20h	;Послать сигнал конца прерывания контроллеру прерываний 8259 
		out 20h,al	
		
		push bx
		push cx
		push dx	
	
		mov ah, 05h ;функция, позволяющая записать символ в буфер клавиатуры
		mov cl,al
		mov ch, 00h ;символ в CL уже занесён ранее, осталось обнулить CH	
		int 16h
		or 	al, al	;проверка переполнения буфера
		jnz skip 	;если переполнен - идём в skip
		jmp return	;иначе выходим
	
	skip: 			;очищаем буфер
		push es
		push si
		mov ax, 0040h
		mov es, ax
		mov si, 001ah
		mov ax, es:[si] 
		mov si, 001ch
		mov es:[si], ax	
		pop si
		pop es
		
	return:
		pop dx    
		pop cx
		pop bx		
		iret
INTERRUPTION ENDP
;----------------------------
inter_end:
INSTALL_CHECK PROC NEAR	;Проверка установки прерывания
	push bx
	push dx
	push es

	mov ah, 35h	;Получение вектора прерываний
	mov al, 09h	;Функция выдает значение сегмента в ES, смещение в BX
	int 21h

	mov dx, es:[bx + 11]
	cmp dx, 0ABCDh ;Проверка на совпадение кода прерывания 
	je install_
	mov al, 00h
	jmp end_install

install_:
	mov al, 01h
	jmp end_install

end_install:
	pop es
	pop dx
	pop bx
	ret
INSTALL_CHECK ENDP
;----------------------------
UN_CHECK PROC NEAR ;Проверка на то, не ввёл ли пользователь /un
	push es
	mov ax, ADDR_PSP1
	mov es, ax

	cmp byte ptr es:[82h], '/'		
	jne not_enter
	cmp byte ptr es:[83h], 'u'		
	jne not_enter
	cmp byte ptr es:[84h], 'n'
	jne not_enter
	mov al, 1h

not_enter:
	pop es
	ret
UN_CHECK ENDP
;----------------------------
INSTALL_INTER PROC NEAR ;Cохранение стандартного обработчика прерываний и загрузка собственного
	push ax
	push bx
	push dx
	push es

	mov ah, 35h
	mov al, 09h
	int 21h

	mov KEEP_IP, bx	;Запоминаем смещение и сегмент
	mov KEEP_CS, es

	push ds
	lea dx, INTERRUPTION
	mov ax, seg INTERRUPTION
	mov ds, ax

	mov ah, 25h
	mov al, 09h
	int 21h 
	pop ds

	lea dx, INSTALL 
	call OUTPUT_PROC 

	pop es
	pop dx
	pop bx
	pop ax
	
	ret
INSTALL_INTER ENDP
;----------------------------
UNLOAD_INTER PROC NEAR	;Выгрузка обработчика прерывания
	push ax
	push bx
	push dx
	push es
	
	mov ah, 35h
	mov al, 09h
	int 21h

	cli
	push ds            
	mov dx, es:[bx + 7]   
	mov ax, es:[bx + 9]   
		
	mov ds, ax
	mov ah, 25h
	mov al, 09h
	int 21h
	pop ds
	sti
	
	lea dx, UNLOAD
	call OUTPUT_PROC 

	push es ;Удаление MCB
	mov cx,es:[bx+3]
	mov es,cx
	mov ah,49h
	int 21h
	
	pop es
	mov cx,es:[bx+5]
	mov es,cx
	int 21h

	pop es
	pop dx
	pop bx
	pop ax
	
	mov ah, 4Ch	;Выход из программы через функцию 4C
	int 21h
	ret
UNLOAD_INTER ENDP
;----------------------------
MAIN  PROC FAR
    mov bx,2Ch
	mov ax,[bx]
	mov ADDR_PSP2,ax
	mov ADDR_PSP1,ds  ;сохраняем PSP
	mov dx, ds 
	sub ax,ax    
	xor bx,bx
	mov ax,data  
	mov ds,ax 
	xor dx, dx

	call UN_CHECK ;Проверка на введение /un 
	cmp al, 01h
	je unload_		

	call INSTALL_CHECK  ;Проверка не является ли программа резидентной
	cmp al, 01h
	jne not_resident
	
	lea dx, ALR_INSTALL ;Программа уже загружена
	call OUTPUT_PROC
	jmp quit

;Загрузка резидента
not_resident: 
	call INSTALL_INTER 
	lea dx, inter_end
	mov cl, 04h
	shr dx, cl
	add dx, 1Bh
	mov ax, 3100h
	int 21h
	
;Выгрузка резидента      
unload_:
	call INSTALL_CHECK
	cmp al, 0h
	je not_install_
	call UNLOAD_INTER
	jmp quit

;Прерывание выгружено
not_install_: 
	lea dx, UNLOAD
	call OUTPUT_PROC
	
quit:
	mov ah, 4Ch
	int 21h
MAIN  	ENDP
CODE 	ENDS

DATA SEGMENT
	INSTALL    	db 'Interrupt handler is installed', 0dh, 0ah, '$'
    NOT_INSTALL db 'Interrupt handler is not installed', 0dh, 0ah, '$'
   	ALR_INSTALL db 'Interrupt handler is already installed', 0dh, 0ah, '$'
	UNLOAD		db 'Interrupt handler was unloaded', 0dh, 0ah, '$'
DATA ENDS

END Main 