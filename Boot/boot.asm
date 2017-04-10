;*********************************************
;	boot.asm
;		- Some Insignificant Tiny OS Bootloader
;
;	By Scuwr
;    Code addapted from http://www.brokenthorn.com/
;*********************************************

bits    16
org	   0

start:    jmp short main    
          nop                 ; use only if prev instr is 
                              ; jmp short main       

;*********************************************
;	BIOS Parameter Block
;    http://www.cse.scu.edu/~tschwarz/coen252_04/Lectures/FAT.html
;*********************************************

oem_name:                db "SITOS1.0"
bytes_per_sector:        dw 512
sectors_per_cluster:     db 1
reserved_sectors:        dw 1
number_of_FATs:          db 2
root_entries:            dw 224
total_sectors:           dw 2880
media_type:	          db 0xf0 ; f8 for fixed media
sectors_per_FAT:	     dw 9
sectors_per_track: 	     dw 18
heads_per_cylinder:      dw 2
hidden_sectors:          dd 0
total_sectors_bignum:    dd 0
drive_number: 	          db 0
current_head: 		     db 0 ; unused in FAT filesystem
ext_boot_signature:      db 0x29
volume_serial_number:	dd 0xa0a1a2a3
volume_label: 	          db "TOS FLOPPY "
file_system_id: 	     db "FAT12   "

;*********************************************
;    Bootloader Entry Point
;*********************************************

main:

     ;----------------------------------------------------
     ; Set segment registers and stack
     ;----------------------------------------------------

          mov     ax, 0x07c0
          mov     ds, ax
          mov     es, ax

          xor     ax, ax
          mov     ss, ax
          mov     sp, 0x7c00

     ;----------------------------------------------------
     ; Display loading message
     ;----------------------------------------------------
     
          mov     ax, 0x3          ; clear screen
          int     0x10
          mov     si, msg_loading
          call    Print
          
     ;----------------------------------------------------
     ; Load root directory table
     ;----------------------------------------------------

     load_root:
     
     ; get root directory size and store in "cx"
     
          xor     cx, cx
          xor     dx, dx
          mov     ax, 0x0020                ; 32 bytes per FAT entry
          mul     WORD [root_entries]
          div     WORD [bytes_per_sector]
          xchg    ax, cx
          
     ; compute location of root directory and store in "ax"
     
          mov     al, BYTE [number_of_FATs]
          mul     WORD [sectors_per_FAT]
          add     ax, WORD [reserved_sectors]
          mov     WORD [datasector], ax
          add     WORD [datasector], cx
          
     ; read root directory into memory (7C00:0200)
     
          mov     bx, 0x0200     ; copy root dir above bootcode
          call    read_sectors

     ;----------------------------------------------------
     ; Find stage 2
     ;----------------------------------------------------

     ; browse root directory for binary image
          mov     cx, WORD [root_entries]             ; load loop counter
          mov     di, 0x0200                            ; locate first root entry
     .LOOP:
          push    cx
          mov     cx, 0x000B                            ; eleven character name
          mov     si, ImageName                         ; image name to find
          push    di
     rep  cmpsb                                         ; test for entry match
          pop     di
          je      LOAD_FAT
          pop     cx
          add     di, 0x0020                            ; queue next directory entry
          loop    .LOOP
          jmp     FAILURE

;************************************************;
;	Prints a string
;	DS=>SI: 0 terminated string
;************************************************;
Print:
			lodsb				; load next byte from string from SI to AL
			or	al, al			; Does AL=0?
			jz	PrintDone		; Yep, null terminator found-bail out
			mov	ah, 0eh			; Nope-Print the character
			int	10h
			jmp	Print			; Repeat until null terminator found
	PrintDone:
			ret				; we are done, so return

;************************************************;
; Reads a series of sectors
; CX=>Number of sectors to read
; AX=>Starting sector
; ES:BX=>Buffer to read to
;************************************************;

read_sectors:
     .MAIN:
          mov     di, 0x0005                          ; five retries for error
     .SECTORLOOP:
          push    ax
          push    cx
          call    lba_to_chs                          ; convert starting sector to CHS
          mov     ah, 0x02                            ; BIOS read sector
          mov     al, 0x01                            ; read one sector
          mov     ch, BYTE [absoluteTrack]            ; track
          mov     cl, BYTE [absoluteSector]           ; sector
          mov     dh, BYTE [absoluteHead]             ; head
          mov     dl, BYTE [drive_number]             ; drive
          int     0x13                                ; invoke BIOS
          jnc     .SUCCESS                            ; test for read error

          xor     ax, ax                              ; if failure, reset BIOS disk
          int     0x13

          dec     di                                  ; decrement error counter
          pop     cx
          pop     ax
          jnz     .SECTORLOOP                         ; attempt to read again
          
          int     0x18                                ; interrupt: failure to boot
     .SUCCESS:
          pop     cx
          pop     ax
          add     bx, WORD [bytes_per_sector]        ; queue next buffer
          inc     ax                                  ; queue next sector
          loop    .MAIN                               ; read next sector

          mov     si, msgProgress
          call    Print
          ret

