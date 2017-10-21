; Elizabeth Wanic
; 8 March 2017
; CS 3140 - Assignment 5
; Command line for assembly : 
;    nasm -f elf32 -g assn5.asm
; Command line for gcc :
;    gcc -o assn5 -m32 assn5.o dns.o lib4.o
; 
; User must enter ./assn5 followed by a URL to run the program
; The URL must start with http://
; 


bits 32                 ; 32 bit program
section .text           ; section declaration

global main             ; let gcc find function
extern resolv           ; declare use of external functions
extern l_strlen
extern l_write 
extern l_close 
extern l_open 

struc sockaddr_in
    .sin_family:    resw 1
    .sin_port:      resw 1
    .sin_addr:      resd 1
    .sin_pad:       resb 8
endstruc

main:
	mov 	eax, [esp + 4]		; eax holds argc
	cmp 	eax, 2				; check if argc is 2
	jne 	error_ret 			; jump to error return if not 2

	mov 	ebp, [esp + 8] 		; else, ebp holds address to argv
	mov 	edi, [ebp + 4]		; address of argv[1] in edi

	push  	edi					; push pointer to argv[1]
	call 	l_strlen			; call l_strlen
	add 	esp, 4				; clean up the stack

    mov 	[length], eax 		; l_strlen's return value 
    xor		ecx, ecx 		 	; set count to 0		

copy_loop:
; copies the full url from argv[1]
    cmp     ecx, dword [length] ; check if count is at length
    je	 	host_loop_set		; find hostname when done copying full_url

    mov 	al, byte [edi + ecx]		; al has the char 
    mov 	byte [full_url + ecx], al 	; char moved to full_url 

    inc 	ecx					; increment counter 
    jmp 	copy_loop 			; continue with chars 

host_loop_set:
; set up to get host name 
	xor 	ecx, ecx 			; counter back to zero
	add 	ecx, 7              ; start after http://

host_loop:
; finds the host name by looking for either match with length or the first /
	cmp     ecx, dword [length] ; check if count is at length
    je	 	host_null		    ; jump to print if hostname is full_url

    mov 	al, byte [edi + ecx]		; al has the char  
    cmp 	byte al, 0x2F				; check for /
    je 		has_slash 					; jump if / found 
    mov 	byte [host_name + ecx - 7], al 	; char moved to host_name 

    inc 	ecx					; increment counter 
    jmp 	host_loop 			; continue with chars 


has_slash:                      
; check if url is only host_name plus a / on the end 
	mov 	ebx, [length]		; length in ebx 
	dec 	ebx         		; decrement length by 1
	cmp 	ebx, ecx            ; check if at end of argv[1]
    je 		host_null           ; jump to print if no file name in url


get_len_hostname:                 
; otherwise there is something after hostname and /
; first we add a null to host_name and get its length 
	mov  	byte [host_name + ecx -7], 0x0  	; add the null 

	mov 	[count], ecx 		; save position in the full_url

	push 	host_name  			; get length of host name
	call 	l_strlen
	add 	esp, 4

	mov 	[len_hn], eax 		; save it in len_hn

	mov 	ecx, [count] 		; restore the value to ecx
    xor     edx, edx  

file_name_loop:
; then we copy everything after the first / into file name long 
	cmp     ecx, dword [length] ; check if count is at length
    je	 	find_short_file_name	    ; if it is need to get short file name

 	mov 	al, byte [edi + ecx]		; al has the char  
    mov 	byte [file_name_long + edx], al 	; char being moved to file_name_long

    inc     edx 
   	inc 	ecx					; increment counter 
    jmp 	file_name_loop 		; continue with chars 

find_short_file_name:
; separate the short name for the file from file path 
; but first we check to see if the last char is a /
; if it is, then it's not a file name, so we jump out 
; we will need to ask for index.html after the path  
    dec     edx                                 ; get to last char
    mov     al, byte [file_name_long + edx]     ; al has the char  
    mov     byte [temp], al                     ; save al in temp 
    cmp     byte al, 0x2F                       ; check for /
    je      add_null                            ; jump if found - not a file name 

