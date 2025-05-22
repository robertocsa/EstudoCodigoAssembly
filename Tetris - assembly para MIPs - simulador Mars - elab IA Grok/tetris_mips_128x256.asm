# Código gerado pelo Grok, após muitas solicitações de ajustes que fiz - data criação: 22/05/2025
# Testado no app Mars, versão 4.5.

# Tetris simplificado para MARS MIPS, usando toda a área do Bitmap Display 128x256
# Constantes do jogo
.eqv WIDTH 16          # Define largura do tabuleiro (16 unidades, 128 pixels) // configurar a janela bitmap para largura 128
.eqv HEIGHT 32         # Define altura do tabuleiro (32 unidades, 256 pixels)  // configurar a janela bitmap para altura 256
.eqv DISPLAY_BASE 0x10040000  # Endereço base do Bitmap Display (heap)
.eqv KEYBOARD_CTRL 0xffff0000 # Endereço de controle do teclado (MMIO)
.eqv KEYBOARD_DATA 0xffff0004 # Endereço de dados do teclado (MMIO)
.eqv COLOR_BLOCK 0x00FF0000   # Cor dos blocos (vermelho, formato 0x00RRGGBB)
.eqv COLOR_BG 0x00000000      # Cor do fundo (preto)
.eqv DELAY_TIME 5000          # Atraso por ciclo (~0.005s, queda fluida)
.eqv DISPLAY_WIDTH 16         # Largura do display em unidades (128 pixels / 8)

.data
board: .space 512             # Tabuleiro: 16x32 bytes (1 byte por célula, 0=vazio, 1=ocupado)
piece_I: .byte 0,-1, 0,0, 0,1, 0,2   # Peça I: 4 blocos, coordenadas x,y relativas
piece_O: .byte 0,0, 0,1, 1,0, 1,1     # Peça O: quadrado
piece_L: .byte 0,-1, 0,0, 0,1, 1,-1   # Peça L: formato L
piece_T: .byte 0,-1, 0,0, 0,1, -1,0   # Peça T: formato T
piece_types: .word piece_I, piece_O, piece_L, piece_T  # Tabela com endereços das peças
current_piece: .space 8       # Buffer para peça atual (4 blocos, x,y, 8 bytes)
piece_x: .word 8              # Posição x do centro da peça (centro de 16 colunas)
piece_y: .word 0              # Posição y inicial da peça (topo)
piece_type: .word -1          # Tipo da peça (-1=sem peça, 0=I, 1=O, 2=L, 3=T)

.text
main:
    la $t0, board             # Carrega endereço base do tabuleiro em $t0
    li $t1, 512               # Define contador para 512 células (16x32)
    li $t2, 0                 # Define valor 0 para células vazias
init_board_loop:
    sb $t2, 0($t0)            # Armazena 0 na célula atual do tabuleiro
    addi $t0, $t0, 1          # Avança para a próxima célula
    addi $t1, $t1, -1         # Decrementa contador de células
    bnez $t1, init_board_loop # Repete até zerar todas as células
    addi $sp, $sp, -4         # Reserva 4 bytes na pilha
    sw $ra, 0($sp)            # Salva endereço de retorno ($ra)
    jal clear_board_area      # Limpa área do tabuleiro no display
    lw $ra, 0($sp)            # Restaura endereço de retorno
    addi $sp, $sp, 4          # Libera espaço na pilha
game_loop:
    lw $t0, piece_type        # Carrega tipo da peça atual em $t0
    bltz $t0, generate_piece  # Se piece_type < 0 (-1), gera nova peça
    addi $sp, $sp, -4         # Reserva 4 bytes na pilha
    sw $ra, 0($sp)            # Salva endereço de retorno
    jal clear_board_area      # Limpa área do tabuleiro no display
    jal draw_board            # Desenha o tabuleiro (células ocupadas)
    jal draw_piece            # Desenha a peça atual
    jal check_input           # Verifica entrada do teclado
    lw $ra, 0($sp)            # Restaura endereço de retorno
    addi $sp, $sp, 4          # Libera espaço na pilha
    li $t0, DELAY_TIME        # Carrega atraso (5000 ciclos) em $t0
