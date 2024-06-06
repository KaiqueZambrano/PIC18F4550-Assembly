# PIC18F4550-Assembly
Exemplos de implementação utilizando o microcontrolador PIC18 e o assembler GPASM.

## Display (HD44780) e teclado matricial
**Obs:** O código na pasta pressupõe que os resistores estão em pull-down. Basta trocar
as instruções que usam o BTFSC e BTFSS de acordo com o estado lógico adequado, não esquecendo que
em pull-up os botões são baixo ativos (ligado em nível lógico baixo e desligado em alto).

![Print da simulação.](https://github.com/KaiqueZambrano/PIC18F4550-Assembly/blob/main/display_teclado/sim-display-teclado.png)

## Tela para inserção de senha (RA do aluno: 2313073)