; otherwise we get the short name 
; but first we get the length of file_name_long and add a null 
    inc     edx 
    mov     byte [file_name_long + edx], 0x0        ; add the null 

    push    file_name_long          ; get length of file_name_long
    call    l_strlen
    add     esp, 4

    mov     [len_fnl], eax          ; save it in len_fnl 

    mov     al, byte [temp] ; put temp back in al 
    dec     edx
    xor     ebx, ebx        ; count for backwards_file_short

backwards_file_short:       
; get the short file name by working backwards 
    mov     byte [file_name_backwards + ebx], al ; move last byte into fnb
    dec     edx                                  ; dec ecx (move backwards)
    mov     al, byte [file_name_long + edx]      ; previous char
    cmp     byte al, 0x2F                        ; check for /
    je      file_name_forward_set                ; if / then have full file name
    inc     ebx                                  ; else inc edx (move forwards)
    jmp     backwards_file_short                 ; move through loop again

file_name_forward_set:
; set up to reverse file name 
    inc     ebx 
    mov     byte [file_name_backwards + ebx], 0x0 ; null terminator

    push    file_name_backwards      ; get len of short file name 
    call    l_strlen
    add     esp, 4                   ; clean up the stack 

    mov     [len_fns], eax           ; save len of short file name

    dec     eax                      ; don't want to copy the null 
    xor     edx, edx                 ; edx is forward count 

forward_loop:                       
; reverse the order for the file name 
    mov     bl, byte [file_name_backwards + eax] ; count backwards in fnb
    mov     byte [file_name_short + edx], bl     ; put char into fns 
    dec     eax                                 ; get to previous char
    inc     edx                                 ; next position in fns
    cmp     eax, 0                              ; check if done with fnb
    jl      file_null                           ; jump out if you are
    jmp     forward_loop                        ; else loop again 

file_null:
; add a null for file_name_short 
    mov     byte [file_name_short + edx], 0x0 ; add a null to short file name

file_create:
; test out opening a file 
    mov     eax, 0x05             ; 5 sys call for open
    mov     ebx, file_name_short  ; name of file 
    mov     ecx, 1102o            ; O_CREAT, O_TRUNCATE and O_RDWR
    mov     edx, 0666o            ; rw-rw-rw-
    int     0x80                  ; execute sys call 
    mov     [fd], eax             ; fd of opened file  

printAgain:
; this prints if you have a short file name for debugging
    mov     eax, 0x04           ; 4 sys call for write
    mov     ebx, 0x01           ; fd for stdout is 1
    mov     ecx, file_name_short       ; pointer to fns
    mov     edx, [len_fns]      ; write len_fns bytes 
    int     0x80                ; execute write sys call

    mov     eax, 0x04           ; 4 sys call for write
    mov     ebx, 0x01           ; fd for stdout is 1
    mov     ecx, space          ; pointer to a space 
    mov     edx, 1              ; write 1 byte  
    int     0x80                ; execute write sys call

shortPrint:
; this prints the backwards file name for debugging
    mov     eax, 0x04           ; 4 sys call for write
    mov     ebx, 0x01           ; fd for stdout is 1
    mov     ecx, file_name_backwards        ; pointer to fnb
    mov     edx, [len_fns]      ; write len_fns bytes  
    int     0x80                ; execute write sys call

    mov     eax, 0x04           ; 4 sys call for write
    mov     ebx, 0x01           ; fd for stdout is 1
    mov     ecx, space          ; pointer to a space 
    mov     edx, 1              ; write 1 byte  
    int     0x80                ; execute write sys call

    mov     eax, 0x04           ; 4 sys call for write
    mov     ebx, 0x01           ; fd for stdout is 1
    mov     ecx, newline        ; pointer to a space 
    mov     edx, 1              ; write 1 byte  
    int     0x80                ; execute write sys call
    jmp     msg_C_loop_set 

add_null:
; this adds a null at the end of the type hostname/something/ 
; no file name 
    inc     edx 
    mov     byte [file_name_long + edx], 0x0        ; add the null 

    push    file_name_long          ; get length of file_name_long
    call    l_strlen
    add     esp, 4

    mov     [len_fnl], eax          ; save it in len_fnl 

