OVL1 segment
	assume cs:OVL1, ds:nothing, ss:nothing, es:nothing

MAIN proc far
	push DS
	push AX
	push DI
	push DX
	push BX
	
	mov DS, AX
	lea DX, CS:message	;������� ��������� � ���, ���
	call Write_message	;��� ������ ������ �������
	
	lea BX, CS:adress
	add BX, 23			;������������� ������ � ������ �����
	mov DI, BX			;� DI - ������ ���������� �������
	mov AX, CS			;� AX - �����, ����������� ������������������
	call WRD_TO_HEX
	
	lea DX, CS:adress	;������� ��������� � ���, ��� 
	call Write_message	;��� ������ ������ �������
	
	pop BX
	pop DX
	pop DI
	pop AX
	pop DS
	retf
MAIN endp

message 	db 	10, 13, 'There is the second overlay.', 10, 13, '$'
adress 		db 	'Its segment adress:     ', 10, 13, '$'

; ������� ������ ��������� �� �����
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
;���� � AL ����������� � ��� ����������������� ������� � AX
	push CX 
	mov AH,AL 
	call TETR_TO_HEX 
	xchg AL,AH 
	mov CL,4 
	shr AL,CL 
	call TETR_TO_HEX ; � AL - ������� ����
	pop CX ;� AH - �������
	ret 
BYTE_TO_HEX ENDP 

WRD_TO_HEX PROC near 
;������� � ����������������� ������� ��������� ����� � AX
; � AX - �����, � DI - ������ �� ��������� ������
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