ASSUME CS:CODE, DS:DATA, SS:STACK

CODE SEGMENT

IS_LOADED PROC ;���������, ����������� �� ��������� ����������� � ������
	push bx
	push dx
	push es
	mov ah, 35h	
	mov al, 09h	
	int 21h
	mov dx, es:[bx + ADR-Interr_09]
	cmp dx, 0506h ; �������� �� ���������� ���� ����������
	je loaded
	mov al, 00h
	jmp not_loaded

LOADED:
	mov al, 01h	

NOT_LOADED:
	pop es
	pop dx
	pop bx
	ret
IS_LOADED ENDP


;����������� ���������� ���������� ��� 09
Interr_09 PROC FAR
	jmp start
;������:
	REQ_KEY_1   db 2h ;����� 1 ����� �������� �� ������ 'A'
	REQ_KEY_2   db 3h ;����� 2 ����� �������� �� ������ 'B'
	REQ_KEY_3   db 4h ;����� 3 ����� �������� �� ������ 'C'
	PSP_AD1 dw ?  
	PSP_AD2 dw ?
	keep_ip_09 dw ? ;��� �������� �������� ������� ���������� 09
	keep_cs_09 dw ?	; �������� ������� ���������� 09
	SAVED_AX dw ?
   	SAVED_SP dw ?	;��� �������� �����
   	SAVED_SS dw ?
	ADR dw 0506h

start:

	   	mov SAVED_SP,sp		
	mov SAVED_SS,ss		
	
	mov di,cs
	mov ss,di
	mov sp,offset STACK_END	

	
    	mov cs:SAVED_AX,ax	
	in AL, 60h
	cmp AL, REQ_KEY_1 ;���������, ������ �� ��� ����
	je 	key1  ;���� �� (����� 1), �� ����� �������� � �� 'A'
		
	cmp AL, REQ_KEY_2 ;���������, ������ �� ��� ����
	je 	key2 ;���� �� (����� 2), �� ����� �������� � �� 'B'

	cmp AL, REQ_KEY_3 ;���������, ������ �� ��� ����
	je 	key3 ;���� �� (����� 3), �� ����� �������� � �� 'C'
		
	mov ax,cs:SAVED_AX
	
	mov ss,SAVED_SS
	mov sp,SAVED_SP
	
	jmp	 dword ptr cs:[keep_ip_09] ;��������� �� �������������� ����������

	key1:
		mov CL, 'A'
		jmp do_req
	key2:
		mov CL, 'B'
		jmp do_req
	key3:
		mov CL, 'C'

do_req:

	in al,61h	;����� �������� ����� ���������� ������������
	mov ah,al	 ;��������� ���
	or al,80h	;���������� ��� ���������� ��� ����������
	out 61h,al	;� ������� ��� � ����������� ����
	xchg AH, AL	;������� �������� �������� �����
	out 61h,al	;� �������� ��� �������

	mov al,20h	;������� ������ "����� ����������"
	out 20h,al	;����������� ���������� 8259

	; ��������� ��������
	push bx
	push cx
	push dx				

	mov AH, 05h ;�������, ������������ �������� ������ � ����� ����������
	mov CH, 00h ;������ � CL ��� ������ �����, �������� �������� CH	
	int 16h	

	; ��������������� ��������
	pop dx    
	pop cx
	pop bx				
	mov ax,cs:SAVED_AX
	
	mov ss,SAVED_SS
	mov sp,SAVED_SP		; ��������������� ����		
	iret				; ����� �� ����������
Interr_09 ENDP

	NEW_STACK dw 256 dup(?)		; ����
	STACK_END:
LAST_BYTE:

;��������, ������� �� ������� /un
Un_check PROC FAR
	push es
	
	mov ax, keep_PSP
	mov es, ax

	cmp	byte ptr es:[82h],'/'
	jne	not_un
	cmp	byte ptr es:[83h],'u'
	jne	not_un
	cmp	byte ptr es:[84h],'n'
	jne	not_un
	mov flag,1
		
