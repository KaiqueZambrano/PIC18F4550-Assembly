; TECLADO MATRICIAL E DISPLAY HD44780 (MODO 4 BITS)
; MICROCONTROLADOR PIC18F4550 (ASSEMBLER: GPASM, LINKER: GPLINK)

processor 18f4550
include <p18f4550.inc>

; BITS DE CONFIGURAÇÃO
CONFIG FOSC = HS
CONFIG MCLRE = OFF

; DIRETIVAS DE COMPILAÇÃO
#define _XTAL_FREQ          20000000    ; 20 MHz
#define LCD_FUNCTION_RESET  0x30
#define LCD_FUNCTION_4BIT   0x20
#define LCD_DISPLAY_ON      0x0C
#define LCD_SHIFT_RIGHT     0x06
#define LCD_CLEAR           0x01

ORG 00H
GOTO Start

Start:
  MOVLW 0x0F
  MOVWF TRISB

  MOVLW 0x00
  MOVWF TRISC

  MOVLW 0x00
  MOVWF TRISD

  CALL Display_Open

  MOVLW 'T'
  CALL Display_Envia_Char
  MOVLW 'E'
  CALL Display_Envia_Char
  MOVLW 'C'
  CALL Display_Envia_Char
  MOVLW 'L'
  CALL Display_Envia_Char
  MOVLW 'A'
  CALL Display_Envia_Char
  MOVLW ':'
  CALL Display_Envia_Char
  MOVLW ' '
  CALL Display_Envia_Char

  CALL Main

Wait:
  NOP
  NOP
  NOP
  NOP
  NOP
  NOP
  NOP
  NOP
  NOP
  NOP
  NOP
  NOP
  NOP
  NOP
  NOP
  NOP
  NOP
  NOP
  NOP
  NOP

  RETURN

Debouncing:
  BTFSC PORTB,3
    GOTO Debouncing
  BTFSC PORTB,2
    GOTO Debouncing
  BTFSC PORTB,1
    GOTO Debouncing
  BTFSC PORTB,0
    GOTO Debouncing

  RETURN

Teclado_Varredura:
  BCF PORTB,4
  BCF PORTB,5
  BCF PORTB,6
  BCF PORTB,7

  BSF PORTB,4
    BTFSC PORTB,3
      RETLW '1'
    BTFSC PORTB,2
      RETLW '2'
    BTFSC PORTB,1
      RETLW '3'
    BTFSC PORTB,0
      RETLW 'A'
  BCF PORTB,4

  BSF PORTB,5
    BTFSC PORTB,3
      RETLW '4'
    BTFSC PORTB,2
      RETLW '5'
    BTFSC PORTB,1
      RETLW '6'
    BTFSC PORTB,0
      RETLW 'B'
  BCF PORTB,5

  BSF PORTB,6
    BTFSC PORTB,3
      RETLW '7'
    BTFSC PORTB,2
      RETLW '8'
    BTFSC PORTB,1
      RETLW '9'
    BTFSC PORTB,0
      RETLW 'C'
  BCF PORTB,6

  BSF PORTB,7
    BTFSC PORTB,3
      RETLW '*'
    BTFSC PORTB,2
      RETLW '0'
    BTFSC PORTB,1
      RETLW '#'
    BTFSC PORTB,0
      RETLW 'F'
  BCF PORTB,7

  RETLW 0

Display_Envia_Nibble:
  BTFSC WREG,7
    BSF PORTD,7
  BTFSS WREG,7
    BCF PORTD,7

  BTFSC WREG,6
    BSF PORTD,6
  BTFSS WREG,6
    BCF PORTD,6

  BTFSC WREG,5
    BSF PORTD,5
  BTFSS WREG,5
    BCF PORTD,5

  BTFSC WREG,4
    BSF PORTD,4
  BTFSS WREG,4
    BCF PORTD,4

  BSF PORTC,1
  CALL Wait
  BCF PORTC,1

  RETURN

Display_Envia_Byte:
  CALL Display_Envia_Nibble
  SWAPF WREG
  CALL Display_Envia_Nibble

  RETURN

Display_Envia_Cmd:
  BCF PORTC,0
  CALL Display_Envia_Byte

  RETURN

Display_Envia_Char:
  BSF PORTC,0
  CALL Display_Envia_Byte

  RETURN

Display_Open:
  MOVLW LCD_FUNCTION_RESET
  CALL Display_Envia_Nibble

  MOVLW LCD_FUNCTION_RESET
  CALL Display_Envia_Nibble

  MOVLW LCD_FUNCTION_RESET
  CALL Display_Envia_Nibble

  MOVLW LCD_FUNCTION_4BIT
  CALL Display_Envia_Nibble

  MOVLW LCD_DISPLAY_ON
  CALL Display_Envia_Cmd

  MOVLW LCD_CLEAR
  CALL Display_Envia_Cmd

  RETURN

Main:
  CALL Teclado_Varredura
  CPFSEQ 0
    CALL Display_Envia_Char
  CALL Debouncing

  GOTO Main

END
