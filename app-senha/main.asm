; MICROCONTROLADOR PIC18F4550 (ASSEMBLER: GPASM, LINKER: GPLINK)
; ----------------------------------------------------------------------------------------------------------
PROCESSOR 18F4550
INCLUDE <P18F4550.INC>

; BITS DE CONFIGURAÇÃO
; ----------------------------------------------------------------------------------------------------------
CONFIG FOSC   = HS                                    ; oscilador externo HS
CONFIG PBADEN = OFF                                   ; porta B é inteiramente digital
CONFIG MCLRE  = OFF                                   ; master clear desligado (RE3 = entrada)
CONFIG LVP    = OFF                                   ; modo LVP desligado (voltagem regular)
CONFIG WDT    = OFF                                   ; não resetar após timeout do watchdog

; DIRETIVAS DE COMPILAÇÃO
; ----------------------------------------------------------------------------------------------------------
#DEFINE _XTAL_FREQ    20000000                        ; frequência do cristal 20 MHz

#DEFINE LCD_FN_SET_4B 0x28                            ; cmd para setar LCD em modo 4 bits
#DEFINE LCD_CURSOR_ON 0x0E                            ; cmd para ligar cursor do LCD
#DEFINE LCD_CLEAR     0x01                            ; cmd para limpar tela do LCD

; ENDEREÇAMENTO DAS VARIÁVEIS
; ----------------------------------------------------------------------------------------------------------

; A interrupção desvia a busca de instruções para uma região específica da memória (rotina ISR)
; Assim sendo, faz-se necessário o backup de alguns registradores para um retorno previsível às operações
; **********************************************************************************************************

CBLOCK 0x20
  TEMP_W                                              ; registrador WREG (armazena valores para trabalho)
  TEMP_STATUS                                         ; registrador STATUS (últimos cálculos do processador)
  TEMP_BSR                                            ; registrador BSR (banco de memória selecionado)
ENDC

; Dados essenciais para a lógica do programa
; **********************************************************************************************************

CBLOCK 0x30
  TEMPO                                               ; limite de 20 segundos para inserir a senha
  CONTADOR_TEMPO                                      ; 10 interrupções * 100 ms = 1 segundo
  CHAR                                                ; caractér salvo após pressionamento dos botões
  CONTADOR_CHAR                                       ; digitos da senha (7 é o limite)
  TMP                                                 ; espaço genérico reservado para a lógica
ENDC

CBLOCK 0x40
  NUM                                                 ; número genérico para divisão e multiplicação
  NUM2                                                ; número genérico para multiplicação
  DIV                                                 ; denominador
  QUO                                                 ; quociente (NUM/DIV = QUO)
  PRODT1                                              ; guarda o MSB do produto (NUM * NUM2)
  PRODT0                                              ; guarda o LSB do produto (carry)
ENDC

CBLOCK 0x50                                           ; dezena e unidade (para conversão e exibição no LCD)
  DEZ
  UNI
ENDC

CBLOCK 0x60                                           ; caractéres da senha
  CHR1
  CHR2
  CHR3
  CHR4
  CHR5
  CHR6
  CHR7
ENDC

CBLOCK 0x70                                           ; senha correta
  SC1
  SC2
  SC3
  SC4
  SC5
  SC6
  SC7
ENDC

CBLOCK 0x80                                           ; contadores para delay
  CONTADOR1
  CONTADOR2
  CONTADOR3
ENDC

; ENDEREÇAMENTO PARA BUSCA DE INSTRUÇÕES
; ----------------------------------------------------------------------------------------------------------
ORG 0x0000                                            ; endereço inicial (MCLRE reseta pra cá)
GOTO START                                            ; rotina do programa principal
ORG 0x0008                                            ; redirecionamento por interrupção de alta prioridade
GOTO ISR_ALTO
ORG 0x0018                                            ; redirecionamento por interrupção de baixa prioridade
GOTO ISR_BAIXO

