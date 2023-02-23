.data
message:
	.asciz "Hello world!"

.align 4

.text

.global _start
_start:
	bl init

inf_loop:

	// clear the screen
	bl BlankScreen

	// <yourcode>

	// DrawStr(10, 15, "Hello world!");
	mov r0, #10
	mov r1, #15
	ldr r2, =message
	bl DrawStr

	// DrawNum(11, 14, -2147483648);
	mov r0, #11
	mov r1, #14
	ldr r2, =-2147483648
	bl DrawNum

	// DrawNum(12, 13, -69420);
	mov r0, #12
	mov r1, #13
	ldr r2, =-69420
	bl DrawNum

	// DrawNum(13, 12, 0);
	mov r0, #13
	mov r1, #12
	mov r2, #0
	bl DrawNum

	// DrawNum(14, 11, 42069);
	mov r0, #14
	mov r1, #11
	ldr r2, =42069
	bl DrawNum

	// DrawNum(15, 10, 2147483647);
	mov r0, #15
	mov r1, #10
	ldr r2, =2147483647
	bl DrawNum


	// </yourcode>

	b inf_loop // This is an intentional infinite loop!


// Place your implementations for DrawStr and DrawNum here

/*
DrawStr

Draws text into the character buffer

Parameters:
	r0: int x // x-coordinate in character buffer to start drawing the string
	r1: int y // y-coordinate in character buffer to start drawing the string
	r2: char *str // pointer to the null-terminated string to draw
Returns nothing

Pseudocode:
char *destRow = CHARBUF + y << 7; // pointer to the block of memory representing the row to print to
while (x < CHAR_WIDTH && *str != '\0') {
	*(destRow + x) = *str;
	x += 1;
	str += 1;
}
*/
DrawStr:
	// r1: destRow
	lsl r1, r1, #7
	add r1, r1, #CHARBUF

	// r3: *str
	b DrawStr_cond
	DrawStr_loop:
	strb r3, [r1, r0]
	add r0, r0, #1
	add r2, r2, #1

	DrawStr_cond:
	cmp r0, #CHAR_WIDTH
	bhs DrawStr_end
	ldrb r3, [r2]
	cmp r3, #0
	bne DrawStr_loop

	DrawStr_end:
	bx lr
// end DrawStr

/*
DrawNum

Prints a signed number into the character buffer in base-10.

Parameters:
	r0: int x // x-coordinate in character buffer to start drawing the digits
	r1: int y // y-coordinate in character buffer to start drawing the digits
	r2: int num // number to print
Returns nothing

Pseudocode:
// setup
int originalNum = num;
char buffer[12]; // max int is 10 decimal digits, plus two for null terminator and maybe minus sign
int index = 11; // index of the first element in the array
buffer[index] = '\0';

// handle zero possibility
if (num == 0) {
	index -= 1;
	buffer[index] = '0';
} else {
	// handle negative possibility
	if (num < 0) {
		num = -num;
	}

	// extract digits
	int rem;
	// write to the array from right to left
	while (num > 0) {
		(num, rem) = DivTenRem(num);
		index -= 1;
		buffer[index] = toAscii(rem); // i.e. rem + 48
	}
	if (originalNum < 0) {
		index -= 1;
		buffer[index] = '-';
	}
}

// print
DrawStr(x, y, buffer + index);
*/
DrawNum:
	// setup
	push {r4-r7, lr}
	sub sp, sp, #12 // sp: buffer; allocate array of 12 bytes
	mov r4, r0 // r4: x
	mov r5, r1 // r5: y
	mov r6, r2 // r6: originalNum
	mov r7, #11 // r7: index
	mov r0, #0
	strb r0, [sp, r7]
	mov r0, r2 // r0: num

	// handle zero possibility
	cmp r0, #0
	beq DrawNum_isZero

	// handle negative possibility
	bge DrawNum_skipNegative
	rsb r0, r0, #0
	DrawNum_skipNegative:

	// extract digits
	b DrawNum_cond
	DrawNum_loop:
	bl DivTenRem // r0: num, r1: rem
	sub r7, r7, #1
	add r1, r1, #48 // r1: toAscii(rem)
	strb r1, [sp, r7]

	DrawNum_cond:
	cmp r0, #0
	bhi DrawNum_loop

	cmp r6, #0
	bge DrawNum_skipMinusSign
	sub r7, r7, #1
	mov r1, #45 // r1: '-'
	strb r1, [sp, r7]
	DrawNum_skipMinusSign:

	b DrawNum_print

	DrawNum_isZero:
	sub r7, r7, #1
	mov r1, #48 // r1: '0'
	strb r1, [sp, r7]

	// print
	DrawNum_print:
	mov r0, r4
	mov r1, r5
	add r2, sp, r7
	bl DrawStr

	add sp, sp, #12 // deallocate array of 12 bytes
	pop {r4-r7, pc}
// end DrawNum

