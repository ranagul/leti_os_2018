AStack		SEGMENT  STACK
        DW 256 DUP(?)			
AStack  	ENDS

DATA		SEGMENT
	error_4Ah	db 'Memory can not be freed! (func 4Ah error)', 0dh, 0ah, '$'		    ;причина неудачного выполнения функции 4Ah
    error4Ah_7  db 'Control unit memory destroyed (code 7)', 0dh, 0ah, '$'	    		;разрушен управляющий блок памяти (код 7)
    error4Ah_8	db 'Not enought memory to perform the function (code 8)', 0dh, 0ah, '$'	;недостаточно памяти для выполнения функции (код 8)
    error4Ah_9	db 'Invalid adress of the memory block (code 9)', 0dh, 0ah, '$'			;неверный адрес блока памяти (код 9)
	
	error_4B03h	    db 'Overlay program was not loaded! (func 4B03h error)', 0dh, 0ah, '$'	;причина неудачного завершения функции 4B03h					
	error_4B03h_1	db 'Incorrect number of the function (code 1)', 0dh, 0ah, '$'   		;неверный номер функции (код 1)
	error_4B03h_2   db 'File not found (code 2)', 0dh, 0ah, '$'								;файл не найден (код 2)
	error_4B03h_3   db 'Way not found (code 3)', 0dh, 0ah, '$'								;маршрут не найден (код 3)
	error_4B03h_4   db 'Too many opened files (code 4)', 0dh, 0ah, '$'						;слишком много открытых файлов (код 4)
	error_4B03h_5   db 'No acsess (code 5)', 0dh, 0ah, '$'									;нет доступа (код 5)
	error_4B03h_8   db 'Not enought memory(code 8)', 0dh, 0ah, '$'							;мало памяти (код 8)
	error_4B03h_10  db 'Incorrect environment (code 10)', 0dh, 0ah, '$'						;неправильная среда(код 10)
	
	error_4Eh	    db 'Overlay size cant be calculate! (func 4Eh error)', 0dh, 0ah, '$'	;причина неудачного завершения функции 4Eh					
	error_4Eh_2	    db 'File not found (code 2)', 0dh, 0ah, '$'   							;файл не найден (код 2)
	error_4Eh_3     db 'Way not found (code 3)', 0dh, 0ah, '$'								;путь не найден (код 3)
	
	memory_error_message  db 'Error: too many big file', 0dh, 0ah, '$'						;ошибка возникает, когда файл слишком велик для загрузки
	
	adr 		dd 	0
	DTA 		db 	43 dup (0), '$'
	Keep_PSP 	dw 	0
	OVL_address dw 	0
	DTA_paraghr db	256	dup (0), '$'
	; Имена вызываемых файлов
	name1		db	'ovl_1.ovl',0
	name2		db	'ovl_2.ovl',0	
DATA 		ENDS

CODE	SEGMENT
	.386
    ASSUME CS:CODE, DS:DATA, SS:AStack

; функция вывода сообщения на экран
Write_message	PROC
	push AX
	mov AH, 09h
	int 21h
	pop AX
	ret
Write_message	ENDP

; Функция, определяющая размер оверлея при помощи функции 4Eh прерывания 21h
MemorySize	 PROC
	push ES
	push BX
	push SI
	
	push DS
	push DX
	mov DX, seg DTA
	mov DS, DX
	mov DX, offset DTA	;в DS:DX - адрес для DTA
	mov AX, 1A00h		;функция установки адреса для DTA
	int 21h
	pop DX
	pop DS
		
	push DS
	push DX
	mov CX, 0			;значение байта атрибутов для файла - 0
	mov DX, seg DTA_paraghr	
	mov DS, DX
	mov DX, offset DTA_paraghr	;в DS:DX указатель на путь к файлу
	mov AX, 4E00h
	int 21h
	pop DX
	pop DS
		
	jnc read_size
	
	lea DX, error_4Eh
	call Write_message
		
	cmp AX, 2
	je error4Eh_2_label
		
	cmp AX, 3
	je error4Eh_3_label
		
error4Eh_2_label:
	lea DX, error_4Eh_2
	call Write_message
	jmp end_function
	
error4Eh_3_label:
	lea DX, error_4Eh_3
	call Write_message
	jmp end_function
	
read_size:
	push ES
	push BX
	push SI
	mov SI, offset DTA
	add SI, 1Ch		;в буфере со смещением 1Ch - старшее слово размера файла
	mov bx, [si]	;читаем старшее слово размера файла
	cmp bx, 000Fh
	jle no_memory_error
	jmp memory_error
	
no_memory_error:
	sub SI, 2	;выбираем смещение на 1Ah
	mov BX, [si]	;читаем оттуда младшее слово размера файла
	push CX
	mov cl, 4
	shr BX, CL ;перевод в параграфы (в BX - младшее слово)
	pop CX
	mov AX, [si+2] ;снова читаем старшее слово
	push CX
	mov CL, 12
	sal AX, CL	;переводим в байты, а затем в параграфы
	pop CX
	add BX, AX	;добавляем к BX
	inc BX
	inc BX
		
	mov AX, 4800h	;вызываем функцию выделения памяти
	int 21h			;с аргументом - количеством параграфов - в BX
	mov OVL_address, AX	;сохраняем полученное значение
	pop SI
	pop BX
	pop ES
	jmp end_function
	
memory_error:
	lea dx, memory_error_message
	call Write_message
	pop SI
	pop BX
	pop ES

end_function:
	pop SI
	pop BX
	pop ES
	ret
MemorySize  ENDP


; Функция нахождения пути до вызываемого файла (в bp - имя файла)
Get_Path	PROC
	push AX
	push BX
	push CX
	push DX
	push SI
	push DI
	push ES
	
	mov ES, Keep_PSP
	mov AX, ES:[2Ch]
	mov ES, AX
	mov BX, 0
	mov CX, 2
		