not_un:
	pop es
	ret
Un_check ENDP

; ��������� ����������� ���������� ���������� � ��������� ����������� ����������
Load_int PROC 
	push ax
	push bx
	push dx
	push es

	mov ah, 35h ;�������, �������� �������� �������� � ES, �������� � BX
	mov al, 09h
	int 21h

	mov keep_ip_09, bx  ;����������� ��������
	mov keep_cs_09, es  ;� ��������

	push ds
	mov dx, offset Interr_09
	mov ax, seg Interr_09
	mov ds, ax

	mov ah, 25h  ;�������, �������� ���������� ���������� �� ��������� � DX � AX
	mov al, 09h
	int 21h
	pop ds

	mov dx, offset Message1
	call Write_message 

	pop es
	pop dx
	pop bx
	pop ax

	ret
Load_int ENDP

; ��������� ����������� ����������
Unload_int PROC 
	push ax
	push bx
	push dx
	push es

	mov ah, 35h
	mov al, 09h
	int 21h

	CLI
	push ds
	mov dx, es:[bx + keep_ip_09-Interr_09]
 	mov ax, es:[bx + keep_cs_09-Interr_09]
		
	mov ds, ax
	mov ah, 25h
	mov al, 09h
	int 21h
	pop ds
	STI

	mov dx, offset Message2
	call Write_message 
	
	push es
	mov cx,es:[bx+PSP_AD1-Interr_09]
	mov es,cx
	mov ah,49h
	int 21h
	
	pop es
	mov cx,es:[bx+PSP_AD2-Interr_09]
	mov es,cx
	int 21h

	pop es
	pop dx
	pop bx
	pop ax
	
	ret
Unload_int ENDP

Make_resident  PROC
	mov dx, offset LAST_BYTE
	mov cl, 04h
	shr dx, cl
	inc dx
	mov ax, 3100h   ;31h ��������� ���������, �������� � ����������� � ������
	int 21h
Make_resident  ENDP

; ������� ������ ��������� �� �����
Write_message PROC 
	push ax
	mov ah, 09h
	int	21h
	pop ax
	ret
Write_message ENDP

Main PROC 
	push ds
	call IS_LOADED
	cmp al, 01h	;  01h, ���� ��������� ����������� ����������� � ������
	je start_program
	
	mov bx, 02Ch
	mov ax, [bx]
	mov PSP_AD2, ax
	mov PSP_AD1, ds 

start_program:
	mov dx, ds 
	sub ax, ax    
	xor bx, bx
	mov ax, DATA  
	mov ds, ax    
	mov keep_PSP, dx 
	xor dx, dx				

	call Un_check		;���������, ������� �� /un
	cmp flag, 1
	je un_block

	call IS_LOADED  ;���������, ����������� �� ����������
	cmp al, 01h
	jne not_load_block
	
	mov dx, offset Message3  ;��������� ��� ���� �����������
	call Write_message 
	jmp exit

not_load_block:		;��������� �� �������� ����������� � ������
	call Load_int
	call Make_resident
un_block:
	call IS_LOADED
	cmp al, 00h
	je not_loaded_un
	call Unload_int		;������������ ��� /un � ��������� ��� �� ���� ���������
	
	jmp exit

not_loaded_un:		;������� /un, �� ��������� ��� ���������
	mov dx, offset Message4
	call Write_message 
    	jmp exit
	
exit:
   	mov ax, 4C00h
	int 21h
Main ENDP
CODE 			ENDS

DATA SEGMENT	
	flag	dw 0
	Message1    db 'Resident program has been loaded', 0dh, 0ah, '$'
  	Message2	db 'Resident program has been unloaded', 0dh, 0ah, '$'
   	Message3	db 'Resident program is already loaded', 0dh, 0ah, '$'
   	Message4	db 'Resident program has already been unloaded!', 0dh, 0ah, '$'
	keep_PSP dw ?
	
DATA ENDS	

STACK SEGMENT STACK 
	DW 64 DUP(?)
STACK ENDS

		END Main