file_create_default_B:
; opening a file with no file name in path for B type
    mov     eax, 0x05           ; 5 sys call for open
    mov     ebx, dflt_file      ; name of file 
    mov     ecx, 1102o          ; O_CREAT, O_TRUNCATE and O_RDWR
    mov     edx, 0666o          ; rw-rw-rw-
    int     0x80                ; execute sys call  
    mov     [fd], eax           ; fd of opened file 

    xor     ecx, ecx            ; counter for get_msgB
    xor     edx, edx            ; counter for pieces 

msg_B_loop1:
; copy get_msg1 into get_msgB
    cmp     edx, 4              ; get_msg1 is 4 bytes
    je      msg_B_loop2_set     ; jump to next piece when copied

    mov     bl, byte [get_msg1 + edx] ; move char from get_msg1
    mov     byte [get_msg + ecx], bl  ; put char into get_msgB

    inc     ecx                 ; get_msgB count
    inc     edx                 ; get_msg1 count
    jmp     msg_B_loop1

msg_B_loop2_set:
    mov    eax, [len_fnl]      ; len of fnl 
    xor    edx, edx            ; reset counter

msg_B_loop2:
; copy file_name_long into get_msgB
    cmp     edx, eax             ; file_name_long len in eax 
    je      msg_B_loop3_set      ; jump to next piece when copied

    mov     bl, byte [file_name_long + edx] ; move char from fnl
    mov     byte [get_msg + ecx], bl ; put char into get_msgB

    inc     ecx                 ; get_msgB count
    inc     edx                 ; file_name_long count
    jmp     msg_B_loop2

msg_B_loop3_set:
     xor    edx, edx            ; reset counter

msg_B_loop3:
; copy get_msg2 into get_msgB
    cmp     edx, 17              ; get_msg2 17 bytes
    je      msg_B_loop4_set      ; jump to next piece when copied

    mov     bl, byte [get_msg2 + edx] ; move char from get_msg2
    mov     byte [get_msg + ecx], bl  ; put char into get_msgB

    inc     ecx                 ; get_msgB count
    inc     edx                 ; get_msg2 count
    jmp     msg_B_loop3

msg_B_loop4_set:
    xor     edx, edx            ; reset counter

msg_B_loop4:
; copy host_name into get_msgB
    cmp     edx, dword [len_hn]   ; host_name is len_hn bytes
    je      msg_B_loop5_set       ; jump to next piece when copied

    mov     bl, byte [host_name + edx] ; move char from host_name
    mov     byte [get_msg + ecx], bl   ; put char into get_msgB

    inc     ecx                 ; get_msgB count
    inc     edx                 ; host_name count
    jmp     msg_B_loop4

msg_B_loop5_set:
    xor     edx, edx            ; reset counter

msg_B_loop5:
; copy conn_msg into get_msgB
    cmp     edx, 24              ; conn_msg is 24 bytes
    je      prelimB              ; jump to next piece when copied

    mov     bl, byte [conn_msg + edx] ; move char from conn_msg
    mov     byte [get_msg + ecx], bl  ; put char into get_msgB

    inc     ecx                 ; get_msgB count
    inc     edx                 ; conn_msg count
    jmp     msg_B_loop5

prelimB:
    mov     byte [get_msg + ecx], 0 ; null terminator 
    jmp     prelimAll

msg_C_loop_set:
    xor     ecx, ecx            ; counter for get_msgC
    xor     edx, edx            ; counter for pieces 

msg_C_loop1:
; copy get_msg1 into get_msgC
    cmp     edx, 4              ; get_msg1 is 4 bytes
    je      msg_C_loop2_set     ; jump to next piece when copied

    mov     bl, byte [get_msg1 + edx] ; move char from get_msg1
    mov     byte [get_msg + ecx], bl  ; put char into get_msgB

    inc     ecx                 ; get_msgC count
    inc     edx                 ; get_msg1 count
    jmp     msg_C_loop1

msg_C_loop2_set:
    mov    eax, [len_fnl]      ; len of fnl 
    xor    edx, edx            ; reset counter

msg_C_loop2:
; copy file_name_long into get_msgC
    cmp     edx, eax             ; file_name_long len in eax 
    je      msg_C_loop3_set      ; jump to next piece when copied

    mov     bl, byte [file_name_long + edx] ; move char from fnl
    mov     byte [get_msg + ecx], bl ; put char into get_msgB

    inc     ecx                 ; get_msgC count
    inc     edx                 ; file_name_long count
    jmp     msg_C_loop2