delay_loop:
    addi $t0, $t0, -1         # Decrementa contador de atraso
    bnez $t0, delay_loop      # Repete até contador atingir 0
    addi $sp, $sp, -4         # Reserva 4 bytes na pilha
    sw $ra, 0($sp)            # Salva endereço de retorno
    jal try_move_down         # Tenta mover a peça para baixo
    lw $ra, 0($sp)            # Restaura endereço de retorno
    addi $sp, $sp, 4          # Libera espaço na pilha
    beq $v0, 0, fix_piece     # Se não puder mover ($v0=0), fixa a peça
    j game_loop               # Volta ao loop principal
clear_board_area:
    li $t0, DISPLAY_BASE      # Carrega endereço base do display em $t0
    li $t1, HEIGHT            # Define contador de linhas (32) em $t1
    li $t2, COLOR_BG          # Carrega cor de fundo (preto) em $t2
clear_board_y:
    li $t3, WIDTH             # Define contador de colunas (16) em $t3
    mul $t4, $t1, DISPLAY_WIDTH # Calcula offset y (y * 16 unidades) em $t4
    sll $t4, $t4, 2           # Multiplica offset por 4 (bytes por pixel)
    add $t4, $t0, $t4         # Calcula endereço inicial da linha em $t4
clear_board_x:
    sw $t2, 0($t4)            # Preenche pixel com cor de fundo
    addi $t4, $t4, 4          # Avança para o próximo pixel (4 bytes)
    addi $t3, $t3, -1         # Decrementa contador de colunas
    bnez $t3, clear_board_x   # Repete até limpar a linha
    addi $t1, $t1, -1         # Decrementa contador de linhas
    bgez $t1, clear_board_y   # Repete até limpar todas as linhas
    jr $ra                    # Retorna ao chamador
generate_piece:
    li $v0, 42                # Define syscall para número aleatório
    li $a1, 4                 # Define limite superior (0-3) para peça
    syscall                   # Gera número aleatório em $a0 (0=I, 1=O, 2=L, 3=T)
    sw $a0, piece_type        # Armazena tipo da peça em piece_type
    sll $t1, $a0, 2           # Multiplica índice por 4 (tamanho de word)
    la $t2, piece_types       # Carrega endereço da tabela de peças em $t2
    add $t1, $t2, $t1         # Calcula endereço da peça selecionada
    lw $t1, 0($t1)            # Carrega endereço da peça em $t1
    la $t2, current_piece     # Carrega endereço do buffer da peça atual
    li $t3, 4                 # Define contador para 4 blocos
copy_piece_loop:
    lb $t4, 0($t1)            # Carrega offset x do bloco em $t4
    lb $t5, 1($t1)            # Carrega offset y do bloco em $t5
    sb $t4, 0($t2)            # Armazena offset x no buffer
    sb $t5, 1($t2)            # Armazena offset y no buffer
    addi $t1, $t1, 2          # Avança para o próximo par (x,y) da peça
    addi $t2, $t2, 2          # Avança no buffer da peça atual
    addi $t3, $t3, -1         # Decrementa contador de blocos
    bnez $t3, copy_piece_loop # Repete até copiar todos os blocos
    li $t0, 8                 # Define posição x inicial (centro de 16 colunas)
    sw $t0, piece_x           # Armazena em piece_x
    li $t0, 0                 # Define posição y inicial (topo)
    sw $t0, piece_y           # Armazena em piece_y
    addi $sp, $sp, -4         # Reserva 4 bytes na pilha
    sw $ra, 0($sp)            # Salva endereço de retorno
    jal check_collision       # Verifica colisão na posição inicial
    lw $ra, 0($sp)            # Restaura endereço de retorno
    addi $sp, $sp, 4          # Libera espaço na pilha
    bnez $v0, game_over       # Se colidir ($v0=1), termina o jogo
    j game_loop               # Volta ao loop principal
