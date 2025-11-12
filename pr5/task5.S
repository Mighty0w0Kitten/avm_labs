/*
    Программа для задания 5: Вычисление вектора b(i) = A(k,i) + A(i,l).
    Использует базово-индексную адресацию со смещением, как в примере adr-mode.S.
*/

.include "my-macro"  # Макрос Finish для выхода

.data  # Инициализированные данные
    A:  # Матрица 6x6, .long, заполнена 1..36 для теста
        .long 1, 2, 3, 4, 5, 6
        .long 7, 8, 9, 10, 11, 12
        .long 13, 14, 15, 16, 17, 18
        .long 19, 20, 21, 22, 23, 24
        .long 25, 26, 27, 28, 29, 30
        .long 31, 32, 33, 34, 35, 36

    error_msg:
        .ascii "Invalid index\n"  # 14 байт для ошибки

    header_msg:
        .ascii "b: "  # 3 байта для заголовка вывода

    space_msg:
        .ascii " "  # 1 байт для пробела

    newline_msg:
        .ascii "\n"  # 1 байт для новой строки

.bss  # Неинициализированные данные
    b:
        .space 24  # Вектор b (6*4 байта)

    k:
        .space 4  # Переменная k (4 байта)

    l:
        .space 4  # Переменная l (4 байта)

    input_buf_k:
        .space 10  # Буфер для ввода k (строка)

    input_buf_l:
        .space 10  # Буфер для ввода l (строка)

    output_buf:
        .space 20  # Буфер для строки числа при выводе

.text  # Секция кода
    .global _start  # Точка входа

    _start:
        nop  # Для отладки в kdbg

        # Чтение k с stdin
        movl $3, %eax
        movl $0, %ebx
        movl $input_buf_k, %ecx
        movl $10, %edx
        int $0x80

        movl $input_buf_k, %esi  # Параметр для atoi_sub
        call atoi_sub
        movl %eax, k  # Сохранение в k

        # Чтение l с stdin
        movl $3, %eax
        movl $0, %ebx
        movl $input_buf_l, %ecx
        movl $10, %edx
        int $0x80

        movl $input_buf_l, %esi
        call atoi_sub
        movl %eax, l

        # Корректировка индексов (1-based → 0-based)
        decl k
        decl l

        # Проверка диапазона [0..5]
        movl k, %eax
        cmpl $0, %eax
        jl error
        cmpl $5, %eax
        jg error
        movl l, %eax
        cmpl $0, %eax
        jl error
        cmpl $5, %eax
        jg error
        jmp continue

    error:  # Обработка ошибки: вывод и выход
        movl $4, %eax
        movl $1, %ebx
        movl $error_msg, %ecx
        movl $14, %edx
        int $0x80
        Finish

    continue:  # Основная логика: вычисления и вывод
        movl $0, %ebx  # i=0 для цикла

        compute_loop:  # Цикл вычислений b(i)
            # A[k, i]: база = A + k*24, index=i, scale=4
            movl k, %eax
            imull $24, %eax
            leal A(%eax), %edx
            movl (%edx, %ebx, 4), %eax

            # A[i, l]: база = A + i*24, index=l, scale=4
            movl %ebx, %ecx
            imull $24, %ecx
            leal A(%ecx), %edx
            movl l, %ecx
            addl (%edx, %ecx, 4), %eax

            # Сохранение в b[i]
            movl %eax, b(,%ebx,4)

            incl %ebx  # i++
            cmpl $6, %ebx
            jne compute_loop

        # Вывод заголовка "b: "
        movl $4, %eax
        movl $1, %ebx
        movl $header_msg, %ecx
        movl $3, %edx
        int $0x80

        movl $0, %ebx  # i=0 для вывода

        output_loop:  # Цикл вывода b[i]
            movl b(,%ebx,4), %eax  # Число для itoa
            leal output_buf, %edi  # Буфер для itoa
            call itoa_sub  # Преобразование, edx=длина

            # Вывод числа
            movl $4, %eax
            movl $1, %ebx
            movl $output_buf, %ecx
            int $0x80

            # Вывод пробела
            movl $4, %eax
            movl $1, %ebx
            movl $space_msg, %ecx
            movl $1, %edx
            int $0x80

            incl %ebx  # i++
            cmpl $6, %ebx
            jne output_loop

        # Вывод новой строки
        movl $4, %eax
        movl $1, %ebx
        movl $newline_msg, %ecx
        movl $1, %edx
        int $0x80

        Finish

    # Подпрограмма atoi_sub: esi=буфер строки, возвращает eax=число
    atoi_sub:
        movl $0, %eax  # Стартовое число

        atoi_loop:
            movb (%esi), %bl
            cmpb $'\n', %bl
            je atoi_end
            cmpb $0, %bl
            je atoi_end
            subb $'0', %bl
            imull $10, %eax
            addl %ebx, %eax
            incl %esi
            jmp atoi_loop

        atoi_end:
            ret

    # Подпрограмма itoa_sub: eax=число, edi=буфер, возвращает edx=длина строки
    itoa_sub:
        movl $0, %ecx  # Счётчик цифр
        movl $10, %esi  # Делитель

        itoa_loop:
            cmpl $0, %eax
            je itoa_reverse
            xorl %edx, %edx
            divl %esi
            addb $'0', %dl
            movb %dl, (%edi, %ecx)
            incl %ecx
            jmp itoa_loop

        itoa_reverse:  # Переворот строки
            decl %ecx
            movl $0, %edx  # Начало буфера

            reverse_loop:
                cmpl %edx, %ecx
                jle itoa_end
                movb (%edi, %edx), %al
                movb (%edi, %ecx), %ah
                movb %ah, (%edi, %edx)
                movb %al, (%edi, %ecx)
                incl %edx
                decl %ecx
                jmp reverse_loop

        itoa_end:
            addl $1, %ecx  # Длина
            movl %ecx, %edx
            ret

.end  # Конец программы