msg_C_loop3_set:
     xor    edx, edx            ; reset counter

msg_C_loop3:
; copy get_msg2 into get_msgB
    cmp     edx, 17              ; get_msg2 17 bytes
    je      msg_C_loop4_set     ; jump to next piece when copied

    mov     bl, byte [get_msg2 + edx] ; move char from get_msg2
    mov     byte [get_msg + ecx], bl  ; put char into get_msgC

    inc     ecx                 ; get_msgC count
    inc     edx                 ; get_msg2 count
    jmp     msg_C_loop3

msg_C_loop4_set:
    xor     edx, edx            ; reset counter

msg_C_loop4:
; copy host_name into get_msgB
    cmp     edx, dword [len_hn]   ; host_name is len_hn bytes
    je      msg_C_loop5_set       ; jump to next piece when copied

    mov     bl, byte [host_name + edx] ; move char from host_name
    mov     byte [get_msg + ecx], bl   ; put char into get_msgC

    inc     ecx                 ; get_msgC count
    inc     edx                 ; host_name count
    jmp     msg_C_loop4

msg_C_loop5_set:
    xor     edx, edx            ; reset counter

msg_C_loop5:
; copy conn_msg into get_msgB
    cmp     edx, 24              ; conn_msg is 24 bytes
    je      prelimC              ; jump to next piece when copied

    mov     bl, byte [conn_msg + edx] ; move char from conn_msg
    mov     byte [get_msg + ecx], bl  ; put char into get_msgC

    inc     ecx                 ; get_msgC count
    inc     edx                 ; conn_msg count
    jmp     msg_C_loop5

prelimC:
    mov     byte [get_msg + ecx], 0 ; null terminator 
    jmp     prelimAll 

host_null:
    mov     byte [host_name + ecx], 0x0 ; add a null on the end of hostname
    push    host_name                   ; get length of host name
    call    l_strlen
    add     esp, 4

    mov     [len_hn], eax               ; save it in len_hn

open_file_A_type:
    mov     eax, 0x05           ; 5 sys call for open
    mov     ebx, dflt_file      ; name of file 
    mov     ecx, 1102o          ; O_CREAT, O_TRUNCATE and O_RDWR
    mov     edx, 0666o          ; rw-rw-rw-
    int     0x80                ; execute sys call
    mov     [fd], eax           ; fd of opened file 

getmsgA_set:
; GET message if just url with nothing afterwards or just /
    xor     ecx, ecx            ; counter for get_msgA
    xor     edx, edx            ; counter for pieces 

msg_A_loop1:
; copy get_msg1 into get_msgA
    cmp     edx, 4              ; get_msg1 is 4 bytes
    je      msg_A_loop2_set     ; jump to next piece when copied

    mov     bl, byte [get_msg1 + edx] ; move char from get_msg1
    mov     byte [get_msg + ecx], bl  ; put char into get_msgA

    inc     ecx                 ; get_msgA count
    inc     edx                 ; get_msg1 count
    jmp     msg_A_loop1

msg_A_loop2_set:
     xor    edx, edx            ; reset counter

; copy dflt_path into get_msgA
    mov     bl, byte [dflt_path + edx] ; move char from dflt_path
    mov     byte [get_msg + ecx], bl ; put char into get_msgA

    inc     ecx                 ; get_msgA count
    inc     edx                 ; dflt_path count

msg_A_loop3_set:
    xor     edx, edx            ; reset counter

msg_A_loop3:
; copy get_msg2 into get_msgA
    cmp     edx, 17              ; get_msg2 17 bytes
    je      msg_A_loop4_set     ; jump to next piece when copied

    mov     bl, byte [get_msg2 + edx] ; move char from get_msg2
    mov     byte [get_msg + ecx], bl ; put char into get_msgA

    inc     ecx                 ; get_msgA count
    inc     edx                 ; get_msg2 count
    jmp     msg_A_loop3

msg_A_loop4_set:
    xor     edx, edx            ; reset counter

