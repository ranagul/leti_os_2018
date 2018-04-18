AStack		SEGMENT  STACK
        DW 256 DUP(?)			
AStack  	ENDS

DATA		SEGMENT
    error_4Ah	db 'Memory can not be freed! (func 4Ah error)', 0dh, 0ah, '$'		     ;причина неудачного выполнения функции 4Ah
    error4Ah_7  db 'Control unit memory destroyed (code 7)', 0dh, 0ah, '$'	    	     ;разрушен управляющий блок памяти (код 7)
    error4Ah_8	db 'Not enought memory to perform the function (code 8)', 0dh, 0ah, '$'	     ;недостаточно памяти для выполнения функции (код 8)
    error4Ah_9	db 'Invalid adress of the memory block (code 9)', 0dh, 0ah, '$'		     ;неверный адрес блока памяти (код 9)
	
	error_4Bh	db 'Program was not loaded! (func 4Bh error)', 0dh, 0ah, '$'	     ;причина неудачного завершения функции 4Bh					
	error4Bh_1	db 'Incorrect number of the function (code 1)', 0dh, 0ah, '$'        ;неверный номер функции (код 1)
	error4Bh_2  db 'File not found (code 2)', 0dh, 0ah, '$'						;файл не найден (код 2)
	error4Bh_5  db 'Hard drive error (code 5)', 0dh, 0ah, '$'					;ошибка диска (код 5)
	error4Bh_8  db 'Not enought memory (code 8)', 0dh, 0ah, '$'					;недостаточно памяти (код 8)
	error4Bh_10 db 'Invalid string (code 10)', 0dh, 0ah, '$'					;неправильная строка среды (код 10)
	error4Bh_11 db 'Incorrect format (code 11)', 0dh, 0ah, '$'					;неверный формат (код 11)
	
	finish_message db 0dh, 0ah, 'Program finished with code #  ', 0dh, 0ah, '$'			;сообщение о завершении программы
	finish_code_0 db   'Normal completion', 0dh, 0ah, '$'						;нормальное завершение (код 0)
	finish_code_1 db   'Completion by Ctrl-Break', 0dh, 0ah, '$'				        ;завершение по Ctrl+Break
	finish_code_2 db   'Completion by device error', 0dh, 0ah, '$'				        ;завершение по ошибке устройства
	finish_code_3 db   'Completion by 31h function', 0dh, 0ah, '$'	                                ;завершение по функции 31h, оставляющей программу резидентной в памяти
	  
DATA 		ENDS

CODE	SEGMENT
	param_block db 14 dup(0)  	   ;место под блок параметров	
	file_path   db 70 dup(0)           ;место под путь до файла (оставляем место с запасом)
	Keep_SS 	dw ?		   ;место под хранение содержимого регистра SS
	Keep_SP 	dw ? 		   ;место под хранение содержимого регистра SP
	position	dw 0 			
    ASSUME CS:CODE, DS:DATA, SS:AStack

; функция вывода сообщения на экран
Write_message	PROC
	push AX
	mov AH, 09h
	int 21h
	pop AX
	ret
Write_message	ENDP
	

; Главная функция
Main 	PROC  
	mov AX, DATA
	mov DS, AX
	
;1)  подготовка места в памяти
	mov AX, ALL_MEMORY	;вся память, выделенная программе
	mov BX, ES			;используемая память
	sub AX, BX			;вычисляем остаток
	mov CX, 0004h		
	shl AX, CL			;переводим в параграфы
	mov BX, AX			;указываем входной параметр для функции 4Ah
	
	mov AX, 4A00h		
	int 21h				;выполняем функцию (в AX занесётся код ошибки если она будет)
	
;1.1) обработка ошибок функции 4Ah
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
	
;2)  Создание блока параметров
NO_ERROR_4Ah:				
	mov byte ptr [param_block], 0	;если сегментный адрес среды 0 - вызываемая программая наследует среду вызывающей

;3)  Подготовка строки, содержащей путь и имя вызываемой программы
	mov ES, ES:[2Ch]
	mov SI, 0
find_zero:
	mov AX, ES:[SI]
	inc SI
	cmp AX, 0000h
	jne find_zero
	
	add SI, 3
	mov DI, 0
	
write:
		mov CL, ES:[SI]
		cmp CL, 0
		je 	cont	
		cmp CL, '\'
		jne not_pos
		mov position, DI