; ROTINA DE EXECUÇÃO DO PROGRAMA PRINCIPAL
; ----------------------------------------------------------------------------------------------------------
START:
  ; Configuração do pino RB (teclado matricial, pull up interno habilitado)
  BANKSEL TRISB
  MOVLW 0xF0
  MOVWF TRISB

  BANKSEL INTCON2
  BCF INTCON2,RBPU

  ; Configuração do pino RD (dados do LCD)
  BANKSEL TRISD
  MOVLW 0x00
  MOVWF TRISD

  ; Configuração do pino RE (RS e ENABLE do LCD)
  BANKSEL TRISE
  BCF TRISE,0                                         ; RD0 = RS
  BCF TRISE,1                                         ; RD1 = ENABLE

  ; Garantindo que todos os pinos são digitais
  BANKSEL ADCON1
  BSF ADCON1,PCFG3                                     ; <PCFG3:PCFG0 = 1111 = TUDO DIGITAL
  BSF ADCON1,PCFG2
  BSF ADCON1,PCFG1
  BSF ADCON1,PCFG0

; Configura o contador
; **********************************************************************************************************

CONFIGURAR_CONTADOR:
  BANKSEL T0CON
  BCF T0CON,T08BIT                                     ; contador 16 bits
  BCF T0CON,T0CS                                       ; fonte: HS
  BCF T0CON,PSA                                        ; com prescaler
  BSF T0CON,T0PS2                                      ; valor prescale
  BSF T0CON,T0PS1
  BSF T0CON,T0PS0

  BANKSEL TMR0H
  MOVLW 0xF8
  MOVWF TMR0H

  BANKSEL TMR0L
  MOVLW 0x5F
  MOVWF TMR0L

; Carrega os dados iniciais (20 segundos, 10 interrupções, 1 caractér, senha correta)
; **********************************************************************************************************

CARREGAR_VAR:
  BANKSEL 0x30
  MOVLW D'20'
  MOVWF TEMPO
  MOVLW D'10'
  MOVWF CONTADOR_TEMPO
  CLRF CHAR
  MOVLW D'1'
  MOVWF CONTADOR_CHAR

  BANKSEL 0x60
  CLRF CHR1
  CLRF CHR2
  CLRF CHR3
  CLRF CHR4
  CLRF CHR5
  CLRF CHR6
  CLRF CHR7

  BANKSEL 0x70
  MOVLW '2'
  MOVWF SC1
  MOVLW '3'
  MOVWF SC2
  MOVLW '1'
  MOVWF SC3
  MOVLW '3'
  MOVWF SC4
  MOVLW '0'
  MOVWF SC5
  MOVLW '7'
  MOVWF SC6
  MOVLW '3'
  MOVWF SC7

; Configura interrupções (seta prioridades, chave global/periféricos, flags e bit enable)
; **********************************************************************************************************

CONFIGURAR_INT:
  BANKSEL RCON
  BSF RCON,IPEN

  BANKSEL INTCON2
  BCF INTCON2,RBIP
  BSF INTCON2,TMR0IP

  BANKSEL INTCON
  BSF INTCON,GIEH
  BSF INTCON,GIEL
  BCF INTCON,RBIF
  BSF INTCON,RBIE
  BCF INTCON,TMR0IF

  BANKSEL T0CON
  BCF T0CON,TMR0ON

  BANKSEL INTCON
  BSF INTCON,TMR0IE

; Inicializa LCD
; **********************************************************************************************************

INICIALIZAR_LCD:
  MOVLW 0x30                                           ; inicializa em 8 bits
  CALL LCD_ENVIA_NIBBLE                                ; nibble = LSB = 0011 = 0x3
  MOVLW 0x30
  CALL LCD_ENVIA_NIBBLE
  MOVLW 0x30
  CALL LCD_ENVIA_NIBBLE

  MOVLW 0x20                                           ; muda pra 4 bits
  CALL LCD_ENVIA_NIBBLE

  MOVLW LCD_FN_SET_4B                                  ; 2 linhas, char 5x7
  CALL LCD_ENVIA_CMD

  MOVLW LCD_CURSOR_ON
  CALL LCD_ENVIA_CMD

