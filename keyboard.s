.data

// PS/2 keyboard FIFO buffer address
.EQU REG_KEYBOARD_FIFO, 0xff200108

/*
struct KeyState {
	changed: bit,
	pressed: bit,
}
// each KeyState is one byte
*/
.EQU KEYBOARDSTATE_INDEXOF_ESC, 0
.EQU KEYBOARDSTATE_INDEXOF_SPACE, 1
.EQU KEYBOARDSTATE_INDEXOF_ONE, 2
.EQU KEYBOARDSTATE_INDEXOF_TWO, 3
.EQU KEYBOARDSTATE_INDEXOF_W, 4
.EQU KEYBOARDSTATE_INDEXOF_A, 5
.EQU KEYBOARDSTATE_INDEXOF_S, 6
.EQU KEYBOARDSTATE_INDEXOF_D, 7
.EQU KEYBOARDSTATE_SIZE, 8
.align 1 // aligned because of a strh instruction in updateKeyboardState
	.byte 0x1 // make flag; see updateKeyboardState
	.byte 0x0 // extended flag; seeUpdateKeyboardState
keyboardState:
	.skip KEYBOARDSTATE_SIZE

.text

/*
updateKeyboardState: updates the keyboardState struct to reflect the current state of the keyboard.
Cannot handle pause key.

updateKeyboardState() {
	let static mut extended = false;
	let static mut make = true; // assume it's a make scan code unless a break code is encountered
	for keyState in keyboardState {
		keyState.changed = false;
	}
	while REG_KEYBOARD_FIFO.bufferSize > 0 {
		let scanCode = REG_KEYBOARD_FIFO.nextScanCode();
		match scanCode {
			0xf0 => make = false,
			0xe0 => extended = true,
			scanCode => {
				let keyIndex = if extended {
					match code {
						_ => goto resetFlags;
					}
				} else {
					match code {
						0x16 => KEYBOARDSTATE_INDEXOF_ONE,
						0x1e => KEYBOARDSTATE_INDEXOF_TWO,
						0x29 => KEYBOARDSTATE_INDEXOF_SPACE,
						0x76 => KEYBOARDSTATE_INDEXOF_ESC,
						0x1d => KEYBOARDSTATE_INDEXOF_W,
						0x1c => KEYBOARDSTATE_INDEXOF_A,
						0x1b => KEYBOARDSTATE_INDEXOF_S,
						0x23 => KEYBOARDSTATE_INDEXOF_D,
						_ => goto resetFlags;
					}
				};
				keyboardState[keyIndex].changed = keyboardState[offset].pressed != make;
				keyboardState[keyIndex].pressed = make;
				resetFlags:
				make = true;
				extended = false;
			},
		}
	}
}
*/
updateKeyboardState:
	push {r4}

	// r0's usage is quite volatile

	// r1 = keyboardState
	ldr r1, =keyboardState

	// iterate over keyState
	mov r2, #KEYBOARDSTATE_SIZE
	b updateKeyboardState_clearChangedCond
updateKeyboardState_clearChangedBody:

	// keyboardState[r2].changed = false;
	ldrb r0, [r1, r2]
	bic r0, r0, #2
	strb r0, [r1, r2]

updateKeyboardState_clearChangedCond:
	subs r2, r2, #1
	bge updateKeyboardState_clearChangedBody

	// r2 = REG_KEYBOARD_FIFO
	ldr r2, =REG_KEYBOARD_FIFO

	b updateKeyboardState_processCodesCond
updateKeyboardState_processCodesBody:

	// r3 = scanCode
	ldrb r3, [r2]

	// outer match statement
	cmp r3, #0xf0
	beq updateKeyboardState_codeBreak
	cmp r3, #0xe0
	beq updateKeyboardState_codeExtended

	// r3 = keyIndex
	ldrb r0, [r1, #-1]
	cmp r0, #0
	bne updateKeyboardState_checkExtendedCodes
	cmp r3, #0x29
	moveq r3, #KEYBOARDSTATE_INDEXOF_SPACE
	beq updateKeyboardState_keyIndexFound
	cmp r3, #0x76
	moveq r3, #KEYBOARDSTATE_INDEXOF_ESC
	beq updateKeyboardState_keyIndexFound
	cmp r3, #0x16
	moveq r3, #KEYBOARDSTATE_INDEXOF_ONE
	beq updateKeyboardState_keyIndexFound
	cmp r3, #0x1e
	moveq r3, #KEYBOARDSTATE_INDEXOF_TWO
	beq updateKeyboardState_keyIndexFound
	cmp r3, #0x1d
	moveq r3, #KEYBOARDSTATE_INDEXOF_W
	beq updateKeyboardState_keyIndexFound
	cmp r3, #0x1c
	moveq r3, #KEYBOARDSTATE_INDEXOF_A
	beq updateKeyboardState_keyIndexFound
	cmp r3, #0x1b
	moveq r3, #KEYBOARDSTATE_INDEXOF_S
	beq updateKeyboardState_keyIndexFound
	cmp r3, #0x23
	moveq r3, #KEYBOARDSTATE_INDEXOF_D
	beq updateKeyboardState_keyIndexFound
	b updateKeyboardState_resetFlags
updateKeyboardState_checkExtendedCodes:
	b updateKeyboardState_resetFlags
updateKeyboardState_keyIndexFound:

	// r4 = keyboardState[keyIndex]
	ldrb r4, [r1, r3]
	ldrb r0, [r1, #-2]
	add r4, r4, r0
	add r4, r0, r4, lsl #1
	and r4, r4, #0x3 // keep only the last two bits
	strb r4, [r1, r3]

updateKeyboardState_resetFlags:
	mov r0, #1 // hword representing both make and extended flags
	strh r0, [r1, #-2]

	b updateKeyboardState_processCodesCond
updateKeyboardState_codeBreak:

	// make = false
	mov r0, #0
	strb r0, [r1, #-2]

	b updateKeyboardState_processCodesCond
updateKeyboardState_codeExtended:

	// extended = true
	mov r0, #1
	strb r0, [r1, #-1]

updateKeyboardState_processCodesCond:
	// r3 = bufferSize
	ldrb r3, [r2, #2]
	cmp r3, #0
	bne updateKeyboardState_processCodesBody

	pop {r4}
	bx lr
// end updateKeyboardState