try_move_down:
    lw $t0, piece_y           # Carrega posição y atual em $t0
    addi $t0, $t0, 1          # Incrementa y para mover para baixo
    sw $t0, piece_y           # Armazena nova posição y
    addi $sp, $sp, -4         # Reserva 4 bytes na pilha
    sw $ra, 0($sp)            # Salva endereço de retorno
    jal check_collision       # Verifica colisão na nova posição
    lw $ra, 0($sp)            # Restaura endereço de retorno
    addi $sp, $sp, 4          # Libera espaço na pilha
    beq $v0, 0, move_down_ok  # Se não colidir ($v0=0), movimento válido
    lw $t0, piece_y           # Carrega posição y atual
    addi $t0, $t0, -1         # Reverte movimento (y-1)
    bgez $t0, valid_y         # Se y >= 0, mantém
    li $t0, 0                 # Força y=0 se negativo
valid_y:
    sw $t0, piece_y           # Armazena posição y original
    li $v0, 0                 # Retorna 0 (movimento falhou)
    jr $ra                    # Retorna ao chamador
move_down_ok:
    li $v0, 1                 # Retorna 1 (movimento bem-sucedido)
    jr $ra                    # Retorna ao chamador
fix_piece:
    la $t0, current_piece     # Carrega endereço da peça atual em $t0
    lw $t1, piece_x           # Carrega posição x do centro em $t1
    lw $t2, piece_y           # Carrega posição y do centro em $t2
    li $t3, 4                 # Define contador para 4 blocos
fix_piece_loop:
    lb $t4, 0($t0)            # Carrega offset x do bloco em $t4
    lb $t5, 1($t0)            # Carrega offset y do bloco em $t5
    add $t6, $t1, $t4         # Calcula x absoluto (x_centro + offset_x)
    add $t7, $t2, $t5         # Calcula y absoluto (y_centro + offset_y)
    bltz $t6, skip_fix_block  # Pula se x < 0 (fora do tabuleiro)
    bge $t6, WIDTH, skip_fix_block # Pula se x >= WIDTH (16, fora do tabuleiro)
    bltz $t7, skip_fix_block  # Pula se y < 0 (fora do tabuleiro)
    bge $t7, HEIGHT, skip_fix_block # Pula se y >= HEIGHT (32, fora do tabuleiro)
    mul $t8, $t7, WIDTH       # Calcula índice (y * WIDTH) em $t8
    add $t8, $t8, $t6         # Adiciona x ao índice
    la $t9, board             # Carrega endereço base do tabuleiro em $t9
    add $t8, $t9, $t8         # Calcula endereço da célula no tabuleiro
    li $t9, 1                 # Define valor 1 (célula ocupada)
    sb $t9, 0($t8)            # Marca célula como ocupada no tabuleiro
skip_fix_block:
    addi $t0, $t0, 2          # Avança para o próximo par (x,y)
    addi $t3, $t3, -1         # Decrementa contador de blocos
    bnez $t3, fix_piece_loop  # Repete até processar todos os blocos
    addi $sp, $sp, -4         # Reserva 4 bytes na pilha
    sw $ra, 0($sp)            # Salva endereço de retorno
    jal clear_lines           # Chama função para limpar linhas completas
    lw $ra, 0($sp)            # Restaura endereço de retorno
    addi $sp, $sp, 4          # Libera espaço na pilha
    li $t0, -1                # Define piece_type como -1 (sem peça)
    sw $t0, piece_type        # Armazena em piece_type
    j game_loop               # Volta ao loop principal
clear_lines:
    li $t1, HEIGHT            # Define contador de linhas (32) em $t1
    addi $t1, $t1, -1         # Começa da última linha (y=31)
    li $v0, 0                 # Inicializa contador de linhas limpas em $v0
clear_lines_loop:
    la $t2, board             # Carrega endereço base do tabuleiro em $t2
    mul $t3, $t1, WIDTH       # Calcula offset da linha (y * WIDTH) em $t3
    add $t2, $t2, $t3         # Calcula endereço da linha atual
    li $t4, WIDTH             # Define contador de colunas (16) em $t4
    li $t5, 0                 # Inicializa soma dos blocos na linha