; Exibe a tela inicial ("TECLE P/ INICIAR")
; **********************************************************************************************************

TELA_INICIAL:
  MOVLW LCD_CLEAR
  CALL LCD_ENVIA_CMD

  MOVLW 'T'
  CALL LCD_ENVIA_CHAR
  MOVLW 'E'
  CALL LCD_ENVIA_CHAR
  MOVLW 'C'
  CALL LCD_ENVIA_CHAR
  MOVLW 'L'
  CALL LCD_ENVIA_CHAR
  MOVLW 'E'
  CALL LCD_ENVIA_CHAR
  MOVLW ' '
  CALL LCD_ENVIA_CHAR
  MOVLW 'P'
  CALL LCD_ENVIA_CHAR
  MOVLW '/'
  CALL LCD_ENVIA_CHAR
  MOVLW ' '
  CALL LCD_ENVIA_CHAR
  MOVLW 'I'
  CALL LCD_ENVIA_CHAR
  MOVLW 'N'
  CALL LCD_ENVIA_CHAR
  MOVLW 'I'
  CALL LCD_ENVIA_CHAR
  MOVLW 'C'
  CALL LCD_ENVIA_CHAR
  MOVLW 'I'
  CALL LCD_ENVIA_CHAR
  MOVLW 'O'
  CALL LCD_ENVIA_CHAR
  MOVLW ' '
  CALL LCD_ENVIA_CHAR

; Loop de execução do programa (lógica de varredura)
; **********************************************************************************************************

LOOP_MAIN:
  ; Desliga colunas
  BANKSEL PORTB
  BSF PORTB,0
  BSF PORTB,1
  BSF PORTB,2
  BSF PORTB,3

  ; Pulsa linha coluna 0
  BCF PORTB,0
  NOP
  NOP
  NOP
  NOP
  NOP
  BSF PORTB,0

  ; Pulsa linha coluna 1
  BCF PORTB,1
  NOP
  NOP
  NOP
  NOP
  NOP
  BSF PORTB,1

  ; Pulsa linha coluna 2
  BCF PORTB,2
  NOP
  NOP
  NOP
  NOP
  NOP
  BSF PORTB,2

  ; Pulsa linha coluna 3
  BCF PORTB,3
  NOP
  NOP
  NOP
  NOP
  NOP
  BSF PORTB,3

  GOTO LOOP_MAIN

; ROTINA DE INTERRUPÇÃO DE ALTA PRIORIDADE (TIMER 0)
; ----------------------------------------------------------------------------------------------------------
ISR_ALTO:
  BANKSEL 0x20
  MOVFF WREG,TEMP_W
  MOVFF STATUS,TEMP_STATUS
  MOVFF BSR,TEMP_BSR