not_pos:
		mov byte ptr [file_path+DI], CL
		inc SI
		inc DI
		jmp write
	
cont:
		mov BX, position
		inc BX
		mov byte ptr [file_path+BX], 'l'
		inc BX
		mov byte ptr [file_path+BX], 'r'
		inc BX	
		mov byte ptr [file_path+BX], '_'
		inc BX	
		mov byte ptr [file_path+BX], '2'
		inc BX	
		mov byte ptr [file_path+BX], '.'
		inc BX
		mov byte ptr [file_path+BX], 'c'
		inc BX
		mov byte ptr [file_path+BX], 'o'
		inc BX
		mov byte ptr [file_path+BX], 'm'
		inc BX
		mov byte ptr [file_path+BX], '$'

;4)  Сохранение регистров SS и SP
	push DS				;запоминаем в стек DS 
	push ES				;и ES
	mov Keep_SP, SP		;сохраняем SP
	mov Keep_SS, SS		;и SS
	
;5)  Подготовка и выполнение функции 4Bh
	mov SP, 0FEh
	mov AX, CODE
	mov DS, AX
	mov ES, AX
	
	lea BX, param_block	;в BX - блок параметров
	lea DX, file_path	;в DX - путь к файлу
	mov AX, 4B00h		;вызываем функцию 4B
	int 21h
	
	mov SS, CS:Keep_SS	;восстанавливаем SS
	mov SP, CS:Keep_SP	;и SP
	
	pop ES				;восстанавливаем из обновлённых 
	pop DS				;SS и SP ES и DS
	
	jnc NO_ERROR_4Bh	;если флаг CF=0 - ошибок нет, идём далее
	
;5.1)  Обработка ошибок от функции 4Bh

	lea DX, error_4Bh	;выводим сообщение о том,
	call Write_message	;что произошла ошибка в 4Bh

	cmp AX, 1
	je error4Bh_1_label
	
	cmp AX, 2
	je error4Bh_2_label
	
	cmp AX, 5
	je error4Bh_5_label
	
	cmp AX, 8
	je error4Bh_8_label
	
	cmp AX, 10
	je error4Bh_10_label
	
	cmp AX, 11
	je error4Bh_11_label
	
error4Bh_1_label:
	lea DX, error4Bh_1
	call Write_message
	jmp Error_finish
	
error4Bh_2_label:
	lea DX, error4Bh_2
	call Write_message
	jmp Error_finish
	
error4Bh_5_label:
	lea DX, error4Bh_5
	call Write_message
	jmp Error_finish
	
error4Bh_8_label:
	lea DX, error4Bh_8
	call Write_message
	jmp Error_finish
	
error4Bh_10_label:
	lea DX, error4Bh_10
	call Write_message
	jmp Error_finish
	
error4Bh_11_label:
	lea DX, error4Bh_11
	call Write_message
	jmp Error_finish
	
;6)  Обработка завершения программы
NO_ERROR_4Bh:
	mov AX, 4D00h	;вызываем функцию 4Dh прерывания int 21h
	int 21h			;в качестве результата в регистре AH будет причина завершения
	
	mov BX, AX
	add BH, 30h		;вычисляем код завершения как символ в таблице ASCII
	lea DI, finish_message
	mov [DI+29], BL		;добавляем код завершения в finish_message
	lea DX, finish_message
	call Write_message
	
	cmp AH, 0
	je FinishCode_0
	
	cmp AH, 1
	je FinishCode_1
	
	cmp AH, 2
	je FinishCode_2
	
	cmp AH, 3
	je FinishCode_3
	
	
FinishCode_0:
	lea DX, finish_code_0
	call Write_message
	jmp Error_finish
	
FinishCode_1:
	lea DX, finish_code_1
	call Write_message
	jmp Error_finish
	
FinishCode_2:
	lea DX, finish_code_2
	call Write_message
	jmp Error_finish
	
FinishCode_3:
	lea DX, finish_code_3
	call Write_message	
	
Error_finish:
	mov AH, 4Ch		;завершение по функции 4C
	int 21h
	
Main 	ENDP
CODE    		ENDS

ALL_MEMORY	SEGMENT	;пустой сегмент в конце
ALL_MEMORY  ENDS	;для определения памяти, которая не используемся в CS

		END Main