/*
DivTenRemSmall

Divides an unsigned number by 10, returning its quotient and remainder. Will not work for numbers
larger than about 6.7e8.
Algorithm for dividing by 10 credited to:
Vowels, R. A. (1992). "Division by 10". Australian Computer Journal. 24 (3): 81–85.

Parameters:
	r0: int dividend
Returns:
	r0: int quotient
	r1: int remainder
*/
DivTenRemSmall:
	mov r1, r0 // save the divident for later

	// divide r0 by 10
	add r0, r0, #1
	lsl r0, r0, #1
	add r0, r0, r0, lsl #1
	add r0, r0, r0, lsr #4
	add r0, r0, r0, lsr #8
	add r0, r0, r0, lsr #16
	lsr r0, r0, #6

	// subtract quotient * 10 from the dividend to get remainder
	sub r1, r1, r0, lsl #3 // divident - 8 * quotient
	sub r1, r1, r0, lsl #1 // divident - 8 * quotient - 2 * quotient

	bx lr
// end DivTenRemSmall

/*
DivTenRem

Divides an unsigned number by 10, returning its quotient and remainder. Will work for any unsigned
32-bit number, unlike DivTenRemSmall.

Parameters:
	r0: int dividend
Returns:
	r0: int quotient
	r1: int remainder

Pseudocode:
if (dividend <= 0x10000000) { // 28 bits is safely below the maximum valid input for DivTenRemSmall
	return DivTenRemSmall(dividend);
}
int msn = dividend & 0xf0000000; // "most significant nybble"
int rest = dividend - msn;
msn >>= 4;
(int msnQuot, int msnRem) = DivTenRemSmall(msn);
msnQuot <<= 4;
rest += msnRem << 4;
(int restQuot, int restRem) = DivTenRemSmall(rest);
return (msnQuot + restQuot, restRem);
*/
DivTenRem:
	// r0: dividend
	cmp r0, #0x10000000
	bhi DivTenRem_continue
	push {lr}
	bl DivTenRemSmall
	pop {pc}

	DivTenRem_continue:
	push {r4, r5, lr}
	and r4, r0, #0xf0000000 // r4: msn
	sub r5, r0, r4 // r5: rest
	lsr r0, r4, #4 // r0: msn
	bl DivTenRemSmall // r0: msnQuot, r1: msnRem
	lsl r4, r0, #4 // r4: msnQuot
	add r0, r5, r1, lsl $4 // r0: rest
	bl DivTenRemSmall // r0: restQuot, r1: restRem
	add r0, r0, r4 // r0: msnQuot + restQuot
	pop {r4, r5, pc}
// end DivTenRem

// Feel free to use helpful constants below

// **** DO NOT MODIFY ANYTHING BELOW ****

// 320x240, 1024 bytes/row, 2 bytes per pixel: DE1-SoC
.equ WIDTH, 320
.equ HEIGHT, 240
.equ BUFFER_SIZE, 1024 * 240
.equ LOG2_BYTES_PER_ROW, 10
.equ LOG2_BYTES_PER_PIXEL, 1

.equ CHAR_WIDTH, 80
.equ CHAR_HEIGHT, 60

.equ PIXBUF, 0xc8000000		// Pixel buffer
.equ CHARBUF, 0xc9000000	// Character buffer

init:
	ldr sp, =0x800000	// Initial stack pointer
	bx lr

BlankScreen:
	// Blanks the screen

    ldr r3, =PIXBUF
    mov r2, #0
	mov r0, #0
BlankScreen_Loop:
	mov r1, #0
BlankScreen_RowLoop:
    str r2, [r3, r1]
	add r1, r1, #4
    cmp r1, #640
    blo  BlankScreen_RowLoop
	add r3, r3, #1024
	add r0, r0, #1
	cmp r0, #240
	blo BlankScreen_Loop
    bx lr


DrawPixel:
	// Draws a single pixel at (r0, r1) with color r2
	// r0 - x
	// r1 - y
	// r2 - color
	lsl r1, #LOG2_BYTES_PER_ROW
	lsl r0, #LOG2_BYTES_PER_PIXEL
	add r0, r0, r1
	ldr r1, =PIXBUF
	strh r2, [r1, r0]
	bx lr

DrawStar:
	// Draws a single star at (r0, r1) of size r2
	// r0 - x center
	// r1 - y center
	// r2 - size (1,2)
	push {r4, r5, r6, r7, lr}
	mov r4, r0
	mov r5, r1
	mov r6, r2

	mvn r2, #0
	bl DrawPixel

	cmp r6, #1
	beq DS0

	add r0, r4, #0
	add r1, r5, #1
	mvn r2, #0
	bl DrawPixel

	add r0, r4, #1
	add r1, r5, #0
	mvn r2, #0
	bl DrawPixel

	add r0, r4, #1
	add r1, r5, #1
	mvn r2, #0
	bl DrawPixel

DS0:
	pop {r4, r5, r6, r7, lr}
	bx lr