INT_TMR0:
  ; Limpa flag
  BANKSEL INTCON
  BCF INTCON,TMR0IF

  ; Redefine a carga (MSB)
  BANKSEL TMR0H
  MOVLW 0xF8
  MOVWF TMR0H

  ; Redefine a carga (LSB)
  BANKSEL TMR0L
  MOVLW 0x5F
  MOVWF TMR0L

  ; O objetivo é dividir o TEMPO por 10 pra pegar a dezena (um número de 0 até 9): DIV = 10
  BANKSEL 0x40
  MOVLW D'10'
  MOVWF DIV

  ; Assim sendo: NUM = TEMPO, QUO = NUM/DIV, DEZ = QUO
  BANKSEL 0x30
  MOVF TEMPO,W
  BANKSEL 0x40
  MOVWF NUM
  CALL DIVIDIR
  MOVF QUO,W
  BANKSEL 0x50
  MOVWF DEZ

  ; Para pegar a unidade, multiplica o QUO por 10: NUM = 10, NUM2 = QUO, PRODT0 = NUM*NUM2
  BANKSEL 0x40
  MOVLW D'10'
  MOVWF NUM
  MOVFF QUO,NUM2
  CALL MULTIPLICAR
  MOVF PRODT0,W

  ; E em seguida subtrai o PRODT0 de TEMPO, pegando assim a unidade
  BANKSEL 0x30
  SUBWF TEMPO,W
  BANKSEL 0x50
  MOVWF UNI

  ; Como 0x30 = '0' e 0x39 = '9', para converter para ASCII, basta somar 0x30 ao algarismo
  MOVLW 0x30
  ADDWF DEZ,F
  ADDWF UNI,F

  ; Muda pra coluna 6 da linha 2
  MOVLW 0xC6
  CALL LCD_ENVIA_CMD

  ; Envia caractér dezena pro display
  BANKSEL 0x50
  MOVF DEZ,W
  CALL LCD_ENVIA_CHAR

  ; Envia caractér unidade pro display
  BANKSEL 0x50
  MOVF UNI,W
  CALL LCD_ENVIA_CHAR

  ; Decrementa o contador, se zero reseta pra 10 e decrementa o tempo, se o tempo é zero TIMEOUT
  BANKSEL 0x30
  DECFSZ CONTADOR_TEMPO,F
    GOTO VERIFICA_SENHA
  MOVLW D'10'
  MOVWF CONTADOR_TEMPO
  DCFSNZ TEMPO,F
    GOTO TIMEOUT

; Caso o contador não é zero, desvia as instruções para verificar a senha
; **********************************************************************************************************

VERIFICA_SENHA:
  ; Se maior que 7, começa a testar cada caractér da senha, se não, desvia pro fim da interrupção
  BANKSEL 0x30
  MOVLW D'7'
  CPFSGT CONTADOR_CHAR
    GOTO FIM_ISR_ALTO

TESTAR_CHR:
  BANKSEL 0x70
  MOVF SC1,W
  BANKSEL 0x60
  CPFSEQ CHR1
    GOTO TIMEOUT

  BANKSEL 0x70
  MOVF SC2,W
  BANKSEL 0x60
  CPFSEQ CHR2
    GOTO TIMEOUT

  BANKSEL 0x70
  MOVF SC3,W
  BANKSEL 0x60
  CPFSEQ CHR3
    GOTO TIMEOUT

  BANKSEL 0x70
  MOVF SC4,W
  BANKSEL 0x60
  CPFSEQ CHR4
    GOTO TIMEOUT

  BANKSEL 0x70
  MOVF SC5,W
  BANKSEL 0x60
  CPFSEQ CHR5
    GOTO TIMEOUT

  BANKSEL 0x70
  MOVF SC6,W
  BANKSEL 0x60
  CPFSEQ CHR6
    GOTO TIMEOUT

  BANKSEL 0x70
  MOVF SC7,W
  BANKSEL 0x60
  CPFSEQ CHR7
    GOTO TIMEOUT

  ; Desliga timer: a senha está correta
  BANKSEL T0CON
  BCF T0CON,TMR0ON

  ; Redefine os valores das variáveis
  BANKSEL 0x30
  MOVLW D'20'
  MOVWF TEMPO
  CLRF CHAR
  MOVLW D'10'
  MOVWF CONTADOR_TEMPO
  MOVLW D'1'
  MOVWF CONTADOR_CHAR

  ; Limpa os caractéres salvos
  BANKSEL 0x60
  CLRF CHR1
  CLRF CHR2
  CLRF CHR3
  CLRF CHR4
  CLRF CHR5
  CLRF CHR6
  CLRF CHR7

  ; Exibe: "SENHA CORRETA!"
  MOVLW LCD_CLEAR
  CALL LCD_ENVIA_CMD
  MOVLW 'S'
  CALL LCD_ENVIA_CHAR
  MOVLW 'E'
  CALL LCD_ENVIA_CHAR
  MOVLW 'N'
  CALL LCD_ENVIA_CHAR
  MOVLW 'H'
  CALL LCD_ENVIA_CHAR
  MOVLW 'A'
  CALL LCD_ENVIA_CHAR
  MOVLW ' '
  CALL LCD_ENVIA_CHAR
  MOVLW 'C'
  CALL LCD_ENVIA_CHAR
  MOVLW 'O'
  CALL LCD_ENVIA_CHAR
  MOVLW 'R'
  CALL LCD_ENVIA_CHAR
  MOVLW 'R'
  CALL LCD_ENVIA_CHAR
  MOVLW 'E'
  CALL LCD_ENVIA_CHAR
  MOVLW 'T'
  CALL LCD_ENVIA_CHAR
  MOVLW 'A'
  CALL LCD_ENVIA_CHAR
  MOVLW '!'
  CALL LCD_ENVIA_CHAR
  MOVLW ' '
  CALL LCD_ENVIA_CHAR
  MOVLW ' '
  CALL LCD_ENVIA_CHAR

  ; Delay de 1 segundo
  CALL DELAY_100MS
  CALL DELAY_100MS
  CALL DELAY_100MS
  CALL DELAY_100MS
  CALL DELAY_100MS
  CALL DELAY_100MS
  CALL DELAY_100MS
  CALL DELAY_100MS
  CALL DELAY_100MS
  CALL DELAY_100MS

  GOTO FIM_ISR_ALTO

