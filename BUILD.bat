
nasm -f bin Boot\boot.asm -o Boot\boot.bin

imdisk -a -f Boot\boot.bin -s 1440K -m A: -o fd,awe

copy Kernel\KRNLDR.SYS A:\

pause
