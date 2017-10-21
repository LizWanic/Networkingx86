all:
	nasm -f elf32 -g assn5.asm
	gcc -g -o assn5 -m32 assn5.o dns.o lib4.o


clean:
	
	rm -f assn5 