; Desvio caso o tempo excedido ou senha incorreta
; **********************************************************************************************************

TIMEOUT:
  ; Desliga temporizador
  BANKSEL T0CON
  BCF T0CON,TMR0ON

  ; Redefine os valores das variáveis
  BANKSEL 0x30
  MOVLW D'20'
  MOVWF TEMPO
  CLRF CHAR
  MOVLW D'10'
  MOVWF CONTADOR_TEMPO
  MOVLW D'1'
  MOVWF CONTADOR_CHAR

  ; Limpa os caractéres salvos
  BANKSEL 0x60
  CLRF CHR1
  CLRF CHR2
  CLRF CHR3
  CLRF CHR4
  CLRF CHR5
  CLRF CHR6
  CLRF CHR7

  ; Exibe "SENHA INCORRETA!"
  MOVLW LCD_CLEAR
  CALL LCD_ENVIA_CMD
  MOVLW 'S'
  CALL LCD_ENVIA_CHAR
  MOVLW 'E'
  CALL LCD_ENVIA_CHAR
  MOVLW 'N'
  CALL LCD_ENVIA_CHAR
  MOVLW 'H'
  CALL LCD_ENVIA_CHAR
  MOVLW 'A'
  CALL LCD_ENVIA_CHAR
  MOVLW ' '
  CALL LCD_ENVIA_CHAR
  MOVLW 'I'
  CALL LCD_ENVIA_CHAR
  MOVLW 'N'
  CALL LCD_ENVIA_CHAR
  MOVLW 'C'
  CALL LCD_ENVIA_CHAR
  MOVLW 'O'
  CALL LCD_ENVIA_CHAR
  MOVLW 'R'
  CALL LCD_ENVIA_CHAR
  MOVLW 'R'
  CALL LCD_ENVIA_CHAR
  MOVLW 'E'
  CALL LCD_ENVIA_CHAR
  MOVLW 'T'
  CALL LCD_ENVIA_CHAR
  MOVLW 'A'
  CALL LCD_ENVIA_CHAR
  MOVLW '!'
  CALL LCD_ENVIA_CHAR

  ; Delay de 1 segundo
  CALL DELAY_100MS
  CALL DELAY_100MS
  CALL DELAY_100MS
  CALL DELAY_100MS
  CALL DELAY_100MS
  CALL DELAY_100MS
  CALL DELAY_100MS
  CALL DELAY_100MS
  CALL DELAY_100MS
  CALL DELAY_100MS

; Diretiva indicando as instruções para finalizar a interrupção
; **********************************************************************************************************