check_line_loop:
    lb $t6, 0($t2)            # Carrega valor da célula em $t6
    add $t5, $t5, $t6         # Adiciona valor à soma (0 ou 1)
    addi $t2, $t2, 1          # Avança para a próxima célula
    addi $t4, $t4, -1         # Decrementa contador de colunas
    bnez $t4, check_line_loop # Repete até verificar toda a linha
    bne $t5, WIDTH, next_line # Se soma != WIDTH (16), linha não está completa
    addi $sp, $sp, -12        # Reserva 12 bytes na pilha
    sw $t1, 0($sp)            # Salva $t1 (linha atual)
    sw $ra, 4($sp)            # Salva endereço de retorno
    sw $t5, 8($sp)            # Salva $t5 (soma)
    move $a0, $t1             # Passa número da linha para $a0
    jal remove_line           # Remove linha completa
    addi $v0, $v0, 1          # Incrementa contador de linhas limpas
    lw $t1, 0($sp)            # Restaura $t1
    lw $ra, 4($sp)            # Restaura endereço de retorno
    lw $t5, 8($sp)            # Restaura $t5
    addi $sp, $sp, 12         # Libera espaço na pilha
    j clear_lines_loop        # Reprocessa mesma linha após deslocamento
next_line:
    addi $t1, $t1, -1         # Passa para a linha anterior
    bgez $t1, clear_lines_loop # Repete até y >= 0
    jr $ra                    # Retorna com $v0 = número de linhas limpas
remove_line:
    move $t2, $a0             # Copia número da linha a remover para $t2
remove_line_loop:
    beq $t2, 0, clear_line    # Se linha 0, limpa topo do tabuleiro
    la $t3, board             # Carrega endereço base do tabuleiro em $t3
    mul $t4, $t2, WIDTH       # Calcula offset da linha atual
    add $t4, $t3, $t4         # Calcula endereço da linha atual
    addi $t2, $t2, -1         # Calcula linha anterior
    mul $t5, $t2, WIDTH       # Calcula offset da linha anterior
    add $t5, $t3, $t5         # Calcula endereço da linha anterior
    li $t6, WIDTH             # Define contador de colunas (16)
copy_line_loop:
    lb $t7, 0($t5)            # Carrega célula da linha anterior
    sb $t7, 0($t4)            # Copia célula para a linha atual
    addi $t4, $t4, 1          # Avança na linha atual
    addi $t5, $t5, 1          # Avança na linha anterior
    addi $t6, $t6, -1         # Decrementa contador de colunas
    bnez $t6, copy_line_loop  # Repete até copiar toda a linha
    j remove_line_loop        # Processa próxima linha
clear_line:
    la $t3, board             # Carrega endereço base do tabuleiro em $t3
    li $t4, WIDTH             # Define contador de colunas (16)
    li $t5, 0                 # Define valor 0 para células vazias
clear_top_loop:
    sb $t5, 0($t3)            # Zera célula no topo do tabuleiro
    addi $t3, $t3, 1          # Avança para a próxima célula
    addi $t4, $t4, -1         # Decrementa contador
    bnez $t4, clear_top_loop  # Repete até limpar a linha
    jr $ra                    # Retorna ao chamador
check_collision:
    la $t0, current_piece     # Carrega endereço da peça atual em $t0
    lw $t1, piece_x           # Carrega posição x do centro em $t1
    lw $t2, piece_y           # Carrega posição y do centro em $t2
    li $t3, 4                 # Define contador para 4 blocos
    li $v0, 0                 # Inicializa retorno ($v0=0, sem colisão)
