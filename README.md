# PIC18F4550-Assembly
Exemplos de implementação utilizando o microcontrolador PIC18 e o assembler GPASM.

## (EXEMPLO 1) Display (HD44780) e teclado matricial
**Obs:** O código na pasta pressupõe que os resistores estão em pull-down. Basta trocar
as instruções que usam o BTFSC e BTFSS de acordo com o estado lógico adequado, não esquecendo que
em pull-up os botões são baixo ativos (ligado em nível lógico baixo e desligado em alto).

![Print da simulação.](https://github.com/KaiqueZambrano/PIC18F4550-Assembly/blob/main/display_teclado/sim-display-teclado.png)

## (EXEMPLO 2) Tela para inserção de senha (RA do aluno: 2313073)
Início da simulação do firmware:

![Gif sim1 exemplo 2](https://github.com/KaiqueZambrano/PIC18F4550-Assembly/blob/main/app-senha/sim1.gif)

Ao inserir a senha **correta** (RA do aluno):

![Gif sim1 exemplo 2](https://github.com/KaiqueZambrano/PIC18F4550-Assembly/blob/main/app-senha/sim2.gif)

Ao inserir uma senha **incorreta**:

![Gif sim1 exemplo 2](https://github.com/KaiqueZambrano/PIC18F4550-Assembly/blob/main/app-senha/sim3.gif)

Após o período de **20 segundos**, a senha também será avaliada como incorreta.