;************************************************;
; Convert CHS to LBA
; LBA = (cluster - 2) * sectors per cluster
;************************************************;

chs_to_lba:
          sub     ax, 0x0002                          ; zero base cluster number
          xor     cx, cx
          mov     cl, BYTE [sectors_per_cluster]     ; convert byte to word
          mul     cx
          add     ax, WORD [datasector]               ; base data sector
          ret
     
;************************************************;
; Convert LBA to CHS
; AX=>LBA Address to convert
;
; absolute sector = (logical sector / sectors per track) + 1
; absolute head   = (logical sector / sectors per track) MOD number of heads
; absolute track  = logical sector / (sectors per track * number of heads)
;
;************************************************;

lba_to_chs:
          xor     dx, dx                              ; prepare dx:ax for operation
          div     WORD [sectors_per_track]           ; calculate
          inc     dl                                  ; adjust for sector 0
          mov     BYTE [absoluteSector], dl
          xor     dx, dx                              ; prepare dx:ax for operation
          div     WORD [heads_per_cylinder]          ; calculate
          mov     BYTE [absoluteHead], dl
          mov     BYTE [absoluteTrack], al
          ret

;----------------------------------------------------
; Load FAT
;----------------------------------------------------

LOAD_FAT:
     
     ; save starting cluster of boot image
          mov     dx, WORD [di + 0x001A]
          mov     WORD [cluster], dx                  ; file's first cluster
          
     ; compute size of FAT and store in "cx"
     
          xor     ax, ax
          mov     al, BYTE [number_of_FATs]          ; number of FATs
          mul     WORD [sectors_per_FAT]             ; sectors used by FATs
          mov     cx, ax

     ; compute location of FAT and store in "ax"

          mov     ax, WORD [reserved_sectors]       ; adjust for bootsector
          
     ; read FAT into memory (7C00:0200)

          mov     bx, 0x0200                          ; copy FAT above bootcode
          call    read_sectors

     ; read image file into memory (0050:0000)
          mov     ax, 0x0050
          mov     es, ax                              ; destination for image
          mov     bx, 0x0000                          ; destination for image
          push    bx

     ;----------------------------------------------------
     ; Load Stage 2
     ;----------------------------------------------------

LOAD_IMAGE:
     
          mov     ax, WORD [cluster]                  ; cluster to read
          pop     bx                                  ; buffer to read into
          call    chs_to_lba                          ; convert cluster to LBA
          xor     cx, cx
          mov     cl, BYTE [sectors_per_cluster]     ; sectors to read
          call    read_sectors
          push    bx
          
     ; compute next cluster
     
          mov     ax, WORD [cluster]                  ; identify current cluster
          mov     cx, ax                              ; copy current cluster
          mov     dx, ax                              ; copy current cluster
          shr     dx, 0x0001                          ; divide by two
          add     cx, dx                              ; sum for (3/2)
          mov     bx, 0x0200                          ; location of FAT in memory
          add     bx, cx                              ; index into FAT
          mov     dx, WORD [bx]                       ; read two bytes from FAT
          test    ax, 0x0001
          jnz     .ODD_CLUSTER
          
     .EVEN_CLUSTER:
     
          and     dx, 0000111111111111b               ; take low twelve bits
          jmp     .DONE
         
     .ODD_CLUSTER:
     
          shr     dx, 0x0004                          ; take high twelve bits
          
     .DONE:
     
          mov     WORD [cluster], dx                  ; store new cluster
          cmp     dx, 0x0FF0                          ; test for end of file
          jb      LOAD_IMAGE
          
     DONE:
     
          mov     si, msgCRLF
          call    Print
          push    WORD 0x0050
          push    WORD 0x0000
          retf
          
     FAILURE:
     
          mov     si, msgFailure
          call    Print
          mov     ah, 0x00
          int     0x16                                ; await keypress
          int     0x19                                ; warm boot computer

     absoluteSector db 0x00
     absoluteHead   db 0x00
     absoluteTrack  db 0x00
     
     datasector  dw 0x0000
     cluster     dw 0x0000
     ImageName   db "KRNLDR  SYS"
     msg_loading db "Loading", 0x00
     msgCRLF     db 0x0D, 0x0A, 0x00
     msgProgress db ".", 0x00
     msgFailure  db 0x0D, 0x0A, "Disk Error", 0x0D, 0x0A, 0x00
     
          TIMES 510-($-$$) DB 0
          DW 0xAA55