msg_A_loop4:
; copy host_name into get_msgA
    cmp     edx, [len_hn]       ; host_name is [len_hn] bytes
    je      msg_A_loop5_set     ; jump to next piece when copied

    mov     bl, byte [host_name + edx] ; move char from host_name
    mov     byte [get_msg + ecx], bl ; put char into get_msgA

    inc     ecx                 ; get_msgA count
    inc     edx                 ; host_name count
    jmp     msg_A_loop4

msg_A_loop5_set:
    xor     edx, edx            ; reset counter

msg_A_loop5:
; copy conn_msg into get_msgA
    cmp     edx, 24              ; conn_msg is 24 bytes
    je      prelimA              ; jump to next piece when copied

    mov     bl, byte [conn_msg + edx] ; move char from conn_msg
    mov     byte [get_msg + ecx], bl ; put char into get_msgA

    inc     ecx                 ; get_msgA count
    inc     edx                 ; conn_msg count
    jmp     msg_A_loop5

prelimA:
    mov     byte [get_msg + ecx], 0 ; null terminator 

prelimAll:
; print GET message for debugging
    push    get_msg
    call    l_strlen
    add     esp, 4                
    mov     [get_len], eax 

    mov     eax, 0x04           ; 4 sys call for write
    mov     ebx, 0x01           ; fd for stdout is 1
    mov     ecx, get_msg       ; pointer to host name 
    mov     edx, [get_len]             ; write 100 bytes 
    int     0x80                ; execute write sys call

    mov     eax, 0x04           ; 4 sys call for write
    mov     ebx, 0x01           ; fd for stdout is 1
    mov     ecx, space          ; pointer to a space 
    mov     edx, 1              ; write 1 byte  
    int     0x80                ; execute write sys call

prelim:
; this prints for everything for debugging
    mov     eax, 0x04           ; 4 sys call for write
    mov     ebx, 0x01           ; fd for stdout is 1
    mov     ecx, host_name      ; pointer to host name 
    mov     edx, [len_hn]       ; write [length] bytes 
    int     0x80                ; execute write sys call

    mov     eax, 0x04           ; 4 sys call for write
    mov     ebx, 0x01           ; fd for stdout is 1
    mov     ecx, space          ; pointer to a space 
    mov     edx, 1              ; write 1 byte  
    int     0x80                ; execute write sys call

    mov     eax, 0x04           ; 4 sys call for write
    mov     ebx, 0x01           ; fd for stdout is 1
    mov     ecx, file_name_long ; pointer to long file name 
    mov     edx, [len_fnl]      ; write length bytes 
    int     0x80                ; execute write sys call

    mov     eax, 0x04           ; 4 sys call for write
    mov     ebx, 0x01           ; fd for stdout is 1
    mov     ecx, space          ; pointer to a space 
    mov     edx, 1              ; write 1 byte  
    int     0x80                ; execute write sys call

    mov     ebx, 0              ; exit on 0 if correct

recieve_initial:
; initialize first three bytes of recieve_buf to 0 and flag to 0
    mov     byte [recieve_buf], 0
    mov     byte [recieve_buf + 1], 0
    mov     byte [recieve_buf + 2], 0
    mov     dword [flag], 0x00

create_socket:
; create socket
    push    dword 0
    push    dword 1         ; SOCK_STREAM
    push    dword 2         ; AF_INET
    mov     ecx, esp        ; pointer to args
    mov     ebx, 1          ; sys_socket
    mov     eax, 0x66       ; sys_socketcall
    int     0x80            ; socket fd returned in eax
    add     esp, 12

    mov     [sock_fd], eax     ; save socket fd 

; resolve the host name to IP address
    push    host_name
    call    resolv
    add     esp, 4

;move the IP address into struct
    mov     [server + sockaddr_in.sin_addr], eax

;connect
    push    16               ; fixed length of the sockaddrstruct
    push    server           ; 
    push    dword [sock_fd]  ;   
    mov     ecx, esp         ; pointer to args
    mov     ebx, 3           ; sys_connect 
    mov     eax, 0x66        ; sys_socketcall 
    int     0x80
    add     esp, 12

; send get request
    push    dword 0
    push    dword [get_len]     ; length of get message 
    push    get_msg             ; pointer to message 
    push    dword [sock_fd]     ; socket fd 
    mov     ecx, esp            ; pointer to args
    mov     ebx, 9              ; sys_send 
    mov     eax, 0x66           ; sys_socketcall 
    int     0x80
    add     esp, 16

    mov     eax, 516
    mov     dword [recieve_buff_len], eax