FIM_ISR_ALTO:
  BANKSEL 0x20
  MOVFF TEMP_BSR,BSR
  MOVFF TEMP_STATUS,STATUS
  MOVFF TEMP_W,WREG
  RETFIE FAST

; ROTINA DE INTERRUPÇÃO DE BAIXA PRIORIDADE (MUDANÇA DE ESTADO EM RB<4-7>)
; ----------------------------------------------------------------------------------------------------------
ISR_BAIXO:
  BANKSEL 0x20
  MOVFF WREG,TEMP_W
  MOVFF STATUS,TEMP_STATUS
  MOVFF BSR,TEMP_BSR

  ; Limpa flag e verifica o timer: se não estiver ligado, desvia as instruções pra mostrar a tela de senha
  BANKSEL INTCON
  BCF INTCON,RBIF
  BANKSEL T0CON
  BTFSS T0CON,TMR0ON
    GOTO MOSTRAR_TELA_SENHA
  GOTO INT_TECLADO

; Mostra a tela de senha
; **********************************************************************************************************

MOSTRAR_TELA_SENHA:
  BANKSEL PORTB
  BTFSS PORTB,4
    GOTO MOSTRAR_TELA_SENHA
  BTFSS PORTB,5
    GOTO MOSTRAR_TELA_SENHA
  BTFSS PORTB,6
    GOTO MOSTRAR_TELA_SENHA
  BTFSS PORTB,7
    GOTO MOSTRAR_TELA_SENHA

  BANKSEL T0CON
  BSF T0CON,TMR0ON

  MOVLW 0x01
  CALL LCD_ENVIA_CMD
  MOVLW 0x80
  CALL LCD_ENVIA_CMD
  MOVLW 'S'
  CALL LCD_ENVIA_CHAR
  MOVLW 'E'
  CALL LCD_ENVIA_CHAR
  MOVLW 'N'
  CALL LCD_ENVIA_CHAR
  MOVLW 'H'
  CALL LCD_ENVIA_CHAR
  MOVLW 'A'
  CALL LCD_ENVIA_CHAR
  MOVLW ':'
  CALL LCD_ENVIA_CHAR

  MOVLW 0xC0
  CALL LCD_ENVIA_CMD
  MOVLW 'T'
  CALL LCD_ENVIA_CHAR
  MOVLW 'E'
  CALL LCD_ENVIA_CHAR
  MOVLW 'M'
  CALL LCD_ENVIA_CHAR
  MOVLW 'P'
  CALL LCD_ENVIA_CHAR
  MOVLW 'O'
  CALL LCD_ENVIA_CHAR
  MOVLW ':'
  CALL LCD_ENVIA_CHAR

; Interrupção pelo teclado (RB<4-7>)
; **********************************************************************************************************

INT_TECLADO:
  ; Muda posição do cursor para coluna 6 da linha 1, salva um caractér nulo ' ', para teste lógico
  MOVLW 0x86
  CALL LCD_ENVIA_CMD
  MOVLW ' '

; Começa verificando RB4 ...
; **********************************************************************************************************

INT_RB4:
  ; Se não foi a porta que causou a interrupção, desvia pra próxima verificação
  BANKSEL PORTB
  BTFSC PORTB,4
    GOTO INT_RB5

  ; Se foi a porta, verifica as colunas e salva o caractér correspondente
  BTFSS PORTB,0
    MOVLW '1'
  BTFSS PORTB,1
    MOVLW '2'
  BTFSS PORTB,2
    MOVLW '3'
  BTFSS PORTB,3
    MOVLW 'A'

  ; Debouncing (prende as instruções até que o usuário solte o dedo do botão)
  BTFSS PORTB,4
    GOTO INT_RB4

; Verifica RB5
; **********************************************************************************************************

INT_RB5:
  BANKSEL PORTB
  BTFSC PORTB,5
    GOTO INT_RB6

  BTFSS PORTB,0
    MOVLW '4'
  BTFSS PORTB,1
    MOVLW '5'
  BTFSS PORTB,2
    MOVLW '6'
  BTFSS PORTB,3
    MOVLW 'B'

  BTFSS PORTB,5
    GOTO INT_RB5