env_loop_path_locate:
	inc CX
	mov AL, ES:[BX]
	inc BX
	cmp AL, 0
	jz 	pre_end_env_path_locate
	loop env_loop_path_locate
		
pre_end_env_path_locate:
	cmp byte ptr ES:[BX], 0
	jnz env_loop_path_locate
	add BX, 3
	lea SI, DTA_paraghr
		
path_loop_path_locate:
	mov AL, ES:[BX]
	mov [SI], AL
	inc SI
	inc BX
	cmp AL, 0
	jz 	end_path_loop_path_locate_m
	jmp path_loop_path_locate
	
end_path_loop_path_locate_m:	
	sub SI, 9
	mov DI, BP
		
replace_loop_path_locate:
	mov AH, [DI]
	mov [SI], AH
	cmp AH, 0
	jz 	end_replace_loop_path_locate
	inc DI
	inc SI
	jmp replace_loop_path_locate
	
end_replace_loop_path_locate:
	pop ES
	pop DI
	pop SI
	pop DX
	pop CX
	pop BX
	pop AX
	ret
Get_Path	ENDP	

; Функция вызова оверлейной программы при помощи 4B03h прерывания 21h
Call_OVL  	PROC
	push AX
	push BX
	push CX
	push DX
	push BP
		
	mov BX, seg OVL_address
	mov ES, BX
	mov BX, offset OVL_address	;в ES:BX - указатель на блок параметров
		
	mov DX, seg DTA_paraghr
	mov DS, DX	
	mov DX, offset DTA_paraghr	;в DS:DX - указатель на путь к оверлею
		
	push SS
	push SP
		
	mov AX, 4B03h	;вызываем функцию
	int 21h
	jnc no_error1
	
	lea DX, error_4B03h
	call Write_message
	
	cmp AX, 1
	je error_4B03h_1_label
	
	cmp AX, 2
	je error_4B03h_2_label
	
	cmp AX, 3
	je error_4B03h_3_label
	
	cmp AX, 4
	je error_4B03h_4_label
	
	cmp AX, 5
	je error_4B03h_5_label
	
	cmp AX, 8
	je error_4B03h_8_label
	
	cmp AX, 10
	je error_4B03h_10_label
	
	jmp error1
	
error_4B03h_1_label:
	lea DX, error_4B03h_1
	call Write_message
	jmp error1
	
error_4B03h_2_label:
	lea DX, error_4B03h_2
	call Write_message
	jmp error1
	
error_4B03h_3_label:
	lea DX, error_4B03h_3
	call Write_message
	jmp error1

error_4B03h_4_label:
	lea DX, error_4B03h_4
	call Write_message
	jmp error1

error_4B03h_5_label:
	lea DX, error_4B03h_5
	call Write_message
	jmp error1

error_4B03h_8_label:
	lea DX, error_4B03h_8
	call Write_message
	jmp error1

error_4B03h_10_label:
	lea DX, error_4B03h_10
	call Write_message
	jmp error1

no_error1:
	mov AX, seg DATA
	mov DS, AX	;восстанавливаем DS
	mov AX, OVL_address
	mov word ptr adr+2, AX
	call adr
	mov AX, OVL_address
	mov ES, AX
	mov AX, 4900h
	int 21h
	mov AX, seg DATA
	mov DS, AX
	
error1:
	pop SP
	pop SS
	mov ES, Keep_PSP
	pop BP
	pop DX
	pop CX
	pop BX
	pop AX	
	ret
Call_OVL  	ENDP

; Главная функция
Main 	PROC  
	mov AX, seg DATA
	mov DS, AX
	mov Keep_PSP, ES

;подготовка места в памяти	
	mov AX, ALL_MEMORY	;вся память, выделенная программе
	mov BX, ES			;используемая память
	sub AX, BX			;вычисляем остаток
	mov CX, 0004h		
	shr AX, CL			;переводим в параграфы
	mov BX, AX			;указываем входной параметр для функции 4Ah
	
	mov AX, 4A00h		
	int 21h				;выполняем функцию (в AX занесётся код ошибки если она будет)
	
;обработка ошибок функции 4Ah
	jnc NO_ERROR_4Ah	;если флаг CF=0 - ошибок не было, движемся далее
	
	lea DX, error_4Ah	;выводим сообщение о том, что произошла ошибка в функции 4Ah
	call Write_message
	
	cmp AX, 7			;ошибка с кодом 7
	je error4Ah_7_label ;соответствующая обработка
	
	cmp AX, 8			;ошибка с кодом 8
	je error4Ah_8_label ;соответствующая обработка
	
	cmp AX, 9			;ошибка с кодом 9
	je error4Ah_8_label ;соответствующая обработка

error4Ah_7_label:
	lea dx, error4Ah_7
	call Write_message
	jmp Error_finish
	
error4Ah_8_label:
	lea dx, error4Ah_8
	call Write_message
	jmp Error_finish

error4Ah_9_label:
	lea dx, error4Ah_9
	call Write_message
	jmp Error_finish
	
NO_ERROR_4Ah:
;освобождение места, нахождение пути и запуск 1 оверлея
	lea bp, name1
	call Get_Path
	call MemorySize
	call Call_OVL
	
;освобождение места, нахождение пути и запуск 2 оверлея
	lea bp, name2
	call Get_Path
	call MemorySize
	call Call_OVL
	
Error_finish:
	mov AH, 4Ch		;завершение по функции 4C
	int 21h
Main 	ENDP
CODE    		ENDS

ALL_MEMORY	SEGMENT	;пустой сегмент в конце
ALL_MEMORY  ENDS	;для определения памяти, которая не используемся в CS

		END Main