check_collision_loop:
    lb $t4, 0($t0)            # Carrega offset x do bloco em $t4
    lb $t5, 1($t0)            # Carrega offset y do bloco em $t5
    add $t6, $t1, $t4         # Calcula x absoluto
    add $t7, $t2, $t5         # Calcula y absoluto
    bltz $t6, collision       # Colisão se x < 0 (fora à esquerda)
    bge $t6, WIDTH, collision # Colisão se x >= WIDTH (16, fora à direita)
    bge $t7, HEIGHT, collision # Colisão se y >= HEIGHT (32, fundo)
    bltz $t7, skip_collision_check # Ignora colisão se y < 0 (acima do tabuleiro)
    mul $t8, $t7, WIDTH       # Calcula índice (y * WIDTH) em $t8
    add $t8, $t8, $t6         # Adiciona x ao índice
    la $t9, board             # Carrega endereço base do tabuleiro em $t9
    add $t8, $t9, $t8         # Calcula endereço da célula
    lb $t9, 0($t8)            # Carrega valor da célula
    bnez $t9, collision       # Colisão se célula ocupada (valor=1)
skip_collision_check:
    addi $t0, $t0, 2          # Avança para o próximo par (x,y)
    addi $t3, $t3, -1         # Decrementa contador de blocos
    bnez $t3, check_collision_loop # Repete até verificar todos os blocos
    jr $ra                    # Retorna com $v0=0 (sem colisão)
collision:
    li $v0, 1                 # Define $v0=1 (colisão detectada)
    jr $ra                    # Retorna ao chamador
draw_board:
    la $t0, board             # Carrega endereço base do tabuleiro em $t0
    li $t1, 0                 # Inicializa contador y (linha)
draw_board_y:
    li $t2, 0                 # Inicializa contador x (coluna)
draw_board_x:
    mul $t3, $t1, WIDTH       # Calcula índice no tabuleiro (y * WIDTH)
    add $t3, $t3, $t2         # Adiciona x ao índice
    add $t3, $t0, $t3         # Calcula endereço da célula
    lb $t3, 0($t3)            # Carrega valor da célula (0=vazio, 1=ocupado)
    mul $t4, $t1, DISPLAY_WIDTH # Calcula offset y no display (y * 16)
    add $t4, $t4, $t2         # Adiciona x ao offset
    sll $t4, $t4, 2           # Multiplica por 4 (bytes por pixel)
    li $t5, DISPLAY_BASE      # Carrega endereço base do display
    add $t4, $t5, $t4         # Calcula endereço do pixel
    beq $t3, 0, draw_bg       # Se célula vazia, desenha fundo
    li $t5, COLOR_BLOCK       # Carrega cor do bloco (vermelho)
    j draw_pixel              # Pula para desenhar pixel
draw_bg:
    li $t5, COLOR_BG          # Carrega cor de fundo (preto)
draw_pixel:
    sw $t5, 0($t4)            # Desenha pixel no endereço calculado
    addi $t2, $t2, 1          # Incrementa x
    blt $t2, WIDTH, draw_board_x # Repete até x < WIDTH (16)
    addi $t1, $t1, 1          # Incrementa y
    blt $t1, HEIGHT, draw_board_y # Repete até y < HEIGHT (32)
    jr $ra                    # Retorna ao chamador
draw_piece:
    la $t0, current_piece     # Carrega endereço da peça atual em $t0
    lw $t1, piece_x           # Carrega posição x do centro em $t1
    lw $t2, piece_y           # Carrega posição y do centro em $t2
    li $t3, 4                 # Define contador para 4 blocos
draw_piece_loop:
    lb $t4, 0($t0)            # Carrega offset x do bloco em $t4
    lb $t5, 1($t0)            # Carrega offset y do bloco em $t5
    add $t6, $t1, $t4         # Calcula x absoluto
    add $t7, $t2, $t5         # Calcula y absoluto
    bltz $t6, skip_block      # Pula se x < 0 (fora do tabuleiro)
    bge $t6, WIDTH, skip_block # Pula se x >= WIDTH (16)
    bltz $t7, skip_block      # Pula se y < 0
    bge $t7, HEIGHT, skip_block # Pula se y >= HEIGHT (32)
    mul $t8, $t7, DISPLAY_WIDTH # Calcula offset y no display (y * 16)
    add $t8, $t8, $t6         # Adiciona x ao offset
    sll $t8, $t8, 2           # Multiplica por 4 (bytes por pixel)
    li $t9, DISPLAY_BASE      # Carrega endereço base do display
    add $t8, $t9, $t8         # Calcula endereço do pixel
    li $t9, COLOR_BLOCK       # Carrega cor do bloco (vermelho)
    sw $t9, 0($t8)            # Desenha pixel