recieve_loop:
; loop to receive 
    push    dword 0
    push    dword [recieve_buff_len]    ; length of recieve_buf
    push    recieve_buf                 ; pointer to recieve_buf
    push    dword [sock_fd]             ; socket fd 
    mov     ecx, esp                    ; pointer to args
    mov     ebx, 10                     ; sys_recv
    mov     eax, 0x66                   ; sys_socketcall 
    int     0x80
    add     esp, 16

    mov     dword [bytes_read], eax  ; bytes read off the socket 
    
    cmp     eax, dword 0x00          ; eax holds number of bytes read
    jle     close                    ; finished when this is 0 

    cmp     dword [flag], 0x01       ; check if the header was already found
    je      copy                     ; jump to copy if it is

header_check_init:
; initialize for 'end of header' check
    xor     eax, eax                ; counter for recieve_buf

header_check_loop:
    cmp     dword [recieve_buf + eax], 0x0A0D0A0D   ; check for sequence 
    je      header_found
    inc     eax 
    cmp     eax, 513                ; check when three bytes left 
    je      try_again               ; keep looking for header   
    jmp     header_check_loop       ; move through buffer one byte at a time

try_again:
; put the last three bytes at beginning 
    mov     ebx, dword [recieve_buf + eax] ; move last 3 bytes to beginning
    mov     dword [recieve_buf], ebx       ; of recieve_buf (plus one junk byte)
    jmp     recieve_loop                   ; then read more 

header_found: 
; \r\n\r\n was found, set flag and start copying to file 
    mov     dword [flag], 0x01       ; set flag to 1    
    mov     ebx, [bytes_read]        ; bytes read in ebx
    sub     ebx, eax                 ; eax is where you are now
                                     ; result is number left in buffer
    lea     ecx, [recieve_buf + eax] ; address of where you are now

    push    ebx                      ; number of bytes after \r\n\r\n
    push    ecx                      ; current location in recieve_buf
    push    dword [fd]               ; fd to the opened file 
    call    l_write                
    add     esp, 12

    jmp     recieve_loop
    
copy:
; copy text after \r\n\r\n into fd 
    push    dword[bytes_read]       ; number of bytes read
    push    recieve_buf             ; write from recieve_buf
    push    dword [fd]              ; to the opened file 
    call    l_write                
    add     esp, 12

    jmp     recieve_loop            ; check if more to read  

error_ret:
; return -1 on an input error 
	mov 	ebx, -1				; put -1 in ebx to return an error 

close:
; close the file 
    push    dword [fd]      ; fd for opened file 
    call    l_close         ; close it
    add     esp, 4          ; clean up the stack 

done:
; exit 
    mov     ebx, 0x01       ; return 1 for success 
    mov     eax, 0x01       ; 1 is sys call for exit
    int     0x80            ; execute exit sys call

section .data   ; section declaration

get_msg1 db "GET "
get_msg2 db " HTTP/1.0",13,10,"Host: "
conn_msg db 13,10,"Connection: close",13,10,13,10,0
space db " "
newline db 10
dflt_file db "index.html",0
dflt_path db "/"

server: istruc sockaddr_in
        at sockaddr_in.sin_family, dw 2
        at sockaddr_in.sin_port, dw 0x5000
        at sockaddr_in.sin_addr, dd 0x0200a8c0  ; will be changed in the code
        iend

section .bss    ; section declaration

count: resd 1 ; counter
temp: resb 1
flag: resd 1 

fd: resd 1 ; file descriptor

length: resd 1  ; length of argv[1] - full url length 
len_hn: resd 1  ; length of host name 
len_fnl: resd 1 ; length file name long
len_fns: resd 1 ; length of file name short 
get_len: resd 1 ; length of get message 

full_url: resb 450  ; full url length 
host_name: resb 50	; host name 
file_name_long: resb 400 ; path to file 
file_name_backwards: resb 100 ; file name for output 
file_name_short: resb 100

get_msg: resb 400 ; comprehensive for all get messages 

sock_fd:          resd 1
recieve_buf:      resb 516
recieve_buff_len: resd 1
bytes_read:       resd 1











