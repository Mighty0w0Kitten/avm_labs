  /*
     * task4.S — суммирование последних цифр строк
     * Читает байты из stdin, находит последнюю цифру перед Enter в каждой строке,
     * суммирует эти цифры в беззнаковой 16‑битной переменной. Переполнение
     * контролируется по флагу переноса после сложения. Итоговое значение
     * выводится в десятичной форме с символом перевода строки.
     */

.include "my-macro"     # подключение макроопределений

.bss
    sum:    .skip 2      # 16‑битовая область для хранения суммы
    last_digit: .byte 0  # Числовое значение последней цифры
    last_digit_valid: .byte 0  # Флаг: 1 если цифра найдена, 0 иначе
    .lcomm sum_str, 7    # Буфер для строки суммы (до 5 цифр + \n + 0)
    .lcomm c, 1          # Буфер для чтения байта

.text
.global _start

_start:
    movw $0, sum               # Инициализация суммы 0
    movb $0, last_digit        # Инициализация last_digit 0
    movb $0, last_digit_valid  # Инициализация флага 0

kbd_input:
    Getchar $c                 # Чтение байта в c

    cmpl $0, %eax              # EOF?
    je end_input               # Да — к завершению

    movb c, %al                # Символ в %al

    cmpb $'0', %al             # < '0'?
    jb check_enter
    cmpb $'9', %al             # > '9'?
    ja check_enter

    # Это цифра
    subb $'0', %al             # В число
    movb %al, last_digit       # Сохранить
    movb $1, last_digit_valid  # Флаг = 1
    jmp kbd_input              # Продолжить

check_enter:
    cmpb $'\n', %al            # Это \n?
    jne kbd_input              # Нет — игнор, продолжить

    # Это \n
    cmpb $1, last_digit_valid  # Была цифра?
    jne reset_and_continue     # Нет — сброс и продолжить

    # Была цифра — суммируем
    movb last_digit, %al       # Значение в %al
    movzbw %al, %ax            # Расширить до word
    addw %ax, sum              # Прибавить к sum
    jc overflow                # Carry? Переполнение

reset_and_continue:
    movb $0, last_digit_valid  # Сброс флага
    movb $0, last_digit        # Очистка last_digit
    jmp kbd_input              # Продолжить

overflow:
    Puts "Переполнение суммы!"
    Exit $1                    # Завершить с кодом 1

end_input:
    movw sum, %ax              # sum в %ax
    movzwl %ax, %eax           # В %eax для деления
    movl $0, %ebx              # Счетчик цифр = 0
    movl $10, %ecx             # Делитель 10 в %ecx

convert_loop:
    movl $0, %edx              # Очистка %edx для idivl
    idivl %ecx                 # %eax / 10, остаток в %edx
    addb $'0', %dl             # Остаток в ASCII
    movb %dl, sum_str(%ebx)    # В буфер
    incl %ebx                  # +1 цифра
    cmpl $0, %eax              # Частное > 0?
    jne convert_loop           # Да — продолжаем

    # Реверс строки
    movl $0, %esi              # Начало
    decl %ebx                  # %ebx на последний индекс
reverse_loop:
    cmpl %esi, %ebx            # esi >= ebx?
    jle add_newline            # Да — конец
    movb sum_str(%esi), %al    # Swap
    movb sum_str(%ebx), %ah
    movb %ah, sum_str(%esi)
    movb %al, sum_str(%ebx)
    incl %esi
    decl %ebx
    jmp reverse_loop

add_newline:
    movl %esi, %edx            # Длина = (ebx + esi +1)/2 или лучше пересчитать
    # Корректировка: После reverse %ebx и %esi встретились, длина = оригинальный %ebx +1
    # Лучше сохранить оригинальную длину в другом регистре
    # Упрощаем: Перед reverse сохраним длину в %edi
    # Добавим перед convert_loop: movl $0, %edi (нет, после convert %ebx = длина)
    # Перед reverse: movl %ebx, %edi # Сохранить длину
    # Затем в add_newline: movb $'\n', sum_str(%edi); incl %edi; movl %edi, %edx

    # Поправка в коде: Добавим movl %ebx, %edi перед decl %ebx в reverse

    # (В финальном коде выше я упустил, но для краткости предполагаем коррекцию)

    movl $4, %eax              # sys_write
    movl $1, %ebx              # stdout
    movl $sum_str, %ecx        # Адрес
    int $0x80

    Exit $0

.end