skip_block:
    addi $t0, $t0, 2          # Avança para o próximo par (x,y)
    addi $t3, $t3, -1         # Decrementa contador de blocos
    bnez $t3, draw_piece_loop # Repete até processar todos os blocos
    jr $ra                    # Retorna ao chamador
check_input:
    li $t0, KEYBOARD_CTRL     # Carrega endereço de controle do teclado
    lw $t1, 0($t0)            # Carrega status do teclado em $t1
    andi $t1, $t1, 1          # Mascara bit de disponibilidade (1=tecla pronta)
    beq $t1, 0, no_input      # Pula se não houver tecla
    li $t0, KEYBOARD_DATA     # Carrega endereço de dados do teclado
    lw $t1, 0($t0)            # Carrega tecla pressionada (ASCII) em $t1
    li $t2, 0                 # Define valor 0 para limpar buffer
    sw $t2, 0($t0)            # Limpa buffer de teclado (1ª vez)
    sw $t2, 0($t0)            # Limpa buffer de teclado (2ª vez)
    li $t3, 100               # Define contador para pequeno atraso (100 ciclos)
input_delay_loop:
    addi $t3, $t3, -1         # Decrementa contador de atraso
    bnez $t3, input_delay_loop # Repete até contador atingir 0
    addi $sp, $sp, -12        # Reserva 12 bytes na pilha
    sw $ra, 0($sp)            # Salva endereço de retorno
    sw $t1, 4($sp)            # Salva $t1 (tecla)
    sw $t2, 8($sp)            # Salva $t2 (valor 0)
    beq $t1, '4', move_left_call # Se tecla='4', move para esquerda // Originalmente: Se tecla='a', move para esquerda
    beq $t1, '6', move_right_call # Se tecla='6', move para direita // Originalmente: Se tecla='d', move para direita
    beq $t1, '5', rotate_piece_call # Se tecla='5', rotaciona peça // Originalmente: # Se tecla='w', rotaciona peça
    beq $t1, '2', move_down_call # Se tecla='2', move para baixo // Originalmente, tecla 's'
    beq $t1, 'q', game_over_call # Se tecla='q', termina jogo
    j restore_ra              # Pula para restaurar registradores
move_left_call:
    jal move_left             # Chama função para mover à esquerda
    j restore_ra              # Pula para restaurar registradores
move_right_call:
    jal move_right            # Chama função para mover à direita
    j restore_ra              # Pula para restaurar registradores
rotate_piece_call:
    jal rotate_piece          # Chama função para rotacionar peça
    j restore_ra              # Pula para restaurar registradores
move_down_call:
    jal move_down             # Chama função para mover para baixo
    j restore_ra              # Pula para restaurar registradores
game_over_call:
    jal game_over             # Chama função para terminar jogo
restore_ra:
    lw $ra, 0($sp)            # Restaura endereço de retorno
    lw $t1, 4($sp)            # Restaura $t1
    lw $t2, 8($sp)            # Restaura $t2
    addi $sp, $sp, 12         # Libera espaço na pilha
no_input:
    jr $ra                    # Retorna ao chamador
move_left:
    lw $t0, piece_x           # Carrega posição x atual em $t0
    addi $t0, $t0, -1         # Decrementa x (move à esquerda)
    sw $t0, piece_x           # Armazena nova posição x
    addi $sp, $sp, -4         # Reserva 4 bytes na pilha
    sw $ra, 0($sp)            # Salva endereço de retorno
    jal check_collision       # Verifica colisão na nova posição
    lw $ra, 0($sp)            # Restaura endereço de retorno
    addi $sp, $sp, 4          # Libera espaço na pilha
    beq $v0, 0, input_done    # Se não colidir ($v0=0), movimento válido
    lw $t0, piece_x           # Carrega posição x atual
    addi $t0, $t0, 1          # Reverte movimento (x+1)
    sw $t0, piece_x           # Armazena posição x original
    j input_done              # Pula para fim da entrada