; Verifica RB6
; **********************************************************************************************************

INT_RB6:
  BANKSEL PORTB
  BTFSC PORTB,6
    GOTO INT_RB7

  BTFSS PORTB,0
    MOVLW '7'
  BTFSS PORTB,1
    MOVLW '8'
  BTFSS PORTB,2
    MOVLW '9'
  BTFSS PORTB,3
    MOVLW 'C'

  BTFSS PORTB,6
    GOTO INT_RB6

; Verifica RB7
; **********************************************************************************************************

INT_RB7:
  BANKSEL PORTB
  BTFSC PORTB,7
    GOTO TESTA_CHAR

  BTFSS PORTB,0
    MOVLW 'F'
  BTFSS PORTB,1
    MOVLW '0'
  BTFSS PORTB,2
    MOVLW 'E'
  BTFSS PORTB,3
    MOVLW 'D'

  BTFSS PORTB,7
    GOTO INT_RB7

; Faz um teste, pra verificar se a entrada é válida (já que a interrupção provém da mudança em RB<4-7>)
; **********************************************************************************************************

TESTA_CHAR:
  ; Se o caractér nulo é inválido, procede, se não, desvia as instruções pro fim
  BANKSEL 0x30
  MOVFF WREG,TMP
  MOVLW ' '
  CPFSEQ TMP
    GOTO TESTA_CONTADOR
  GOTO FIM_ISR_BAIXO

; Testa qual caractér da senha o usuário está inserindo (se contador igual a 8, excedeu o limite)
; **********************************************************************************************************

TESTA_CONTADOR:
  MOVF TMP,W
  MOVWF CHAR
  CALL LCD_ENVIA_CHAR
  BANKSEL 0x30
  MOVLW D'8'
  CPFSEQ CONTADOR_CHAR
    GOTO INSERE_CHR1
  GOTO FIM_ISR_BAIXO

; Insere CHR1
; **********************************************************************************************************

INSERE_CHR1:
  BANKSEL 0x30
  MOVLW D'1'
  CPFSEQ CONTADOR_CHAR
    GOTO INSERE_CHR2
  MOVF CHAR,W

  BANKSEL 0x60
  MOVWF CHR1
  BANKSEL 0x30
  INCF CONTADOR_CHAR,0
  MOVWF CONTADOR_CHAR
  GOTO FIM_ISR_BAIXO

; Insere CHR2
; **********************************************************************************************************

INSERE_CHR2:
  BANKSEL 0x30
  MOVLW D'2'
  CPFSEQ CONTADOR_CHAR
    GOTO INSERE_CHR3
  MOVF CHAR,W

  BANKSEL 0x60
  MOVWF CHR2
  BANKSEL 0x30
  INCF CONTADOR_CHAR,0
  MOVWF CONTADOR_CHAR
  GOTO FIM_ISR_BAIXO

; Insere CHR3
; **********************************************************************************************************

INSERE_CHR3:
  BANKSEL 0x30
  MOVLW D'3'
  CPFSEQ CONTADOR_CHAR
    GOTO INSERE_CHR4
  MOVF CHAR,W

  BANKSEL 0x60
  MOVWF CHR3
  BANKSEL 0x30
  INCF CONTADOR_CHAR,0
  MOVWF CONTADOR_CHAR
  GOTO FIM_ISR_BAIXO

; Insere CHR4
; **********************************************************************************************************

INSERE_CHR4:
  BANKSEL 0x30
  MOVLW D'4'
  CPFSEQ CONTADOR_CHAR
    GOTO INSERE_CHR5
  MOVF CHAR,W

  BANKSEL 0x60
  MOVWF CHR4
  BANKSEL 0x30
  INCF CONTADOR_CHAR,0
  MOVWF CONTADOR_CHAR
  GOTO FIM_ISR_BAIXO

; Insere CHR5
; **********************************************************************************************************

