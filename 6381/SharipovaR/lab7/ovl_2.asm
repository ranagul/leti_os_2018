OVL1 segment
	assume cs:OVL1, ds:nothing, ss:nothing, es:nothing

MAIN proc far
	push DS
	push AX
	push DI
	push DX
	push BX
	
	mov DS, AX
	lea DX, CS:message	;выводим сообщение о том, что
	call Write_message	;был вызван первый оверлей
	
	lea BX, CS:adress
	add BX, 23			;устанавливаем курсор в нужное место
	mov DI, BX			;в DI - адресс последнего символа
	mov AX, CS			;в AX - число, необходимое переконвертировать
	call WRD_TO_HEX
	
	lea DX, CS:adress	;выводим сообщение о том, что 
	call Write_message	;был вызван второй оверлей
	
	pop BX
	pop DX
	pop DI
	pop AX
	pop DS
	retf
MAIN endp

message 	db 	10, 13, 'There is the second overlay.', 10, 13, '$'
adress 		db 	'Its segment adress:     ', 10, 13, '$'

; функция вывода сообщения на экран
Write_message	PROC
	push AX
	mov AH, 09h
	int 21h
	pop AX
	ret
Write_message	ENDP

TETR_TO_HEX PROC near
	and AL,0Fh 
	cmp AL,09 
	jbe NEXT 
	add AL,07 
NEXT: 
	add AL,30h 
	ret 
TETR_TO_HEX ENDP 

BYTE_TO_HEX PROC near 
;Байт в AL переводится в два шестнадцатеричных символа в AX
	push CX 
	mov AH,AL 
	call TETR_TO_HEX 
	xchg AL,AH 
	mov CL,4 
	shr AL,CL 
	call TETR_TO_HEX ; в AL - старший байт
	pop CX ;в AH - младший
	ret 
BYTE_TO_HEX ENDP 

WRD_TO_HEX PROC near 
;перевод в шестнадцатеричную систему счисления числа в AX
; в AX - номер, в DI - ссылка на последний символ
	push BX 
	mov BH,AH 
	call BYTE_TO_HEX 
	mov [DI],AH 
	dec DI 
	mov [DI],AL 
	dec DI 
	mov AL,BH 
	call BYTE_TO_HEX 
	mov [DI],AH 
	dec DI 
	mov [DI],AL 
	pop BX 
	ret 
WRD_TO_HEX ENDP 

OVL1 ends
end MAIN