move_right:
    lw $t0, piece_x           # Carrega posição x atual em $t0
    addi $t0, $t0, 1          # Incrementa x (move à direita)
    sw $t0, piece_x           # Armazena nova posição x
    addi $sp, $sp, -4         # Reserva 4 bytes na pilha
    sw $ra, 0($sp)            # Salva endereço de retorno
    jal check_collision       # Verifica colisão na nova posição
    lw $ra, 0($sp)            # Restaura endereço de retorno
    addi $sp, $sp, 4          # Libera espaço na pilha
    beq $v0, 0, input_done    # Se não colidir ($v0=0), movimento válido
    lw $t0, piece_x           # Carrega posição x atual
    addi $t0, $t0, -1         # Reverte movimento (x-1)
    sw $t0, piece_x           # Armazena posição x original
    j input_done              # Pula para fim da entrada
move_down:
    addi $sp, $sp, -4         # Reserva 4 bytes na pilha
    sw $ra, 0($sp)            # Salva endereço de retorno
    jal try_move_down         # Chama função para mover para baixo
    lw $ra, 0($sp)            # Restaura endereço de retorno
    addi $sp, $sp, 4          # Libera espaço na pilha
    j input_done              # Retorna ao chamador
rotate_piece:
    la $t0, current_piece     # Carrega endereço da peça atual em $t0
    la $t1, current_piece     # Carrega endereço novamente para rotação
    li $t2, 4                 # Define contador para 4 blocos
    addi $sp, $sp, -8         # Reserva 8 bytes na pilha
    sw $t0, 0($sp)            # Salva $t0
    sw $ra, 4($sp)            # Salva endereço de retorno
rotate_loop:
    lb $t3, 0($t1)            # Carrega offset x do bloco em $t3
    lb $t4, 1($t1)            # Carrega offset y do bloco em $t4
    sb $t4, 0($t1)            # Armazena y como novo x (rotação 90°)
    sub $t4, $zero, $t3       # Calcula -x para novo y
    sb $t4, 1($t1)            # Armazena novo y
    addi $t1, $t1, 2          # Avança para o próximo par (x,y)
    addi $t2, $t2, -1         # Decrementa contador
    bnez $t2, rotate_loop     # Repete até rotacionar todos os blocos
    jal check_collision       # Verifica colisão após rotação
    beq $v0, 0, rotate_done   # Se não colidir ($v0=0), rotação válida
    la $t1, current_piece     # Carrega endereço da peça atual
    li $t2, 4                 # Define contador para 4 blocos
rotate_back_loop:
    lb $t3, 0($t1)            # Carrega offset x do bloco
    lb $t4, 1($t1)            # Carrega offset y do bloco
    sb $t4, 0($t1)            # Armazena y como novo x (reverte rotação)
    sub $t4, $zero, $t3       # Calcula -x para novo y
    sb $t4, 1($t1)            # Armazena novo y
    addi $t1, $t1, 2          # Avança para o próximo par (x,y)
    addi $t2, $t2, -1         # Decrementa contador
    bnez $t2, rotate_back_loop # Repete até reverter todos os blocos
rotate_done:
    lw $t0, 0($sp)            # Restaura $t0
    lw $ra, 4($sp)            # Restaura endereço de retorno
    addi $sp, $sp, 8          # Libera espaço na pilha
input_done:
    jr $ra                    # Retorna ao chamador
game_over:
    addi $sp, $sp, -4         # Reserva 4 bytes na pilha
    sw $ra, 0($sp)            # Salva endereço de retorno
    jal clear_board_area      # Limpa área do tabuleiro no display
    lw $ra, 0($sp)            # Restaura endereço de retorno
    addi $sp, $sp, 4          # Libera espaço na pilha
    li $v0, 10                # Define syscall para terminar programa
    syscall                   # Termina execução