INSERE_CHR5:
  BANKSEL 0x30
  MOVLW D'5'
  CPFSEQ CONTADOR_CHAR
    GOTO INSERE_CHR6
  MOVF CHAR,W

  BANKSEL 0x60
  MOVWF CHR5
  BANKSEL 0x30
  INCF CONTADOR_CHAR,0
  MOVWF CONTADOR_CHAR
  GOTO FIM_ISR_BAIXO

; Insere CHR6
; **********************************************************************************************************

INSERE_CHR6:
  BANKSEL 0x30
  MOVLW D'6'
  CPFSEQ CONTADOR_CHAR
    GOTO INSERE_CHR7
  MOVF CHAR,W

  BANKSEL 0x60
  MOVWF CHR6
  BANKSEL 0x30
  INCF CONTADOR_CHAR,0
  MOVWF CONTADOR_CHAR
  GOTO FIM_ISR_BAIXO

; Insere CHR7
; **********************************************************************************************************

INSERE_CHR7:
  BANKSEL 0x30
  MOVLW D'7'
  CPFSEQ CONTADOR_CHAR
    GOTO FIM_ISR_BAIXO
  MOVF CHAR,W

  BANKSEL 0x60
  MOVWF CHR7
  BANKSEL 0x30
  INCF CONTADOR_CHAR,0
  MOVWF CONTADOR_CHAR

; Finaliza rotina de interrupção
; **********************************************************************************************************

FIM_ISR_BAIXO:
  BANKSEL 0x20
  MOVFF TEMP_BSR,BSR
  MOVFF TEMP_STATUS,STATUS
  MOVFF TEMP_W,WREG
  RETFIE

; ROTINAS AUXILIARES PARA CHAMADAS NECESSÁRIAS
; --------------------------------------------------------------------------------------------
DELAY_100MS:
  BANKSEL 0x80
  MOVLW D'100'
  MOVWF CONTADOR3
DELAY_100MS_LOOP:
  BANKSEL 0x80
  MOVLW D'250'
  MOVWF CONTADOR1
  MOVLW D'8'
  MOVWF CONTADOR2
DELAY_1MS_LOOP:
  BANKSEL 0x80
  DECFSZ CONTADOR1,F
    GOTO DELAY_1MS_LOOP
  DECFSZ CONTADOR2,F
    GOTO DELAY_1MS_LOOP
  DECFSZ CONTADOR3,F
    GOTO DELAY_100MS_LOOP
  RETURN

LCD_ENVIA_NIBBLE:
  BANKSEL PORTD

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

  BANKSEL PORTE
  BSF PORTE,1
  NOP
  NOP
  NOP
  NOP
  NOP
  NOP
  NOP
  NOP
  NOP
  BCF PORTE,1

  RETURN

LCD_ENVIA_BYTE:
  CALL LCD_ENVIA_NIBBLE
  SWAPF WREG
  CALL LCD_ENVIA_NIBBLE
  RETURN

LCD_ENVIA_CMD:
  BANKSEL PORTE
  BCF PORTE,0
  CALL LCD_ENVIA_BYTE
  RETURN

LCD_ENVIA_CHAR:
  BANKSEL PORTE
  BSF PORTE,0
  CALL LCD_ENVIA_BYTE
  RETURN

DIVIDIR:
  BANKSEL 0x40
  CLRF QUO
LOOP_DIV:
  MOVF DIV,W
  SUBWF NUM,F
  BTFSS STATUS,C
    RETURN
  INCF QUO,F
  GOTO LOOP_DIV

MULTIPLICAR:
  BANKSEL 0x40
  CLRF PRODT0
  CLRF PRODT1
  MOVF NUM,W
  MOVWF PRODT0
LOOP_MULT:
  DECF NUM2,F
  BTFSC STATUS,Z
    RETURN
  MOVF NUM,W
  ADDWF PRODT0,F
  BTFSC STATUS,C
    INCF PRODT1,F
  GOTO LOOP_MULT

; Diretiva indicando o fim para o compilador
END
